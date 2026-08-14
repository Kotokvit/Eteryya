#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DEM → P³ ИМПОРТ РЕЛЬЕФА v1.0
==============================

Загрузка реальных DEM (Digital Elevation Model) данных Земли
и конвертация в P³ с Фубини-Штуди метрикой.

Поддерживаемые форматы:
  - GeoTIFF (.tif) — через rasterio
  - SRTM HGT (.hgt) — встроенный парсер NASA SRTM
  - ASCII Grid (.asc) — ESRI ASCIIGRID
  - CSV высот (.csv) — lat, lon, elevation
  - NumPy (.npy) — предварительно обработанные

Конвертация в P³:
  1. (lat, lon, h) → (X, Y, Z) на сфере радиуса R_Земли + h
  2. (X, Y, Z) → HomVec4(X, Y, Z, W) с W = cos(s/2R)
  3. W-калибровка: высоты → W-значения
  4. Выбор лучшей афинной карты через pick_best_card

Ключевое наблюдение:
  Земля в R³ → Земля в P³ — мы видим ТОПОЛОГИЧЕСКУЮ разницу!
  
  В R³: Земля — просто сфера, ничего интересного.
  В P³: Земля — проективная сфера с Z/2Z-голономией,
        антиподальные точки отождествлены,
        Северный полюс ≡ Южный полюс (в RP³)!
        
  Это значит: навигация на P³ «замыкает» полюса —
  маршрут через Северный полюс выходит с Южного.

Интеграция:
  from kernel.p3_kernel import HomVec4, surface_to_p3, w_from_distance
  from kernel.extensions.dem_import import DEMToP3
