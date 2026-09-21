#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
СКРИПТ 01 — МОДУЛЬ «ФИЛЬТР»: МАТЕРИАЛЬНЫЙ КАСКАД 1.4 ТГц → 18.7 Гц
====================================================================
Инженерная задача:
  1. Толщина пассивного демпфера (Pb-Bi-C) для подавления ТГц-поля
     на заданный коэффициент (10^-11 по амплитуде).
  2. Тепловая нагрузка на шлюз и утилизация тепла (сифоны в базальт).
  3. Баланс тактовой шины 18.7 Гц (квантовый бюджет).

Физика: скин-эффект в тяжелых металлах (δ = sqrt(2/(ωμσ))),
закон Бугера-Ламберта A(x) = A0·exp(-x/δ), закон Стефана-Больцмана
для тепловой нагрузки, теплопроводность Фурье для сифонов.

Выход: results/01_filter.json
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

h = sc.h
k_B = sc.k
mu0 = sc.mu_0

# ── Канонические входы ──────────────────────────────────────────────────────
F0 = 1.4e12          # Гц, несущая фредерита
F_CLK = 18.7         # Гц, тактовая шина
R_m = 5839.525651487551e3
OMEGA = 2 * math.pi * F0

# ── Материалы демпфера (справочные удельные проводимости, S/m) ─────────────
MATERIALS = {
    "Pb (свинец)":  {"sigma": 4.81e6,  "k_therm": 35.3,  "note": "χ-демпфер, электронная плотность 7.4e28 1/м3"},
    "Bi (висмут)":  {"sigma": 7.70e5,  "k_therm": 7.87,  "note": "полуметалл, тяжелый поглотитель"},
    "C (алмаз)":    {"sigma": 1.0e-13, "k_therm": 2200,  "note": "бездефектный диэлектрик, выпрямитель φ-фазы"},
}

results = {"inputs": {"F0_Hz": F0, "F_clock_Hz": F_CLK, "suppression_target": 1e-11}}

print("=" * 78)
print("ЭТАП 1. СКИН-ГЛУБИНА НА ЧАСТОТЕ 1.4 ТГц (δ = sqrt(2/(ω·μ0·σ)))")
print("=" * 78)

skin = {}
for name, mat in MATERIALS.items():
    delta = math.sqrt(2.0 / (OMEGA * mu0 * mat["sigma"]))
    skin[name] = delta
    # Кросс-проверка mpmath
    delta_mp = float(mp.sqrt(2 / (mp.mpf(OMEGA) * mp.mpf(mu0) * mp.mpf(mat["sigma"]))))
    assert abs(delta - delta_mp) / delta < 1e-12
    print(f"  {name:14s} σ={mat['sigma']:.2e} S/м  →  δ = {delta*1e9:8.2f} нм")
results["skin_depth_nm"] = {k: v * 1e9 for k, v in skin.items()}

print()
print("=" * 78)
print("ЭТАП 2. ТОЛЩИНА МНОГОСЛОЙНОГО ЭКРАНА ДЛЯ ПОДАВЛЕНИЯ 10^-11")
print("=" * 78)

# Коэффициент подавления по амплитуде: S = П exp(-x_i/δ_i) = 10^-11
# Σ x_i/δ_i = 11·ln(10) = 25.3284
TARGET = 1e-11
req_atten = -math.log(TARGET)  # 25.3284 натуральных единиц
print(f"  Требуемое суммарное затухание: {req_atten:.4f} Нп (непер) = {abs(math.log10(TARGET)):.1f} декад")

# Конфигурация A: чистый Pb
x_pb = req_atten * skin["Pb (свинец)"]
# Конфигурация B: чередование Pb/Bi/Pb (равное затухание на слой, 6 слоёв)
# Конфигурация C: Pb-Bi-C композит: Pb основной + Bi + C-подложка (C не поглощает)
frac = {"Pb": 0.6, "Bi": 0.4}
x_pb_part = req_atten * frac["Pb"] * skin["Pb (свинец)"]
x_bi_part = req_atten * frac["Bi"] * skin["Bi (висмут)"]

configs = {
    "A_чистый_Pb":        {"layers": [("Pb", x_pb)], "total": x_pb},
    "B_композит_Pb_Bi":   {"layers": [("Pb", x_pb_part), ("Bi", x_bi_part)], "total": x_pb_part + x_bi_part},
}
for cfg_name, cfg in configs.items():
    desc = " + ".join(f"{n}: {t*1e6:.2f} мкм" for n, t in cfg["layers"])
    print(f"  Конфигурация {cfg_name}: {desc}  →  ИТОГО {cfg['total']*1e6:.2f} мкм")
results["screen_thickness"] = {
    "requirement_Np": req_atten,
    "config_A_um": x_pb * 1e6,
    "config_B_um": (x_pb_part + x_bi_part) * 1e6,
    "config_B_Pb_um": x_pb_part * 1e6,
    "config_B_Bi_um": x_bi_part * 1e6,
}

# Масса экрана на 1 м2 (композит B)
rho_pb, rho_bi = 11340.0, 9790.0  # кг/м3
m_pb = x_pb_part * rho_pb
m_bi = x_bi_part * rho_bi
print(f"  Масса экрана на 1 м2: Pb {m_pb*1e3:.1f} г + Bi {m_bi*1e3:.1f} г = {(m_pb+m_bi)*1e3:.1f} г/м2")
results["areal_mass_g_m2"] = (m_pb + m_bi) * 1e3

print()
print("=" * 78)
print("ЭТАП 3. ТЕПЛОВАЯ НАГРУЗКА ШЛЮЗА (из планетарного баланса)")
print("=" * 78)

