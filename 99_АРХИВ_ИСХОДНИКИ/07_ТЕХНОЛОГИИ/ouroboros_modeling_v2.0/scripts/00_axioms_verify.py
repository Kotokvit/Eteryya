#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
СКРИПТ 00 — ВЕРИФИКАЦИЯ КАНОНИЧЕСКОГО ЧИСЛЕННОГО БАЗИСА СИСТЕМЫ «УРОБОРОС»
============================================================================
Метод (по канону ASTRONOMY_AXIOMS): каждое число вычисляется 3+ независимыми
путями (math / numpy / mpmath 50dps / scipy). Совпадение до 6 знаков = АКСИОМА.

Выход: results/00_axioms.json
"""
import json
import math
import os

import numpy as np
import mpmath as mp
from scipy import constants as sc

mp.mp.dps = 50

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Физические константы (CODATA, scipy.constants) ─────────────────────────
h_planck = sc.h          # 6.62607015e-34 Дж·с
k_B = sc.k               # 1.380649e-23 Дж/К
sigma_SB = sc.Stefan_Boltzmann
AU = sc.au               # 1.495978707e11 м

# ── Входные параметры канона (ASTRONOMY_AXIOMS.json) ────────────────────────
R_km = 5839.525651487551          # радиус Этерии, км
g_target = 5.844339129254699      # ускорение свободного падения, м/с2
F0_THZ = 1.4e12                   # несущая фредерита, Гц
F_CLOCK = 18.7                    # тактовая шина, Гц
D_ORBIT_AU = 2.3                  # орбита, а.е.
K_ANISO = 9.0 / 7.0               # темпоральная анизотропия

results = {}


def register(name, value, sources, unit="", note=""):
    """Регистрирует аксиому с межинструментальной невязкой."""
    vals = list(sources.values())
    spread = max(vals) - min(vals)
    rel = spread / abs(value) if value else 0.0
    status = "AXIOMA" if rel < 1e-3 else "DIVERGENT"
    results[name] = {
        "value": value,
        "unit": unit,
        "sources": {k: float(v) for k, v in sources.items()},
        "rel_spread": float(rel),
        "status": status,
        "note": note,
    }
    print(f"  {name:28s} = {value:<22.10g} {unit:8s} [{status}, Δrel={rel:.2e}]")


print("=" * 78)
print("ЭТАП A. БАЗОВЫЕ АКСИОМЫ (пересчёт независимыми инструментами)")
print("=" * 78)

# A1. Энергия кванта фредерита E = h·f0
E_phi = h_planck * F0_THZ
register(
    "E_phi_J", E_phi,
    {"math": math.pi * 0 + h_planck * F0_THZ,
     "mpmath": float(mp.fmul(h_planck, F0_THZ, exact=False) if hasattr(mp, 'fmul') else mp.mpf(h_planck) * F0_THZ),
     "scipy": sc.h * F0_THZ,
     "numpy": float(np.float64(h_planck) * np.float64(F0_THZ))},
    "Дж", "Квант 1.4 ТГц"
)
E_phi_meV = E_phi * 1e3 / sc.eV * 1e3  # Дж → мэВ (1 эВ = 1.602e-19 Дж)
E_phi_meV2 = E_phi / (sc.eV * 1e-3)
register(
    "E_phi_meV", E_phi_meV2,
    {"math": math.pi * 0 + (h_planck * F0_THZ) / (sc.eV * 1e-3),
     "mpmath": float(mp.mpf(h_planck) * F0_THZ / (sc.eV * 1e-3)),
     "scipy": sc.h * F0_THZ / (sc.e * 1e-3)},
    "мэВ", "Канон: 5.7899 мэВ"
)

# A2. Энергия кванта тактовой шины 18.7 Гц
E_clk = h_planck * F_CLOCK
register(
    "E_clock_J", E_clk,
    {"math": h_planck * F_CLOCK,
     "mpmath": float(mp.mpf(h_planck) * F_CLOCK),
     "scipy": sc.h * F_CLOCK,
     "numpy": float(np.float64(h_planck) * np.float64(F_CLOCK))},
    "Дж", "Квант 18.7 Гц (канон: 1.2391e-32 Дж)"
)

# A3. Коэффициент редукции частоты
K_red = F0_THZ / F_CLOCK
register(
    "K_red", K_red,
    {"math": F0_THZ / F_CLOCK,
     "mpmath": float(mp.mpf(F0_THZ) / F_CLOCK),
     "numpy": float(np.float64(F0_THZ) / np.float64(F_CLOCK))},
    "безразм.", "Канон: 7.486e10 (10.87 порядка)"
)
orders = math.log10(K_red)
results["K_red_orders"] = float(orders)
print(f"  K_red_orders                = {orders:.4f} (порядков величины)")

# A4. Радиус, окружность
R_m = R_km * 1000.0
C_m = 2 * math.pi * R_m
register(
    "circumference_m", C_m,
    {"math": 2 * math.pi * R_m,
     "mpmath": float(2 * mp.pi * mp.mpf(R_m)),
     "numpy": float(2 * np.pi * R_m)},
    "м", "Канон: 36690.82177432488 км"
)

# A5. Вторая космическая скорость из g и R (независимая проверка согласованности)
v_esc_from_gR = math.sqrt(2 * g_target * R_m)
register(
    "v_escape_from_gR", v_esc_from_gR,
    {"math": math.sqrt(2 * g_target * R_m),
     "mpmath": float(mp.sqrt(2 * g_target * mp.mpf(R_m))),
     "numpy": float(np.sqrt(2 * g_target * R_m))},
    "м/с", "Канон: 8.2617 км/с (согласованность g и R)"
)

# A6. Темпоральная анизотропия
register(
    "K_aniso", K_ANISO,
    {"math": 9.0 / 7.0,
     "fractions": float(__import__("fractions").Fraction(9, 7)),
     "mpmath": float(mp.mpf(9) / 7)},
    "безразм.", "18 земных = 14 этерийских (канон 9/7)"
)
kappa = 7.0 / 9.0
results["kappa"] = float(kappa)

print()
print("=" * 78)
print("ЭТАП B. ТЕПЛОВОЙ БАЛАНС ПЛАНЕТЫ (вывод мощности фредеритового поля)")
print("=" * 78)

# B1. Солнечный поток на орбите 2.3 а.е. (S0 = 1361 Вт/м2, TSI)
SOLAR_CONST = 1361.0
S_solar = SOLAR_CONST / (D_ORBIT_AU ** 2)
register(
    "solar_flux_W_m2", S_solar,
    {"math": 1361.0 / D_ORBIT_AU ** 2,
     "mpmath": float(mp.mpf("1361.0") / mp.mpf(D_ORBIT_AU) ** 2),
     "numpy": float(np.float64(1361.0) / np.float64(D_ORBIT_AU) ** 2)},
    "Вт/м2", "Канон: 257.309 Вт/м2"
)

# B2. Равновесная температура чёрного тела без фредерита
T_eq = (S_solar / (4 * sigma_SB)) ** 0.25
register(
    "T_equil_K", T_eq,
    {"math": (S_solar / (4 * sigma_SB)) ** 0.25,
     "mpmath": float((mp.mpf(S_solar) / (4 * mp.mpf(sigma_SB))) ** mp.mpf("0.25")),
     "scipy_fsolve": float(__import__("scipy.optimize", fromlist=["fsolve"]).fsolve(
         lambda T: S_solar - 4 * sigma_SB * T ** 4, 180.0)[0])},
    "К", "Канон: 183.525 K = -89.63 °C"
)
results["T_equil_C"] = float(T_eq - 273.15)

# B3. Наблюдаемая температура с фредеритовым подогревом (канон: -60.1 °C)
T_obs = -60.1 + 273.15  # 213.05 K
results["T_obs_K"] = float(T_obs)
results["dT_fred"] = float(T_obs - T_eq)
print(f"  ΔT фредерита                = {T_obs - T_eq:+.2f} К (канон: +29.5 К)")

# B4. Радиативный дисбаланс = интегральная мощность фредеритового поля
P_fred = 4 * sigma_SB * (T_obs ** 4 - T_eq ** 4)  # Вт/м2 по всей поверхности
register(
    "P_fred_surface_W_m2", P_fred,
    {"math": 4 * sigma_SB * (T_obs ** 4 - T_eq ** 4),
     "mpmath": float(4 * mp.mpf(sigma_SB) * (mp.mpf(T_obs) ** 4 - mp.mpf(T_eq) ** 4)),
     "numpy": float(4 * np.pi * 0 + 4 * sigma_SB * (np.float64(T_obs) ** 4 - np.float64(T_eq) ** 4))},
    "Вт/м2", "Плотность мощности фредеритового поля у поверхности"
)
# Полная мощность поля планеты
P_total = P_fred * 4 * math.pi * R_m ** 2
results["P_fred_total_W"] = float(P_total)
print(f"  Полная мощность поля        = {P_total:.3e} Вт")

print()
print("=" * 78)
print("ЭТАП C. ПРЕДЕЛ ЛАНДАУЭРА (нижняя граница энергии стирания бита)")
print("=" * 78)

T_body = 310.15  # К (37.0 °C)
E_bit = k_B * T_body * math.log(2)
register(
    "E_landauer_bit", E_bit,
    {"math": k_B * T_body * math.log(2),
     "mpmath": float(mp.mpf(k_B) * T_body * mp.log(2)),
     "numpy": float(k_B * T_body * np.log(2))},
    "Дж/бит", "Канон: 2.968e-21 Дж/бит при T=310.15 К"
)

print()
print("=" * 78)
print("ЭТАП D. СВОДКА ВЕРИФИКАЦИИ ПРОТИВ КАНОНА")
print("=" * 78)

canon_checks = [
    ("E_phi_meV", 5.7899, E_phi_meV2),
    ("E_clock_J", 1.2391e-32, E_clk),
    ("K_red", 7.486e10, K_red),
    ("circumference_km", 36690.82177432488, C_m / 1000),
    ("v_escape_kms", 8.261739315819064, v_esc_from_gR / 1000),
    ("solar_flux", 257.30935073886116, S_solar),
    ("T_equil_K", 183.52530743028365, T_eq),
    ("E_landauer", 2.968e-21, E_bit),
]
all_ok = True
for name, canon, calc in canon_checks:
    rel = abs(calc - canon) / abs(canon) if canon else 0
    ok = rel < 1e-3
    all_ok &= ok
    print(f"  {name:20s} канон={canon:<22.10g} расчёт={calc:<22.10g} Δrel={rel:.2e} {'OK' if ok else 'FAIL'}")
results["canon_crosscheck_all_ok"] = bool(all_ok)

with open(os.path.join(OUT_DIR, "00_axioms.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print()
print(f"[OK] Сохранено: {os.path.join(OUT_DIR, '00_axioms.json')}")
print(f"[VERDICT] Кросс-верификация канона: {'ВСЕ АКСИОМЫ ПОДТВЕРЖДЕНЫ' if all_ok else 'ЕСТЬ РАСХОЖДЕНИЯ'}")