"""

import math
import numpy as np
import struct
import os
from typing import List, Tuple, Optional, Dict, NamedTuple
from dataclasses import dataclass, field

# ═══════════════════════════════════════════════════════════════
# 0. ЗАВИСИМОСТИ ОТ ЯДРА
# ═══════════════════════════════════════════════════════════════

import sys
_kernel_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _kernel_dir not in sys.path:
    sys.path.insert(0, _kernel_dir)

from p3_kernel import (
    HomVec4, surface_to_p3, w_from_distance, s_from_W,
    fs_distance, R_ETERIA_KM, R_EARTH_KM, W_EPS
)


# ═══════════════════════════════════════════════════════════════
# 1. DEM ДАННЫЕ
# ═══════════════════════════════════════════════════════════════

@dataclass
class DEMGrid:
    """
    Сетка высот: регулярная широта-долгота.
    
    Атрибуты:
      elevations: 2D массив высот (м) — [lat_idx, lon_idx]
      lat_min, lat_max: диапазон широт (градусы)
      lon_min, lon_max: диапазон долгот (градусы)
      n_lat, n_lon: размер сетки
      nodata: значение «нет данных»
      source: источник данных (SRTM, ASTER, etc.)
    """
    elevations: np.ndarray
    lat_min: float = -90.0
    lat_max: float = 90.0
    lon_min: float = -180.0
    lon_max: float = 180.0
    nodata: float = -32768.0
    source: str = "unknown"
    
    @property
    def n_lat(self) -> int:
        return self.elevations.shape[0]
    
    @property
    def n_lon(self) -> int:
        return self.elevations.shape[1]
    
    @property
    def d_lat(self) -> float:
        """Шаг по широте (градусы)"""
        return (self.lat_max - self.lat_min) / max(self.n_lat - 1, 1)
    
    @property
    def d_lon(self) -> float:
        """Шаг по долготе (градусы)"""
        return (self.lon_max - self.lon_min) / max(self.n_lon - 1, 1)
    
    def lat_lon(self, i: int, j: int) -> Tuple[float, float]:
        """Широта и долгота для индекса (i, j)"""
        lat = self.lat_max - i * self.d_lat
        lon = self.lon_min + j * self.d_lon
        return lat, lon
    
    def elevation_at(self, lat: float, lon: float) -> float:
        """Высота в заданной точке (билинейная интерполяция)"""
        # Инвертируем: i = (lat_max - lat) / d_lat
        i_f = (self.lat_max - lat) / self.d_lat
        j_f = (lon - self.lon_min) / self.d_lon
        
        i0 = int(np.floor(i_f))
        j0 = int(np.floor(j_f))
        i1 = min(i0 + 1, self.n_lat - 1)
        j1 = min(j0 + 1, self.n_lon - 1)
        
        if i0 < 0 or i0 >= self.n_lat or j0 < 0 or j0 >= self.n_lon:
            return self.nodata
        
        a = i_f - i0
        b = j_f - j0
        
        h00 = self.elevations[i0, j0]
        h10 = self.elevations[i1, j0]
        h01 = self.elevations[i0, j1]
        h11 = self.elevations[i1, j1]
        
        # Билинейная
        h = (1-a)*(1-b)*h00 + a*(1-b)*h10 + (1-a)*b*h01 + a*b*h11
        return h
    
    def stats(self) -> Dict:
        """Статистика высот"""
        valid = self.elevations[self.elevations != self.nodata]
        if len(valid) == 0:
            return {'min': 0, 'max': 0, 'mean': 0, 'std': 0, 'n_valid': 0}
        return {
            'min': float(np.min(valid)),
            'max': float(np.max(valid)),
            'mean': float(np.mean(valid)),
            'std': float(np.std(valid)),
            'n_valid': len(valid)
        }


# ═══════════════════════════════════════════════════════════════
# 2. ЗАГРУЗЧИКИ DEM
# ═══════════════════════════════════════════════════════════════

class DEMLoader:
    """Загрузка DEM из различных форматов"""
    
    @staticmethod
    def load_hgt(filepath: str) -> DEMGrid:
        """
        Загрузка SRTM HGT файла (NASA SRTM).
        
        Формат: 3601×3601 (SRTM3, 3 arcsec) или 1201×1201 (SRTM1, 1 arcsec)
        Данные: big-endian int16
        
        Имя файла: N50E030.hgt → широта 50°N, долгота 30°E
        """
        filename = os.path.basename(filepath)
        # Парсим координаты из имени
        lat_str = filename[1:3]
        lon_str = filename[4:7]
        lat_base = int(lat_str) if filename[0] == 'N' else -int(lat_str)
        lon_base = int(lon_str) if filename[3] == 'E' else -int(lon_str)
        
        # Определяем размер
        file_size = os.path.getsize(filepath)
        if file_size == 3601 * 3601 * 2:
            n = 3601  # SRTM3
        elif file_size == 1201 * 1201 * 2:
            n = 1201  # SRTM1
        else:
            n = int(math.sqrt(file_size / 2))
        
        # Читаем
        with open(filepath, 'rb') as f:
            data = struct.unpack(f'>{n*n}h', f.read(n * n * 2))
        
        elevations = np.array(data, dtype=np.float64).reshape(n, n)
        
        return DEMGrid(
            elevations=elevations,
            lat_min=lat_base,
            lat_max=lat_base + 1,
            lon_min=lon_base,
            lon_max=lon_base + 1,
            nodata=-32768.0,
            source=f"SRTM ({filename})"
        )
    
    @staticmethod
    def load_asc(filepath: str) -> DEMGrid:
        """
        Загрузка ESRI ASCIIGRID (.asc).
        
        Заголовок:
          ncols        3601
          nrows        3601
          xllcorner    30.0
          yllcorner    49.0
          cellsize     0.000833333
          NODATA_value -9999
        """
        with open(filepath, 'r') as f:
            header = {}
            data_lines = []
            in_data = False
            for line in f:
                line = line.strip()
                if not in_data:
                    if any(key in line.lower() for key in ['ncols', 'nrows', 'xll', 'yll', 'cellsize', 'nodata']):
                        parts = line.split()
                        header[parts[0].lower()] = float(parts[1])
                    else:
                        in_data = True
                        data_lines.append(line)
                else:
                    data_lines.append(line)
        
        ncols = int(header.get('ncols', 0))
        nrows = int(header.get('nrows', 0))
        nodata = header.get('nodata_value', -9999)
        
        lon_min = header.get('xllcorner', 0)
        lat_min = header.get('yllcorner', 0)
        cellsize = header.get('cellsize', 1.0)
        
        elevations = np.zeros((nrows, ncols))
        for i, line in enumerate(data_lines[:nrows]):
            vals = line.split()
            for j, v in enumerate(vals[:ncols]):
                elevations[i, j] = float(v)
        
        return DEMGrid(
            elevations=elevations,
            lat_min=lat_min,
            lat_max=lat_min + nrows * cellsize,
            lon_min=lon_min,
            lon_max=lon_min + ncols * cellsize,
            nodata=nodata,
            source=f"ASC ({os.path.basename(filepath)})"
        )
    
    @staticmethod
    def load_csv(filepath: str, 
                 lat_col: int = 0, lon_col: int = 1, elev_col: int = 2,
                 delimiter: str = ',') -> DEMGrid:
        """
        Загрузка CSV с колонками (lat, lon, elevation).
        Регулярная сетка восстанавливается автоматически.
        """
        data = np.loadtxt(filepath, delimiter=delimiter, skiprows=1)
        lats = data[:, lat_col]
        lons = data[:, lon_col]
        elevs = data[:, elev_col]
        
        unique_lats = np.sort(np.unique(lats))[::-1]  # Сверху вниз
        unique_lons = np.sort(np.unique(lons))
        
        n_lat = len(unique_lats)
        n_lon = len(unique_lons)
        elevations = np.full((n_lat, n_lon), -32768.0)
        
        for row in data:
            lat, lon, elev = row[lat_col], row[lon_col], row[elev_col]
            i = np.argmin(np.abs(unique_lats - lat))
            j = np.argmin(np.abs(unique_lons - lon))
            elevations[i, j] = elev
        
        return DEMGrid(
            elevations=elevations,
            lat_min=float(unique_lats[-1]),
            lat_max=float(unique_lats[0]),
            lon_min=float(unique_lons[0]),
            lon_max=float(unique_lons[-1]),
            nodata=-32768.0,
            source=f"CSV ({os.path.basename(filepath)})"
        )
    
    @staticmethod
    def load_npy(filepath: str, 
                 lat_range: Tuple[float, float] = (-90, 90),
                 lon_range: Tuple[float, float] = (-180, 180)) -> DEMGrid:
        """Загрузка NumPy массива"""
        elevations = np.load(filepath)
        return DEMGrid(
            elevations=elevations.astype(np.float64),
            lat_min=lat_range[0],
            lat_max=lat_range[1],
            lon_min=lon_range[0],
            lon_max=lon_range[1],
            source=f"NumPy ({os.path.basename(filepath)})"
        )
    
    @staticmethod
    def generate_synthetic(
        n_lat: int = 180, n_lon: int = 360,
        style: str = "earth_like"
    ) -> DEMGrid:
        """
        Генерация синтетического рельефа для тестирования.
        
        Стили:
          'earth_like' — горы + океаны + шум
          'flat'       — плоская поверхность
          'volcano'    — одиночный вулкан
          'etheria'    — рельеф Этерии (K=9/7 анизотропия)
        """
        lats = np.linspace(90, -90, n_lat)
        lons = np.linspace(-180, 180, n_lon)
        LON, LAT = np.meshgrid(lons, lats)
        LAT_r = np.radians(LAT)
        LON_r = np.radians(LON)
        
        if style == 'flat':
            elevations = np.zeros((n_lat, n_lon))
        
        elif style == 'earth_like':
            # Шум Перлина-подобный (сумма гармоник)
            elevations = np.zeros((n_lat, n_lon))
            for octave in range(6):
                freq = 2 ** octave
                amp = 2000.0 / freq
                phase_lat = np.random.uniform(0, 2 * math.pi)
                phase_lon = np.random.uniform(0, 2 * math.pi)
                elevations += amp * np.sin(freq * LAT_r + phase_lat) * np.cos(freq * LON_r + phase_lon)
            
            # Океаны: высота < 0 → вода
            ocean_mask = LAT_r < 0  # Упрощённо: южное полушарие — океан
            elevations[ocean_mask] -= 3000
            
            # Гималаи
            himalaya = 8000 * np.exp(-((LAT - 28)**2 / 200 + (LON - 85)**2 / 500))
            elevations += himalaya
            
            # Анды
            andes = 5000 * np.exp(-((LAT + 15)**2 / 300 + (LON + 70)**2 / 200))
            elevations += andes
        
        elif style == 'volcano':
            # Вулкан в центре
            d = np.sqrt(LAT**2 + LON**2)
            elevations = 4000 * np.exp(-d**2 / 100) - 1000
            # Кратер
            crater = np.exp(-d**2 / 5) * 500
            elevations -= crater * (d < 3)
        
        elif style == 'etheria':
            # Рельеф Этерии с K=9/7 анизотропией
            K = 9.0 / 7.0
            elevations = np.zeros((n_lat, n_lon))
            
            # Анизотропные горы (K-модулированные)
            for octave in range(5):
                freq = 2 ** octave
                amp = 1500.0 / freq * K
                elevations += amp * np.sin(freq * LAT_r * K) * np.cos(freq * LON_r)
            
            # Бездна (W → 0) в южных широтах
            abyss = -5000 * np.exp(-((LAT + 60)**2 / 200))
            elevations += abyss
            
            # Плато Сектора 4
            sector4 = 2000 * np.exp(-((LAT - 50)**2 / 100 + (LON - 35)**2 / 200))
            elevations += sector4
        
        else:
            elevations = np.zeros((n_lat, n_lon))
        
        return DEMGrid(
            elevations=elevations,
            lat_min=-90.0, lat_max=90.0,
            lon_min=-180.0, lon_max=180.0,
            source=f"synthetic_{style}"
        )


# ═══════════════════════════════════════════════════════════════
# 3. КОНВЕРТЕР DEM → P³
# ═══════════════════════════════════════════════════════════════

@dataclass
class P3TerrainPoint:
    """Точка рельефа в P³"""
    p3: HomVec4
    lat: float
    lon: float
    elevation: float
    W: float
    card: int  # Лучшая афинная карта


class DEMToP3:
    """
    Конвертер DEM → P³.
    
    Пайплайн:
      1. DEM (lat, lon, h) → (X, Y, Z) на сфере R + h
      2. (X, Y, Z) → HomVec4 с W-калибровкой
      3. Выбор лучшей афинной карты
      4. Downsampling (опционально)
    """
    
    def __init__(self, R_km: float = R_EARTH_KM, 
                 W_model: str = "distance",
                 max_points: int = 10000):
        """
        R_km: радиус планеты
        W_model: модель W-калибровки
          'distance'  — W = cos(s/2R) (стандартная)
          'elevation' — W пропорционально высоте
          'uniform'   — W = 1 (без калибровки)
        max_points: максимальное количество точек (downsampling)
        """
        self.R_km = R_km
        self.W_model = W_model
        self.max_points = max_points
    
    def _latlon_to_xyz(self, lat: float, lon: float, h_m: float) -> Tuple[float, float, float]:
        """(lat, lon, h) → (X, Y, Z) в км"""
        lat_r = math.radians(lat)
        lon_r = math.radians(lon)
        r = self.R_km + h_m / 1000.0  # км
        X = r * math.cos(lat_r) * math.cos(lon_r)
        Y = r * math.cos(lat_r) * math.sin(lon_r)
        Z = r * math.sin(lat_r)
        return X, Y, Z
    
    def _compute_W(self, lat: float, lon: float, h_m: float,
                   h_min: float, h_max: float) -> float:
        """Вычислить W для данной точки"""
        if self.W_model == 'distance':
            # Стандартная: W = cos(s/2R)
            # s — расстояние от наблюдателя (0,0,0,1)
            X, Y, Z = self._latlon_to_xyz(lat, lon, h_m)
            norm = math.sqrt(X*X + Y*Y + Z*Z + 1.0)  # +1 for W-component
            # cos угла с (0,0,0,1)
            W = 1.0 / norm if norm > 0 else 1.0
            return W
        
        elif self.W_model == 'elevation':
            # W пропорционально высоте
            if h_max == h_min:
                return 1.0
            return 0.5 + 0.5 * (h_m - h_min) / (h_max - h_min)
        
        elif self.W_model == 'uniform':
            return 1.0
        
        else:
            return 1.0
    
    def convert(self, dem: DEMGrid, 
                downsample: int = 1) -> List[P3TerrainPoint]:
        """
        Конвертировать DEM → P³ точки.
        
        downsample: шаг выборки (1 = все точки, 4 = каждый 4-й)
        """
        stats = dem.stats()
        h_min = stats['min']
        h_max = stats['max']
        
        points = []
        step_lat = max(1, downsample)
        step_lon = max(1, downsample)
        
        for i in range(0, dem.n_lat, step_lat):
            for j in range(0, dem.n_lon, step_lon):
                h = dem.elevations[i, j]
                if h == dem.nodata:
                    continue
                
                lat, lon = dem.lat_lon(i, j)
                X, Y, Z = self._latlon_to_xyz(lat, lon, h)
                W = self._compute_W(lat, lon, h, h_min, h_max)
                
                p3 = HomVec4(X, Y, Z, W).normalize()
                
                # Выбор лучшей афинной карты
                v = p3.v
                abs_v = np.abs(v)
                card = int(np.argmax(abs_v))
                
                points.append(P3TerrainPoint(
                    p3=p3, lat=lat, lon=lon,
                    elevation=h, W=W, card=card
                ))
        
        # Downsampling если слишком много точек
        if len(points) > self.max_points:
            indices = np.linspace(0, len(points)-1, self.max_points, dtype=int)
            points = [points[i] for i in indices]
        
        return points
    
    def convert_to_json(self, dem: DEMGrid, 
                        downsample: int = 4) -> dict:
        """Конвертировать DEM → JSON для визуализации в браузере"""
        points = self.convert(dem, downsample)
        return {
            'type': 'P3_terrain',
            'source': dem.source,
            'n_points': len(points),
            'R_km': self.R_km,
            'W_model': self.W_model,
            'dem_stats': dem.stats(),
            'points': [
                {
                    'X': p.p3.v[0], 'Y': p.p3.v[1],
                    'Z': p.p3.v[2], 'W': p.p3.v[3],
                    'lat': p.lat, 'lon': p.lon,
                    'elevation': p.elevation,
                    'card': p.card
                }
                for p in points
            ],
            'card_counts': {
                'UW': sum(1 for p in points if p.card == 0),
                'UX': sum(1 for p in points if p.card == 1),
                'UY': sum(1 for p in points if p.card == 2),
                'UZ': sum(1 for p in points if p.card == 3)
            }
        }
    
    def compute_p3_statistics(self, points: List[P3TerrainPoint]) -> Dict:
        """
        Статистика рельефа в P³ метрике.
        
        Ключевой вопрос: чем P³-статистика отличается от R³?
        """
        if len(points) < 2:
            return {}
        
        # Расстояния Фубини-Штуди между соседними точками
        d_fs_values = []
        for i in range(len(points) - 1):
            d = fs_distance(points[i].p3, points[i+1].p3)
            d_fs_values.append(d)
        
        d_fs_arr = np.array(d_fs_values)
        
        # Распределение по картам
        card_dist = np.zeros(4)
        for p in points:
            card_dist[p.card] += 1
        card_dist /= len(points)
        
        # W-статистика
        W_values = np.array([p.W for p in points])
        
        return {
            'n_points': len(points),
            'd_fs': {
                'min': float(np.min(d_fs_arr)),
                'max': float(np.max(d_fs_arr)),
                'mean': float(np.mean(d_fs_arr)),
                'std': float(np.std(d_fs_arr))
            },
            'W': {
                'min': float(np.min(W_values)),
                'max': float(np.max(W_values)),
                'mean': float(np.mean(W_values)),
                'std': float(np.std(W_values)),
                'n_near_zero': int(np.sum(np.abs(W_values) < 0.1))
            },
            'card_distribution': {
                'UW': float(card_dist[0]),
                'UX': float(card_dist[1]),
                'UY': float(card_dist[2]),
                'UZ': float(card_dist[3])
            },
            'antipodal_pairs': int(np.sum(W_values < 0))
        }


# ═══════════════════════════════════════════════════════════════
# 4. ДЕМО
# ═══════════════════════════════════════════════════════════════

def demo_dem_import():
    """Демо: синтетический рельеф Земли → P³"""
    print("=" * 64)
    print("  DEM → P³ ИМПОРТ РЕЛЬЕФА v1.0")
    print("=" * 64)
    
    # Генерируем синтетический рельеф
    print("\n[1] Генерация синтетического рельефа 'earth_like'...")
    dem = DEMLoader.generate_synthetic(n_lat=180, n_lon=360, style='earth_like')
    stats = dem.stats()
    print(f"  Размер: {dem.n_lat}×{dem.n_lon} = {dem.n_lat * dem.n_lon} точек")
    print(f"  Высоты: [{stats['min']:.0f}, {stats['max']:.0f}] м, средняя: {stats['mean']:.0f} м")
    
    # Конвертируем в P³
    print("\n[2] Конвертация в P³ (downsample=4)...")
    converter = DEMToP3(R_km=R_EARTH_KM, W_model='distance', max_points=5000)
    points = converter.convert(dem, downsample=4)
    print(f"  Точек в P³: {len(points)}")
    
    # P³-статистика
    print("\n[3] P³-статистика рельефа...")
    p3_stats = converter.compute_p3_statistics(points)
    print(f"  d_FS: [{p3_stats['d_fs']['min']:.6f}, {p3_stats['d_fs']['max']:.6f}]")
    print(f"        среднее: {p3_stats['d_fs']['mean']:.6f} ± {p3_stats['d_fs']['std']:.6f}")
    print(f"  W:   [{p3_stats['W']['min']:.6f}, {p3_stats['W']['max']:.6f}]")
    print(f"        среднее: {p3_stats['W']['mean']:.6f}")
    print(f"        точек у горизонта (|W|<0.1): {p3_stats['W']['n_near_zero']}")
    print(f"  Карты: UW={p3_stats['card_distribution']['UW']:.3f} "
          f"UX={p3_stats['card_distribution']['UX']:.3f} "
          f"UY={p3_stats['card_distribution']['UY']:.3f} "
          f"UZ={p3_stats['card_distribution']['UZ']:.3f}")
    
    # Рельеф Этерии
    print("\n[4] Рельеф Этерии (K=9/7 анизотропия)...")
    dem_etheria = DEMLoader.generate_synthetic(n_lat=180, n_lon=360, style='etheria')
    converter_e = DEMToP3(R_km=R_ETERIA_KM, W_model='distance', max_points=5000)
    points_e = converter_e.convert(dem_etheria, downsample=4)
    p3_stats_e = converter_e.compute_p3_statistics(points_e)
    print(f"  Точек в P³: {len(points_e)}")
    print(f"  R_Этерии = {R_ETERIA_KM} км")
    print(f"  d_FS: среднее = {p3_stats_e['d_fs']['mean']:.6f}")
    print(f"  W:   среднее = {p3_stats_e['W']['mean']:.6f}, "
          f"у горизонта: {p3_stats_e['W']['n_near_zero']}")
    
    # JSON экспорт
    print("\n[5] JSON экспорт для визуализации...")
    json_data = converter.convert_to_json(dem, downsample=8)
    print(f"  Точек: {json_data['n_points']}")
    print(f"  Карты: {json_data['card_counts']}")
    
    print("\n✓ Демо DEM→P³ завершено")


if __name__ == "__main__":
    demo_dem_import()
