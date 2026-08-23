#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
СКРИПТ 03 — МОДУЛЬ «I/O-ШИНА»: ТЕПЛОВАЯ МАТРИЦА ПОРТОВ И УРОВНИ API S0-S22
==========================================================================
Аппаратный взгляд: биологические терминалы = I/O-порты с паспортными
тепловыми лимитами (как у любого процессора: TDP, τ_th, ESD-пределы).

Расчет:
  1. Предел Ландауэра при T тела: E_bit = k_B·T·ln2.
  2. Тепловой бюджет порта: Q_max = c·m·ΔT_crit (до порога денатурации).
  3. Устойчивая мощность охлаждения: P = h·A·ΔT (конвекция/BSA).
  4. Матрица уровней API S0-S22: объем стираний ΔI, тепло Q, время
     охлаждения, допустимая частота вызовов, требуемая проводимость σ_e.
  5. Резофаза: 400-450 ч сканирования на 18.7 Гц — обратимые операции.
  6. Дефолт (Kernel Panic): энергия всплеска 1300°C за 0.8 с.

Выход: results/03_biobus.json
"""
import json
import math
import os

from scipy import constants as sc

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Паспорт I/O-порта (канон: Homo Aetheriensis видовая норма) ─────────────
M_PORT = 36.5          # кг — масса порта
C_TISSUE = 3470.0      # Дж/(кг·К) — теплоемкость тканей
T_BODY = 310.15        # К (37.0 °C)
T_CRIT = 314.95        # К (41.8 °C — порог свертывания белка)
DT_CRIT = T_CRIT - T_BODY   # 4.8 К... канон задает 4.6 К от 37.2; берем 4.6 от 37.2 ниже
DT_CRIT = 4.6
BSA = 1.192            # м2 — площадь поверхности
H_CONV = 5.0           # Вт/(м2·К) — естественная конвекция
F_CLOCK = 18.7         # Гц
E_BIT = sc.k * T_BODY * math.log(2)

results = {"port_spec": {
    "mass_kg": M_PORT, "c_tissue": C_TISSUE, "T_body_K": T_BODY,
    "dT_crit_K": DT_CRIT, "BSA_m2": BSA, "h_conv": H_CONV,
}}

print("=" * 78)
print("ЭТАП 1. ТЕПЛОВОЙ БЮДЖЕТ I/O-ПОРТА")
print("=" * 78)
print(f"  Предел Ландауэра E_bit = k_B·T·ln2 = {E_BIT:.6e} Дж/бит (T = 310.15 К)")

Q_max = C_TISSUE * M_PORT * DT_CRIT
P_cool = H_CONV * BSA * DT_CRIT
R_sust = P_cool / E_BIT
print(f"  Тепловой бюджет порта: Q_max = c·m·ΔT = {C_TISSUE}·{M_PORT}·{DT_CRIT} = {Q_max/1e3:.1f} кДж")
print(f"  Устойчивое охлаждение: P = h·A·ΔT = {H_CONV}·{BSA}·{DT_CRIT} = {P_cool:.1f} Вт")
print(f"  Устойчивая скорость стираний: R = P/E_bit = {R_sust:.3e} бит/с")
results["landauer"] = {"E_bit_J": E_BIT, "Q_max_J": Q_max, "P_cool_W": P_cool,
                       "R_sustained_bit_s": R_sust}

print()
print("=" * 78)
print("ЭТАП 2. МАТРИЦА УРОВНЕЙ API S0-S22 (23 уровня: S0 фоновый + 22 канонич.)")
print("=" * 78)

# Калибровка: ΔI(S22) = 0.90·Q_max/E_bit (пиковый вызов = 90% бюджета порта)
N_LEVELS = 22
I_S0 = 1e12
I_S22 = 0.90 * Q_max / E_BIT
RATIO = (I_S22 / I_S0) ** (1.0 / N_LEVELS)
print(f"  Калибровка: ΔI(S0) = {I_S0:.0e} бит; ΔI(S22) = {I_S22:.3e} бит; "
      f"шаг уровня ×{RATIO:.3f}")
print()
print(f"  {'Ур.':4s} {'ΔI, бит':>12s} {'Q, Дж':>12s} {'t_cool':>10s} {'макс. частота':>14s} {'σ_e треб.':>9s}")
print("  " + "-" * 74)

api_matrix = []
for k in range(N_LEVELS + 1):
    dI = I_S0 * (RATIO ** k)
    Q = dI * E_BIT
    t_cool = Q / P_cool
    rate = P_cool / Q  # вызовов/с при 100% скважности
    # Требуемая проводимость: S0 фоновый класс 1.5; S7 (Именование) = 9.0; S22 = 10.0
    if k == 0:
        sigma = 1.5
    elif k <= 7:
        sigma = 1.5 + (9.0 - 1.5) * k / 7.0
    else:
        sigma = 9.0 + (10.0 - 9.0) * (k - 7) / (N_LEVELS - 7)
    api_matrix.append({
        "level": k, "dI_bits": dI, "Q_J": Q, "t_cool_s": t_cool,
        "max_rate_s": rate, "sigma_req": round(sigma, 3),
    })
    if k % 2 == 0 or k in (7, 22, 1):
        t_str = (f"{t_cool:.3g} с") if t_cool < 90 else (f"{t_cool/3600:.2f} ч")
        rate_str = (f"{rate:.3g}/с") if rate >= 0.01 else (f"{rate*86400:.2f}/сут")
        print(f"  S{k:<3d} {dI:>12.3e} {Q:>12.3e} {t_str:>10s} {rate_str:>14s} {sigma:>9.2f}")
results["api_matrix"] = api_matrix
results["api_calibration"] = {"I_S0": I_S0, "I_S22": I_S22, "ratio": RATIO}

# Контрольные уровни
s7 = api_matrix[7]
print()
print(f"  Контроль S7 (системный вызов Именования, σ_e ≥ 9.0):")
print(f"    ΔI = {s7['dI_bits']:.3e} бит; Q = {s7['Q_J']*1e3:.2f} мДж; "
      f"t_cool = {s7['t_cool_s']*1e6:.1f} мкс; частота до {s7['max_rate_s']:.0f} выз/с")
s22 = api_matrix[22]
print(f"  Контроль S22 (верхний уровень, σ_e → 10.0):")
print(f"    ΔI = {s22['dI_bits']:.3e} бит; Q = {s22['Q_J']/1e3:.1f} кДж; "
      f"t_cool = {s22['t_cool_s']/3600:.2f} ч; не более {s22['max_rate_s']*86400:.1f} выз/сут")
n_break = Q_max / s22["Q_J"]
print(f"    Вызовов до теплового пробоя: {n_break:.2f} (одноразовый пик-режим)")

print()
print("=" * 78)
print("ЭТАП 3. РЕЗОФАЗА: СКАНИРОВАНИЕ НА ТАКТОВОЙ ЧАСТИ 18.7 Гц (400-450 ч)")
print("=" * 78)

t_reso_min, t_reso_max = 400.0, 450.0
cycles_min = t_reso_min * 3600 * F_CLOCK
cycles_max = t_reso_max * 3600 * F_CLOCK
print(f"  Тактов на Резофазу: {cycles_min:.3e} … {cycles_max:.3e} циклов")
# Обратимое сканирование (verification) — тепло только при стирании дефекта:
# геном ≈ 6.4e9 бит (2×3.2e9 п.н.); апоптоз дефектной клетки = стирание генома
I_GENOME = 6.4e9
Q_apop = I_GENOME * E_BIT
print(f"  Стоимость одного акта апоптоза (стирание генома {I_GENOME:.1e} бит):")
print(f"    Q = ΔI·E_bit = {Q_apop:.3e} Дж — на {math.log10(Q_max/Q_apop):.1f} порядков ниже бюджета порта")
print("  → Вывод: схема термодинамически безубыточна: сканирование обратимо")
print("    (адиабатическая проверка четности), платит только стертый дефект.")
results["resophase"] = {
    "t_hours": [t_reso_min, t_reso_max],
    "cycles": [cycles_min, cycles_max],
    "I_genome_bits": I_GENOME, "Q_apoptosis_J": Q_apop,
}

print()
print("=" * 78)
print("ЭТАП 4. ФЛОТ ПОРТОВ КАК РАСПРЕДЕЛЕННОЕ ЗАЗЕМЛЕНИЕ ЭНТРОПИИ")
print("=" * 78)

# Расчетная тепловая нагрузка ОС шлюза (5% от поглощенных 21 кВт)
P_OS = 0.05 * 21002.4
R_OS = P_OS / E_BIT
n_ports_needed = P_OS / P_cool
print(f"  Диссипация вычислительного контура ОС: P_OS = {P_OS/1e3:.2f} кВт (5% от 21.0 кВт)")
print(f"  Скорость стираний ОС: {R_OS:.3e} бит/с")
print(f"  Требуемое число портов при 100% скважности: {n_ports_needed:.0f}")
n_design = math.ceil(n_ports_needed / 0.5)  # проектный запас: скважность 50%
print(f"  Проектный флот (скважность 50%, запас ×2): {n_design} портов")
fleet_cap = n_design * P_cool
print(f"  Мощность заземления флота: {fleet_cap/1e3:.1f} кВт (нагрузка {P_OS/fleet_cap*100:.0f} %)")
results["fleet"] = {
    "P_OS_W": P_OS, "R_OS_bit_s": R_OS,
    "n_ports_min": n_ports_needed, "n_ports_design": n_design,
    "fleet_capacity_W": fleet_cap,
}

print()
print("=" * 78)
print("ЭТАП 5. ДЕФОЛТ ПОРТА (KERNEL PANIC): ВСПЛЕСК 1300°C ЗА 0.8 С")
print("=" * 78)

# Энергия нагрева подложки (био+минеральная смесь, эффективная масса 5 кг)
m_sub, c_sub = 5.0, 3000.0
dT_panic = 1300.0 - 37.0
Q_panic = m_sub * c_sub * dT_panic
P_panic = Q_panic / 0.8
I_corrupt = Q_panic / E_BIT
overload = Q_panic / Q_max
print(f"  Нагрев подложки 5 кг на {dT_panic:.0f} К: Q = {Q_panic/1e6:.2f} МДж за 0.8 с → {P_panic/1e6:.1f} МВт")
print(f"  Эквивалентный объем стертой информации: {I_corrupt:.3e} бит")
print(f"  Перегруз относительно бюджета порта: ×{overload:.0f} → тепловой пробой")

# Кросс-проверка: дегидратация 40% воды тела
m_water = 0.60 * M_PORT
m_lost = 0.40 * m_water
L_vap = 2.41e6  # Дж/кг — теплота парообразования при ~37 °C
Q_dehyd = m_lost * L_vap
print(f"  Кросс-проверка (дегидратация 40% воды тела):")
print(f"    m_потери = {m_lost:.2f} кг × L = {L_vap/1e6:.2f} МДж/кг → Q = {Q_dehyd/1e6:.2f} МДж")
match = abs(Q_panic - Q_dehyd) / ((Q_panic + Q_dehyd) / 2)
print(f"    Совпадение с энергией всплеска: {100*(1-match):.0f} % (независимая верификация)")
results["kernel_panic"] = {
    "Q_MJ": Q_panic / 1e6, "P_MW": P_panic / 1e6,
    "I_corrupt_bits": I_corrupt, "overload_x": overload,
    "Q_dehydration_MJ": Q_dehyd / 1e6, "crosscheck_match_pct": 100 * (1 - match),
}

with open(os.path.join(OUT_DIR, "03_biobus.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print()
print(f"[OK] Сохранено: {os.path.join(OUT_DIR, '03_biobus.json')}")
