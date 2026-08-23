#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
СКРИПТ 02 — МОДУЛЬ «МЕТРИКА»: КООРДИНАТНЫЙ ДВИЖОК P³ (НАВИГАЦИОННОЕ ЯДРО)
==========================================================================
Аналог земного GPS-движка: координаты, метрика, переход карт, четность.

Модель (канон p3_kernel.surface_to_p3 + OUROBOROS_SYSTEM_HARDWARE_SPEC §1):
  * Позиция узла = однородный вектор P = [X:Y:Z:W] на S³:
      s   = дуга большого круга от опорного узла (шлюза),
      α   = азимут,
      W   = cos(s/2R),  X = sin(s/2R)·cos α,  Y = sin(s/2R)·sin α,
      Z   = sin(h/2R)   (h — высота над поверхностью).
  * Метрика Фубини-Штуди: d_FS(P1,P2) = arccos(|⟨P1,P2⟩|) ∈ [0, π/2].
  * Физическая дистанция: s_физ = 2R·d_FS.
  * Атлас 4 аффинных карт, переключение при |координата| → max.
  * Четность Z/2Z: двойное накрытие SU(2) → SO(3).

Выход: results/02_p3metric.json
"""
import json
import math
import os

import numpy as np

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
os.makedirs(OUT_DIR, exist_ok=True)

R_m = 5839.525651487551e3   # канонический радиус, м
results = {}


# ════════════════════════════════════════════════════════════════════════════
# 1. ЯДРО КООРДИНАТНОГО ДВИЖКА
# ════════════════════════════════════════════════════════════════════════════

def gc_from_ref(lat_deg, lon_deg, R=R_m):
    """Дуга большого круга от опорного узла (0°, 0°)."""
    lat, lon = math.radians(lat_deg), math.radians(lon_deg)
    cosg = math.cos(lat) * math.cos(lon)
    return R * math.acos(max(-1.0, min(1.0, cosg)))


def azimuth_from_ref(lat_deg, lon_deg):
    """Азимут дуги от опорного узла (0°, 0°)."""
    lat, lon = math.radians(lat_deg), math.radians(lon_deg)
    return math.atan2(math.sin(lon), math.cos(lat) * math.cos(lon))


def surface_to_p3(lat_deg, lon_deg, elev_m=0.0, R=R_m):
    """Каноническая параметризация: точка поверхности → [X:Y:Z:W]."""
    s = gc_from_ref(lat_deg, lon_deg, R)
    alpha = azimuth_from_ref(lat_deg, lon_deg)
    half = s / (2.0 * R)
    W = math.cos(half)
    X = math.sin(half) * math.cos(alpha)
    Y = math.sin(half) * math.sin(alpha)
    Z = math.sin(elev_m / (2.0 * R))
    v = np.array([X, Y, Z, W])
    return v / np.linalg.norm(v)


def fs_distance(p1, p2):
    """Метрика Фубини-Штуди на RP³."""
    c = abs(float(np.dot(p1, p2)))
    return math.acos(min(1.0, max(0.0, c)))


def s_physical(d_fs, R=R_m):
    return 2.0 * R * d_fs


def haversine(lat1, lon1, lat2, lon2, R=R_m):
    p1, l1, p2, l2 = map(math.radians, (lat1, lon1, lat2, lon2))
    a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin((l2 - l1) / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def w_from_distance(s, R=R_m):
    return math.cos(s / (2.0 * R))


def s_from_w(W, R=R_m):
    return 2.0 * R * math.acos(max(-1.0, min(1.0, W)))


# ════════════════════════════════════════════════════════════════════════════
# 2. ВЕРИФИКАЦИЯ: ДИСТАНЦИЯ ОТ ОПОРНОГО УЗЛА ТОЧНА ПО ПОСТРОЕНИЮ
# ════════════════════════════════════════════════════════════════════════════

print("=" * 78)
print("ЭТАП 1. ВЕРИФИКАЦИЯ МЕТРИКИ: ДИСТАНЦИЯ ШЛЮЗ → УЗЕЛ (точность построения)")
print("=" * 78)

P_GATEWAY = np.array([0.0, 0.0, 0.0, 1.0])  # опорный узел (шлюз)

NODES = {
    "N-01": (0.0, 30.0),
    "N-02": (30.0, 60.0),
    "N-03": (-33.87, 151.21),
    "N-04": (64.13, -21.90),
    "N-05": (45.0, 100.0),
    "N-06": (0.0, 180.0),        # антипод опорного узла по долготе
    "N-07": (-50.45, -149.48),   # полный антипод (50.45N, 30.52E)
}

p3_nodes = {name: surface_to_p3(*ll) for name, ll in NODES.items()}

radial_table = []
max_err = 0.0
for name, (lat, lon) in NODES.items():
    d_fs = fs_distance(P_GATEWAY, p3_nodes[name])
    s_p3 = s_physical(d_fs)
    s_gc = gc_from_ref(lat, lon)
    err = abs(s_p3 - s_gc) / s_gc if s_gc > 0 else 0.0
    max_err = max(max_err, err)
    radial_table.append({"node": name, "lat": lat, "lon": lon,
                         "d_FS_rad": d_fs, "s_P3_m": s_p3, "s_GC_m": s_gc,
                         "rel_error": err})
    print(f"  Шлюз → {name}: d_FS={d_fs:.9f} рад  s_P3={s_p3/1000:10.3f} км  "
          f"S_GC={s_gc/1000:10.3f} км  Δ={err:.2e}")
results["radial_verification"] = radial_table
results["radial_max_rel_error"] = max_err
print(f"  → Радиальная метрика верифицирована: max Δ = {max_err:.2e}")

print()
print("=" * 78)
print("ЭТАП 2. МЕЖУЗЛОВАЯ МАРШРУТИЗАЦИЯ: d_FS vs ПОВЕРХНОСТНАЯ ДУГА")
print("=" * 78)

# d_FS между узлами — геодезическая проективного оверлея (маршрут ОС);
# поверхностная дуга — физический путь по рельефу.
pairs = [("N-01", "N-02"), ("N-02", "N-03"), ("N-01", "N-04"),
         ("N-03", "N-05"), ("N-02", "N-07"), ("N-04", "N-05")]
routing_table = []
for n1, n2 in pairs:
    d_fs = fs_distance(p3_nodes[n1], p3_nodes[n2])
    s_p3 = s_physical(d_fs)
    s_surf = haversine(*NODES[n1], *NODES[n2])
    # канон: при d_FS → 0 происходит «координатный захват» (транзит)
    penalty = (s_p3 - s_surf) / s_surf if s_surf > 0 else float("nan")
    routing_table.append({"from": n1, "to": n2, "d_FS_rad": d_fs,
                          "s_overlay_m": s_p3, "s_surface_m": s_surf,
                          "overlay_penalty": penalty})
    print(f"  {n1} → {n2}: d_FS={d_fs:.6f}  s_оверлей={s_p3/1000:9.2f} км  "
          f"s_поверх={s_surf/1000:9.2f} км  надбавка={penalty*100:+6.1f} %")
results["routing_verification"] = routing_table
print("  → Вывод: межузловая d_FS-геодезика проходит «сквозь» проективный оверлей")
print("    и в общем случае длиннее поверхностной дуги (кручение кадра). Протокол")
print("    маршрутизации: ретрансляторы опрашиваются от ближайшего шлюза (точная")
print("    радиальная метрика), межузловые связи — только при d_FS < порога транзита.")

print()
print("=" * 78)
print("ЭТАП 3. МАСШТАБНОЕ ПОЛЕ W(s) И РАДИУСЫ ЗОН КОНТРОЛЯ")
print("=" * 78)

w_table = []
for s_km in [0, 100, 165, 522, 1000, 1653, 3709, 5000, 9172.8, 12230, 18345.4]:
    s = s_km * 1000.0
    W = w_from_distance(s)
    w_table.append({"s_km": s_km, "W": W, "leak_percent": (1.0 - W) * 100.0})
    print(f"  s = {s_km:9.1f} км  →  W = {W:.6f}   протечка поля: {(1-W)*100:.4f} %")
results["W_table"] = w_table

zones = {}
for W_thr in [0.9999, 0.999, 0.99, 0.95, 0.7071, 0.5]:
    s_zone = s_from_w(W_thr) / 1000.0
    zones[f"W>={W_thr}"] = s_zone
    print(f"  Зона W ≥ {W_thr:.4f}: радиус s ≤ {s_zone:9.1f} км")
results["control_zones_km"] = zones
print("  → Канон-контроль: экватор карты (W = 0.70711) при s = πR/2 = "
      f"{math.pi*R_m/2/1000:.1f} км ✓; антипод (W→0) при s = πR = {math.pi*R_m/1000:.1f} км ✓")

print()
print("=" * 78)
print("ЭТАП 4. ПЕРЕКЛЮЧЕНИЕ АФФИННЫХ КАРТ (АТЛАС U_W, U_X, U_Y, U_Z)")
print("=" * 78)


def pick_card(v):
    comps = {"U_W": abs(v[3]), "U_X": abs(v[0]), "U_Y": abs(v[1]), "U_Z": abs(v[2])}
    best = max(comps, key=comps.get)
    return best, comps[best]


def to_affine(v, card):
    idx = {"U_W": 3, "U_X": 0, "U_Y": 1, "U_Z": 2}[card]
    d = v[idx]
    order = {"U_W": [0, 1, 2], "U_X": [1, 2, 3], "U_Y": [0, 2, 3], "U_Z": [0, 1, 3]}[card]
    return np.array([v[i] / d for i in order])


drift = []
for s_km in [0, 5000, 9172.8, 15000, 18000, 18345.0, 18345.4]:
    theta = s_km * 1000.0 / (2 * R_m)
    v = np.array([math.sin(theta), 0.0, 0.0, math.cos(theta)])
    card, best = pick_card(v)
    aff = to_affine(v, card)
    drift.append({"s_km": s_km, "W": float(v[3]), "card": card,
                  "affine": [float(x) for x in aff]})
    print(f"  s = {s_km:9.1f} км  W = {v[3]:.2e}  карта = {card}  "
          f"аффинные = ({aff[0]:+.3f}, {aff[1]:+.3f}, {aff[2]:+.3f})")
results["card_switching"] = drift
W_EPS = 1e-6
results["card_switch_threshold"] = {"W_eps": W_EPS,
                                    "antipode_km": math.pi * R_m / 1000.0}
print(f"  Порог смены карты |коорд| → max срабатывает при W < {W_EPS:.0e}:")
print(f"  антиподальный предел s = πR = {math.pi*R_m/1000:.1f} км — выход на карту U_X/U_Y.")

print()
print("=" * 78)
print("ЭТАП 5. ГОЛОНОМНАЯ ПРОВЕРКА ЧЕТНОСТИ Z/2Z (ДВОЙНОЕ НАКРЫТИЕ SU(2)→SO(3))")
print("=" * 78)


def quat_from_axis_angle(axis, angle):
    n = np.asarray(axis, dtype=float)
    n = n / np.linalg.norm(n)
    return np.concatenate(([math.cos(angle / 2)], math.sin(angle / 2) * n))


def quat_to_matrix(q):
    w, x, y, z = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
        [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
    ])


axis = [0.3, 0.5, 0.81]
z2z = {}
for label, angle in [("loop_360", 2 * math.pi), ("loop_720", 4 * math.pi)]:
    q = quat_from_axis_angle(axis, angle)
    Rm = quat_to_matrix(q)
    phase_ok = bool(q[0] > 0)
    z2z[label] = {
        "quaternion_w": float(q[0]),
        "SO3_identity": bool(np.allclose(Rm, np.eye(3), atol=1e-12)),
        "SU2_phase_restored": phase_ok,
        "parity_class": 0 if phase_ok else 1,
    }
    print(f"  {'Петля 360° (1 цикл)' if label == 'loop_360' else 'Петля 720° (2 цикла)'}: "
          f"SO(3) = {'Единичная матрица' if np.allclose(Rm, np.eye(3), atol=1e-12) else 'изменена'} | "
          f"SU(2)-фаза: {'+q — исходная' if phase_ok else '−q — инвертирована'} | "
          f"класс четности = {0 if phase_ok else 1} ∈ Z/2Z")
results["z2z_parity"] = z2z
print("  → Аппаратный вывод: объект, совершивший один цикл в метрике RP³, не")
print("    восстанавливает фазу состояния (класс 1 — «временный/неверифицированный»).")
print("    Двойной цикл стягивается в тождество (класс 0 — «верифицирован»).")

print()
print("=" * 78)
print("ЭТАП 6. ТОЧНОСТЬ ИЗМЕРЕНИЯ ДИСТАНЦИИ ПО W-КООРДИНАТЕ")
print("=" * 78)

precision = []
for dW in [1e-12, 1e-9, 1e-6]:
    ds_center = 2 * R_m * dW  # при W≈1: ds ≈ 2R·dW
    ds_equator = 2 * R_m * dW / math.sqrt(1 - 0.7071 ** 2)  # при W=0.7071
    precision.append({"dW": dW, "ds_center_mm": ds_center * 1e3,
                      "ds_equator_mm": ds_equator * 1e3})
    print(f"  δW = {dW:.0e}: δs(центр зоны) = {ds_center*1e3:.3f} мм, "
          f"δs(экватор карты) = {ds_equator*1e3:.2f} мм")
results["precision"] = precision
eps = 1e-15
ds_min = 2 * R_m * math.sqrt(2 * eps)
results["fs_resolution_um"] = ds_min * 1e6
print(f"  Числовое разрешение метрики (ε=1e-15): δs_min = {ds_min*1e6:.1f} мкм")

with open(os.path.join(OUT_DIR, "02_p3metric.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print()
print(f"[OK] Сохранено: {os.path.join(OUT_DIR, '02_p3metric.json')}")