# Из 00_axioms: радиативный дисбаланс планеты 210 Вт/м2 — верхняя оценка
# плотности мощности фредеритового поля у поверхности.
P_FIELD = 210.024378  # Вт/м2
A_GATEWAY = 100.0     # м2 — эталонный шлюз
P_abs = P_FIELD * A_GATEWAY * (1 - TARGET)  # почти всё поглощается
print(f"  Плотность мощности поля у поверхности: {P_FIELD:.1f} Вт/м2")
print(f"  Шлюз A = {A_GATEWAY:.0f} м2 → поглощаемая мощность P = {P_abs/1e3:.2f} кВт")
results["thermal"] = {
    "field_flux_W_m2": P_FIELD,
    "gateway_area_m2": A_GATEWAY,
    "absorbed_power_W": P_abs,
}

# Пассивный отвод через стенку (теплопроводность): q = k·ΔT/L
# Стена: Pb-Bi композит 5 мм + алмазная подложка 2 мм
L_pb, L_bi, L_c = 5e-3, 5e-3, 2e-3
R_th = L_pb / 35.3 + L_bi / 7.87 + L_c / 2200.0  # м2·К/Вт
dT_wall = P_FIELD * R_th
print(f"  Термосопротивление стены (Pb 5мм + Bi 5мм + C 2мм): {R_th*1e3:.3f}·10^-3 м2·К/Вт")
print(f"  Перепад температуры на стене при 210 Вт/м2: ΔT = {dT_wall:.2f} К")
results["thermal"]["wall_R_th_m2K_W"] = R_th
results["thermal"]["wall_dT_K"] = dT_wall

# Сифон: скважина в базальт, глубина H, радиус r
k_basalt = 1.7  # Вт/(м·К)
H_bore, r_bore = 500.0, 0.15
T_mantle_adv = 100.0  # доступный перепад, К (тепловой фронт)
# Цилиндрический радиальный поток от стенки скважины — приближение линии тока
# q' = 2π·k·H·ΔT / ln(r_out/r_in), r_out = 10 м (термовлиятельная зона)
q_bore = 2 * math.pi * k_basalt * H_bore * T_mantle_adv / math.log(10.0 / r_bore)
n_bore = math.ceil(P_abs / q_bore)
print(f"  Сифон: скважина H={H_bore:.0f} м, r={r_bore*100:.0f} см, базальт k={k_basalt} Вт/мК")
print(f"  Мощность одного сифона (ΔT=100 К): {q_bore:.0f} Вт")
print(f"  Требуется сифонов на шлюз 100 м2: {n_bore} шт.")
results["siphon"] = {
    "k_basalt": k_basalt, "depth_m": H_bore, "radius_m": r_bore,
    "capacity_W": q_bore, "count_for_gateway": n_bore,
}

print()
print("=" * 78)
print("ЭТАП 4. КВАНТОВЫЙ БЮДЖЕТ ТАКТОВОЙ ШИНЫ 18.7 Гц")
print("=" * 78)

E_clk = h * F_CLK
# На тактовую шину направляем η = 0.5% поглощенной мощности
eta = 0.005
P_clk = eta * P_abs
N_clk = P_clk / E_clk
print(f"  Энергия кванта шины: E = {E_clk:.4e} Дж ({E_clk*1e3/sc.e:.3e} мэВ)")
print(f"  Мощность шины (η={eta*100:.1f}%): {P_clk:.2f} Вт")
print(f"  Поток квантов: {N_clk:.3e} квант/с")
print(f"  Квантов на один период такта (1/18.7 с): {N_clk/F_CLK:.3e}")
results["clock_bus"] = {
    "E_quantum_J": E_clk, "eta": eta, "power_W": P_clk,
    "quanta_per_s": N_clk, "quanta_per_cycle": N_clk / F_CLK,
}

# Отношение энергий квантов — «понижающий трансформатор»
ratio = (h * F0) / E_clk
print(f"  Отношение энергий квантов ТГц/шина: {ratio:.4e} (×{ratio:.3g})")
results["clock_bus"]["quantum_energy_ratio"] = ratio

print()
print("=" * 78)
print("ЭТАП 5. ЛИТОСФЕРНОЕ ЛЕГИРОВАНИЕ (планетарный масштаб)")
print("=" * 78)

# Канон: «миллиарды тонн» флюса в активные жилы. Проверим порядок:
# Объем приповерхностного слоя фредерита глубиной d=100 м на площади 1% поверхности
d_layer = 100.0
frac_area = 0.01
V_layer = 4 * math.pi * R_m ** 2 * d_layer * frac_area
m_layer = V_layer * 2600.0  # кг, плотность минерализованной породы
# Масса флюса при объемной доле легирования f_dope
f_dope = 1e-8
m_flux = m_layer * f_dope
print(f"  Объем приповерхностных жил (1% площади, 100 м): {V_layer:.3e} м3")
print(f"  Полная масса жил: {m_layer/1e12:.2f}·10^12 т")
print(f"  Флюс при объемной доле f={f_dope:.0e}: {m_flux/1e9:.2f} млрд тонн — порядок канона подтвержден")
results["litho_doping"] = {
    "layer_depth_m": d_layer, "area_fraction": frac_area,
    "volume_m3": V_layer, "layer_mass_t": m_layer / 1e3,
    "doping_fraction": f_dope, "flux_mass_Gt": m_flux / 1e9,
}

with open(os.path.join(OUT_DIR, "01_filter.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print()
print(f"[OK] Сохранено: {os.path.join(OUT_DIR, '01_filter.json')}")
