#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P³×R ПРОСТРАНСТВО-ВРЕМЯ v1.0
==============================

Расширение P³ до P³×R — проективное пространство + время.

Архитектура:
  - SpacetimePoint = (HomVec4, t) — точка в P³×R
  - Причинная структура: d_FS + |Δt|/c_eff → световой конус
  - Мировая линия = кривая в P³×R, параметризованная по t
  - Эволюция мира: Worldline → EndogenousFlow(t) → следующее состояние
  - Π_Λ каузальный проектор: отсеивает непричинные связи

Ключевые формулы:
  d_causal(p1, p2) = d_FS(p1.p3, p2.p3) - |p1.t - p2.t| / c_eff

  Если d_causal ≤ 0  →  p2 в будущем светового конуса p1 (причинно связано)
  Если d_causal > 0  →  пространственноподобное разделение (некомуникационно)

  c_eff = c × K_ANISO × W_avg  — эффективная скорость света на P³
  (анизотропия + W-калибровка замедляют propagation)

Интеграция с ядром:
  from kernel.p3_kernel import HomVec4, fs_distance, K_ANISO
  from kernel.extensions.spacetime import SpacetimePoint, CausalStructure
"""

import math
import numpy as np
from typing import List, Tuple, Optional, Dict, NamedTuple
from dataclasses import dataclass, field
from enum import IntEnum

# ═══════════════════════════════════════════════════════════════
# 0. ЗАВИСИМОСТИ ОТ ЯДРА
# ═══════════════════════════════════════════════════════════════

import sys
import os
_kernel_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _kernel_dir not in sys.path:
    sys.path.insert(0, _kernel_dir)

from p3_kernel import (
    HomVec4, fs_distance, K_ANISO, R_ETERIA_KM, W_EPS,
    w_from_distance, s_from_W, RESONANCE_HZ
)

# ═══════════════════════════════════════════════════════════════
# 1. ФИЗИЧЕСКИЕ КОНСТАНТЫ P³×R
# ═══════════════════════════════════════════════════════════════

C_LIGHT_KM_S = 299792.458       # Скорость света (км/с)
C_EFF_BASE = C_LIGHT_KM_S * K_ANISO  # Анизотропная поправка: c × 9/7
POLER_PERIOD_S = 1.0 / 18.7     # Период POLER-цикла (с)
TIMELIKE_THRESHOLD = 1e-10      # Порог для различения time/spacelike
LIGHT_CONE_APERTURE = math.pi / 2  # Апертура светового конуса на P³


# ═══════════════════════════════════════════════════════════════
# 2. ТОЧКА В P³×R
# ═══════════════════════════════════════════════════════════════

@dataclass
class SpacetimePoint:
    """
    Точка в P³×R: пространственная часть в P³ + временная координата.
    
    Атрибуты:
      p3: HomVec4 — точка в P³ (пространство)
      t: float — временная координата (секунды)
      label: str — метка (название узла/города/сектора)
      metadata: dict — дополнительные данные
    """
    p3: HomVec4
    t: float = 0.0
    label: str = ""
    metadata: dict = field(default_factory=dict)
    
    @property
    def W(self) -> float:
        """W-координата (калибровочная)"""
        return self.p3.v[3]
    
    @property
    def x_y_z_w(self) -> Tuple[float, float, float, float]:
        """Однородные координаты (X, Y, Z, W)"""
        v = self.p3.v
        return (v[0], v[1], v[2], v[3])
    
    def at_time(self, new_t: float) -> 'SpacetimePoint':
        """Та же пространственная точка в другой момент времени"""
        return SpacetimePoint(self.p3, new_t, self.label + "'", dict(self.metadata))


# ═══════════════════════════════════════════════════════════════
# 3. КАУЗАЛЬНАЯ СТРУКТУРА
# ═══════════════════════════════════════════════════════════════

class CausalRelation(IntEnum):
    """Каузальное отношение между двумя событиями в P³×R"""
    TIMELIKE_FUTURE = 1      # p2 в будущем p1 (причинно связано)
    TIMELIKE_PAST = 2        # p2 в прошлом p1
    LIGHTLIKE = 3            # На световом конусе (нуевой интервал)
    SPACELIKE = 4            # Пространственноподобное (некоммуникационно)
    Z2Z_TUNNEL = 5           # Связь через Z/2Z-туннель (антиподальная)


@dataclass
class CausalInterval:
    """Каузальный интервал между двумя событиями"""
    p1: SpacetimePoint
    p2: SpacetimePoint
    d_fs: float                    # Фубини-Штуди расстояние
    dt: float                      # Временная разница
    d_causal: float                # Каузальный интервал
    relation: CausalRelation       # Тип отношения
    c_eff: float                   # Эффективная скорость света
    
    @property
    def is_causal(self) -> bool:
        """Можно ли передать сигнал от p1 к p2?"""
        return self.relation in (
            CausalRelation.TIMELIKE_FUTURE,
            CausalRelation.LIGHTLIKE,
            CausalRelation.Z2Z_TUNNEL
        )


class CausalStructure:
    """
    Каузальная структура P³×R — определяет, какие события могут влиять
    друг на друга через световые конусы, деформированные анизотропией.
    """
    
    def __init__(self, c_eff: float = C_EFF_BASE):
        self.c_eff = c_eff
        self._cone_cache: Dict[Tuple[int, int], CausalInterval] = {}
    
    def effective_speed(self, p: SpacetimePoint) -> float:
        """
        Эффективная скорость света в точке p ∈ P³×R.
        
        c_eff(p) = c × K_ANISO × |W(p)|
        
        W-калибровка: ближе к W=0 свет «замедляется» — 
        это горизонт событий (объекты исчезают).
        """
        W_abs = min(abs(p.W), 1.0)
        if W_abs < W_EPS:
            return 0.0  # Горизонт событий — свет не проходит
        return self.c_eff * W_abs
    
    def classify(self, p1: SpacetimePoint, p2: SpacetimePoint) -> CausalInterval:
        """
        Классифицировать каузальное отношение p1 → p2.
        
        d_causal = d_FS(p1, p2) - |Δt| / c_eff_avg
        
        d_causal < 0 → timelike (причинно связано)
        d_causal = 0 → lightlike (на конусе)
        d_causal > 0 → spacelike (некоммуникационно)
        """
        d_fs = fs_distance(p1.p3, p2.p3)
        dt = p2.t - p1.t
        
        # Средняя эффективная скорость на интервале
        c1 = self.effective_speed(p1)
        c2 = self.effective_speed(p2)
        c_avg = (c1 + c2) / 2.0 if (c1 + c2) > 0 else self.c_eff
        
        # Каузальный интервал
        if c_avg > 0:
            d_causal = d_fs - abs(dt) / c_avg
        else:
            d_causal = float('inf')  # Оба на горизонте — нет причинной связи
        
        # Классификация
        if d_causal < -TIMELIKE_THRESHOLD:
            if dt > 0:
                relation = CausalRelation.TIMELIKE_FUTURE
            else:
                relation = CausalRelation.TIMELIKE_PAST
        elif abs(d_causal) <= TIMELIKE_THRESHOLD:
            relation = CausalRelation.LIGHTLIKE
        else:
            # Проверяем Z/2Z-туннель: если точки антиподальные
            dot = abs(np.dot(p1.p3.v, p2.p3.v))
            if dot < 0.1:  # Почти ортогональные → антиподальные на RP³
                relation = CausalRelation.Z2Z_TUNNEL
            else:
                relation = CausalRelation.SPACELIKE
        
        return CausalInterval(
            p1=p1, p2=p2,
            d_fs=d_fs, dt=dt,
            d_causal=d_causal,
            relation=relation,
            c_eff=c_avg
        )
    
    def future_cone(self, origin: SpacetimePoint, points: List[SpacetimePoint]) -> List[CausalInterval]:
        """Все точки в будущем световом конусе origin"""
        results = []
        for p in points:
            interval = self.classify(origin, p)
            if interval.relation in (CausalRelation.TIMELIKE_FUTURE, CausalRelation.LIGHTLIKE):
                results.append(interval)
        return results
    
    def causal_diamond(self, p1: SpacetimePoint, p2: SpacetimePoint, 
                       points: List[SpacetimePoint]) -> List[SpacetimePoint]:
        """
        Каузальный ромб I⁺(p1) ∩ I⁻(p2) — область, причинно 
        зависящая от обоих событий.
        """
        diamond = []
        for p in points:
            i1 = self.classify(p1, p)
            i2 = self.classify(p, p2)
            # p в будущем p1 И p2 в будущем p
            if (i1.relation in (CausalRelation.TIMELIKE_FUTURE, CausalRelation.LIGHTLIKE) and
                i2.relation in (CausalRelation.TIMELIKE_FUTURE, CausalRelation.LIGHTLIKE)):
                diamond.append(p)
        return diamond


# ═══════════════════════════════════════════════════════════════
# 4. МИРОВАЯ ЛИНИЯ
# ═══════════════════════════════════════════════════════════════

@dataclass
class WorldlineSegment:
    """Сегмент мировой линии между двумя событиями"""
    p_start: SpacetimePoint
    p_end: SpacetimePoint
    interval: CausalInterval
    proper_time: float = 0.0  # Собственное время вдоль сегмента


class Worldline:
    """
    Мировая линия — кривая в P³×R, параметризованная по t.
    
    Реализация: последовательность SpacetimePoint,
    связанных каузальными интервалами.
    """
    
    def __init__(self, label: str = "", color: str = "#7af"):
        self.label = label
        self.color = color
        self.events: List[SpacetimePoint] = []
        self.segments: List[WorldlineSegment] = []
        self.causal = CausalStructure()
    
    def add_event(self, p: SpacetimePoint) -> None:
        """Добавить событие на мировую линию"""
        if self.events:
            prev = self.events[-1]
            interval = self.causal.classify(prev, p)
            # Собственное время: ∫√(dτ²) ≈ |Δt| для timelike
            if interval.relation in (CausalRelation.TIMELIKE_FUTURE, CausalRelation.LIGHTLIKE):
                proper_time = abs(p.t - prev.t)
            else:
                proper_time = 0.0
            self.segments.append(WorldlineSegment(prev, p, interval, proper_time))
        self.events.append(p)
    
    @property
    def total_proper_time(self) -> float:
        """Полное собственное время вдоль мировой линии"""
        return sum(seg.proper_time for seg in self.segments)
    
    @property
    def is_causal(self) -> bool:
        """Является ли мировая линия причинной (все сегменты timelike/lightlike)?"""
        return all(
            seg.interval.relation in (
                CausalRelation.TIMELIKE_FUTURE,
                CausalRelation.LIGHTLIKE
            )
            for seg in self.segments
        )
    
    @property
    def has_z2z_tunneling(self) -> bool:
        """Проходит ли мировая линия через Z/2Z-туннель?"""
        return any(
            seg.interval.relation == CausalRelation.Z2Z_TUNNEL
            for seg in self.segments
        )
    
    def interpolate(self, t: float) -> SpacetimePoint:
        """
        Интерполировать мировую линию в момент t.
        Геодезическая интерполяция на P³ + линейная по t.
        """
        if not self.events:
            raise ValueError("Пустая мировая линия")
        if t <= self.events[0].t:
            return self.events[0]
        if t >= self.events[-1].t:
            return self.events[-1]
        
        # Найти сегмент
        for seg in self.segments:
            if seg.p_start.t <= t <= seg.p_end.t:
                dt_total = seg.p_end.t - seg.p_start.t
                if dt_total == 0:
                    return seg.p_start
                alpha = (t - seg.p_start.t) / dt_total
                
                # Геодезическая интерполяция на P³ (сферическая)
                v1 = seg.p_start.p3.v / np.linalg.norm(seg.p_start.p3.v)
                v2 = seg.p_end.p3.v / np.linalg.norm(seg.p_end.p3.v)
                dot = np.clip(np.dot(v1, v2), -1.0, 1.0)
                theta = math.acos(dot)
                
                if theta < 1e-10:
                    v_interp = v1
                else:
                    # SLERP на S³
                    v_interp = (math.sin((1-alpha)*theta) * v1 + math.sin(alpha*theta) * v2) / math.sin(theta)
                
                p3 = HomVec4(*v_interp)
                return SpacetimePoint(p3, t, self.label)
        
        return self.events[-1]


# ═══════════════════════════════════════════════════════════════
# 5. ЭВОЛЮЦИЯ МИРА
# ═══════════════════════════════════════════════════════════════

class WorldEvolution:
    """
    Эволюция мира на P³×R — шаги времени с эндогенным течением.
    
    Каждый шаг:
      1. Применяем эндогенное течение к каждой мировой линии
      2. Вычисляем каузальную структуру
      3. Вычисляем Π_Λ каузальный проектор
      4. Записываем новые события
    """
    
    def __init__(self, dt: float = POLER_PERIOD_S):
        self.dt = dt  # Шаг времени (по умолчанию = период POLER)
        self.t = 0.0  # Текущее время
        self.worldlines: List[Worldline] = []
        self.causal = CausalStructure()
        self.history: List[Dict] = []  # Слепки состояния
        self._step_count = 0
    
    def add_worldline(self, wl: Worldline) -> None:
        self.worldlines.append(wl)
    
    def step(self) -> Dict:
        """
        Один шаг эволюции мира.
        
        Возвращает слепок состояния: {
          't': текущее время,
          'events': [(label, t, x, y, z, w), ...],
          'causal_links': [(i, j, relation), ...],
          'resonance': текущий резонанс
        }
        """
        self.t += self.dt
        self._step_count += 1
        
        new_events = []
        for wl in self.worldlines:
            if wl.events:
                last = wl.events[-1]
                # Эндогенное течение: PGL(4) действует на последнюю точку
                # Упрощённая модель: малое вращение + W-затухание
                v = last.p3.v.copy()
                norm = np.linalg.norm(v)
                if norm > 1e-15:
                    v /= norm
                
                # Малое вращение (эндогенный поток)
                angle = 0.01 * math.sin(2 * math.pi * 18.7 * self.t)
                c, s = math.cos(angle), math.sin(angle)
                # Вращение в плоскости XW (Z/2Z-основа)
                new_v = np.array([
                    c * v[0] + s * v[3],
                    v[1],
                    v[2],
                    -s * v[0] + c * v[3]
                ])
                
                new_p3 = HomVec4(*new_v).normalize()
                new_point = SpacetimePoint(new_p3, self.t, last.label, dict(last.metadata))
                wl.add_event(new_point)
                new_events.append(new_point)
        
        # Каузальные связи
        causal_links = []
        all_points = []
        for wl in self.worldlines:
            if wl.events:
                all_points.append(wl.events[-1])
        
        for i, p1 in enumerate(all_points):
            for j, p2 in enumerate(all_points):
                if i < j:
                    interval = self.causal.classify(p1, p2)
                    if interval.is_causal:
                        causal_links.append((i, j, interval.relation.name))
        
        # Резонанс Бездны 18.7 Гц
        resonance = math.sin(2 * math.pi * RESONANCE_HZ * self.t)
        
        # Слепок
        snapshot = {
            't': self.t,
            'step': self._step_count,
            'events': [
                (p.label, p.t, *p.x_y_z_w) for p in all_points
            ],
            'causal_links': causal_links,
            'resonance': resonance,
            'n_causal': len(causal_links)
        }
        self.history.append(snapshot)
        return snapshot
    
    def evolve(self, n_steps: int) -> List[Dict]:
        """Эволюция мира на n_steps"""
        return [self.step() for _ in range(n_steps)]
    
    def pi_lambda_projector(self) -> np.ndarray:
        """
        Π_Λ Каузальный проектор — отсеивает непричинные связи.
        
        Возвращает матрицу связности: C[i,j] = 1 если i→j причинно.
        """
        n = len(self.worldlines)
        C = np.zeros((n, n))
        
        for i in range(n):
            for j in range(n):
                if i != j and self.worldlines[i].events and self.worldlines[j].events:
                    pi = self.worldlines[i].events[-1]
                    pj = self.worldlines[j].events[-1]
                    interval = self.causal.classify(pi, pj)
                    if interval.is_causal:
                        C[i, j] = 1.0
        
        return C


# ═══════════════════════════════════════════════════════════════
# 6. ЭКСПОРТ
# ═══════════════════════════════════════════════════════════════

def export_spacetime_json(evolution: WorldEvolution) -> dict:
    """Экспорт состояния P³×R в JSON для визуализации"""
    return {
        'type': 'P3xR_spacetime',
        't_current': evolution.t,
        'dt': evolution.dt,
        'n_worldlines': len(evolution.worldlines),
        'worldlines': [
            {
                'label': wl.label,
                'color': wl.color,
                'is_causal': wl.is_causal,
                'has_z2z_tunneling': wl.has_z2z_tunneling,
                'proper_time': wl.total_proper_time,
                'events': [
                    {
                        't': e.t,
                        'X': e.p3.v[0], 'Y': e.p3.v[1],
                        'Z': e.p3.v[2], 'W': e.p3.v[3],
                        'label': e.label
                    }
                    for e in wl.events
                ]
            }
            for wl in evolution.worldlines
        ],
        'pi_lambda': evolution.pi_lambda_projector().tolist(),
        'history': evolution.history[-10:]  # Последние 10 шагов
    }


# ═══════════════════════════════════════════════════════════════
# 7. ДЕМО
# ═══════════════════════════════════════════════════════════════

def demo_spacetime():
    """Демо P³×R пространство-время Этерии"""
    print("=" * 64)
    print("  P³×R ПРОСТРАНСТВО-ВРЕМЯ ЭТЕРИИ v1.0")
    print("=" * 64)
    
    # Создаём мировые линии для ключевых узлов
    nodes = [
        ("Киев", HomVec4(0.5, 0.3, 0.2, 0.8)),
        ("Сектор 4", HomVec4(0.4, 0.35, 0.25, 0.82)),
        ("Гиза", HomVec4(0.3, 0.5, 0.1, 0.75)),
        ("Одесса", HomVec4(0.45, 0.28, 0.18, 0.78)),
        ("Бездна", HomVec4(0.01, 0.01, 0.01, 0.001)),  # W ≈ 0
    ]
    
    evolution = WorldEvolution(dt=POLER_PERIOD_S)
    
    for name, p3 in nodes:
        wl = Worldline(label=name, color=f"#{hash(name) & 0xFFFFFF:06x}")
        sp = SpacetimePoint(p3.normalize(), 0.0, name)
        wl.add_event(sp)
        evolution.add_worldline(wl)
    
    print(f"\nСоздано {len(nodes)} мировых линий")
    print(f"Шаг времени: {evolution.dt*1000:.2f} мс (период POLER 18.7 Гц)")
    print(f"c_eff = {evolution.causal.c_eff:.2f} км/с (анизотропная)")
    
    # Эволюция на 20 шагов
    print(f"\nЭволюция мира на 20 шагов...")
    for i in range(20):
        snap = evolution.step()
        if i % 5 == 0:
            print(f"  t={snap['t']*1000:8.2f} мс | "
                  f"событий: {len(snap['events'])} | "
                  f"причинных связей: {snap['n_causal']} | "
                  f"резонанс: {snap['resonance']:.6f}")
    
    # Π_Λ проектор
    pi_lam = evolution.pi_lambda_projector()
    print(f"\nΠ_Λ каузальный проектор ({pi_lam.shape[0]}×{pi_lam.shape[1]}):")
    print(pi_lam.astype(int))
    
    # Каузальная структура между узлами
    print(f"\nКаузальные отношения (финальные):")
    wls = evolution.worldlines
    for i in range(len(wls)):
        for j in range(i+1, len(wls)):
            if wls[i].events and wls[j].events:
                pi = wls[i].events[-1]
                pj = wls[j].events[-1]
                interval = evolution.causal.classify(pi, pj)
                print(f"  {pi.label:10s} → {pj.label:10s} : "
                      f"{interval.relation.name:20s} | "
                      f"d_FS={interval.d_fs:.6f} | "
                      f"d_causal={interval.d_causal:.6f}")
    
    # Мировые линии
    print(f"\nМировые линии:")
    for wl in evolution.worldlines:
        print(f"  {wl.label:10s} | "
              f"τ={wl.total_proper_time*1000:.3f} мс | "
              f"причинная={'ДА' if wl.is_causal else 'НЕТ'} | "
              f"Z/2Z-туннель={'ДА' if wl.has_z2z_tunneling else 'НЕТ'} | "
              f"W_final={wl.events[-1].W:.6f}")
    
    print("\n✓ Демо P³×R завершено")


if __name__ == "__main__":
    demo_spacetime()
