#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
СКРИПТ 04 — ИНТЕГРИРОВАННЫЙ СИМУЛЯТОР «УРОБОРОС» (КОНСОЛЬНЫЙ ДВИЖОК)
=====================================================================
Собирает три модуля в единый расчетный контур:

  [ВХОД: объект с координатами [X:Y:Z:W]] →
    Модуль МЕТРИКА  → d_FS, s, W(s), карта атласа
    Модуль ФИЛЬТР   → локальное подавление поля A(s) = A0·W(s)
    Модуль I/O-ШИНА → пропускная способность портов, тепловой бюджет
    БАЛАНС ЗСЭР     → ΔS_tot = ΔS_χ − κ·ΔI_Ω = const
    ЗАЩИТА Z/2Z     → верификация четности; сбой → Kernel Panic

Сценарии:
  A. Номинал: штатный вызов API уровня S_k на дистанции s от шлюза.
  B. Пиковый: вызов S22 на пределе бюджета.
  C. Инжекция несовместимого кода (без четности) → дефолт порта.

Выход: results/04_simulator.json
"""
import json
import math
import os
import sys

import numpy as np
from scipy import constants as sc

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "results")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Загрузка результатов модулей ────────────────────────────────────────────
with open(os.path.join(OUT_DIR, "00_axioms.json"), encoding="utf-8") as f:
    AX = json.load(f)
with open(os.path.join(OUT_DIR, "01_filter.json"), encoding="utf-8") as f:
    FLT = json.load(f)
with open(os.path.join(OUT_DIR, "03_biobus.json"), encoding="utf-8") as f:
    BIO = json.load(f)

R_m = 5839.525651487551e3
KAPPA = 7.0 / 9.0            # коэффициент анизотропии (ЗСЭР)
E_BIT = BIO["landauer"]["E_bit_J"]
Q_MAX = BIO["landauer"]["Q_max_J"]
P_COOL = BIO["landauer"]["P_cool_W"]
API = BIO["api_matrix"]
P_FIELD = FLT["thermal"]["field_flux_W_m2"]
A_GATE = FLT["thermal"]["gateway_area_m2"]
P_ABS = FLT["thermal"]["absorbed_power_W"]

results = {"scenarios": []}


# ════════════════════════════════════════════════════════════════════════════
# ЯДРО СИМУЛЯТОРА
# ════════════════════════════════════════════════════════════════════════════

def metric_module(P_hom):
    """Метрика: d_FS до шлюза, дистанция, W, аффинная карта."""
    P = np.asarray(P_hom, dtype=float)
    P = P / np.linalg.norm(P)
    gateway = np.array([0.0, 0.0, 0.0, 1.0])
    d_fs = math.acos(min(1.0, abs(float(np.dot(P, gateway)))))
    s = 2.0 * R_m * d_fs
    W = math.cos(s / (2.0 * R_m))
    comps = {"U_W": abs(P[3]), "U_X": abs(P[0]), "U_Y": abs(P[1]), "U_Z": abs(P[2])}
    card = max(comps, key=comps.get)
    return {"d_FS_rad": d_fs, "s_m": s, "W": W, "card": card}


def filter_module(s_m, suppression=1e-11):
    """Фильтр: остаточная амплитуда поля на дистанции s (затухание экрана × W(s))."""
    W = math.cos(s_m / (2.0 * R_m))
    # Внутри шлюза: экран 10^-11; вне: подавление ослабевает как W(s)
    residual = suppression ** W  # интерполяция защиты купола
    leak_field = P_FIELD * residual
    return {"W": W, "residual_suppression": residual, "leak_W_m2": leak_field}


def bio_module(level, sigma_port, duty=1.0):
    """I/O-шина: тепловой отклик порта на вызов уровня S_level."""
    spec = API[level]
    ok_sigma = sigma_port >= spec["sigma_req"]
    Q = spec["Q_J"]
    budget_used = Q / Q_MAX
    t_cool = Q / (P_COOL * duty)
    return {"sigma_req": spec["sigma_req"], "sigma_ok": bool(ok_sigma),
            "Q_J": Q, "budget_fraction": budget_used, "t_cool_s": t_cool}


def zser_balance(dI_omega, dS_chi):
    """ЗСЭР: ΔS_tot = ΔS_χ − κ·ΔI_Ω. Совместимость: dS_chi >= kappa*dI_omega."""
    lhs = dS_chi - KAPPA * dI_omega
    compatible = dS_chi >= KAPPA * dI_omega
    return {"dS_tot": lhs, "compatible": bool(compatible),
            "deficit": max(0.0, KAPPA * dI_omega - dS_chi)}


def z2z_check(parity_loops):
    """Верификация четности: класс 0 (2 цикла) — пропуск; класс 1 — карантин."""
    return parity_loops % 2 == 0


def run_scenario(name, P_hom, level, sigma_port, parity_loops, dS_chi_avail):
    print("=" * 78)
    print(f"СЦЕНАРИЙ {name}")
    print("=" * 78)
    m = metric_module(P_hom)
    f = filter_module(m["s_m"])
    b = bio_module(level, sigma_port)

    dI_omega = API[level]["dI_bits"]
    # Доступный сброс хаоса: тепловой путь порта в единицах информации
    dS_chi = dS_chi_avail / E_BIT
    zser = zser_balance(dI_omega, dS_chi)
    z2z = z2z_check(parity_loops)

    verdict_ok = m["W"] > 0 and b["sigma_ok"] and zser["compatible"] and z2z
    if not z2z:
        # Дефолт: инжекция несовместимого кода → Kernel Panic
        panic = BIO["kernel_panic"]
        print(f"  [МЕТРИКА ] d_FS = {m['d_FS_rad']:.6f} рад, s = {m['s_m']/1000:.1f} км, "
              f"W = {m['W']:.4f}, карта {m['card']}")
        print(f"  [ФИЛЬТР  ] остаточная протечка {f['leak_W_m2']:.2e} Вт/м2")
        print(f"  [ЗАЩИТА  ] класс четности = {parity_loops % 2} ∈ Z/2Z → ВЕРИФИКАЦИЯ ПРОВАЛЕНА")
        print(f"  [PANIC   ] Перегрузка регистров за 0.0014 с; сброс {panic['Q_MJ']:.1f} МДж "
              f"({panic['P_MW']:.1f} МВт); нагрев до 1300°C за 0.8 с")
        print(f"  [ВЕРДИКТ ] KERNEL PANIC — порт изолирован, подложка остеклена")
        out = {"name": name, "metric": m, "filter": f, "bio": b,
               "zser": zser, "z2z_ok": z2z, "verdict": "KERNEL_PANIC"}
    else:
        print(f"  [МЕТРИКА ] d_FS = {m['d_FS_rad']:.6f} рад, s = {m['s_m']/1000:.1f} км, "
              f"W = {m['W']:.4f}, карта {m['card']}")
        print(f"  [ФИЛЬТР  ] остаточное подавление {f['residual_suppression']:.2e}, "
              f"протечка {f['leak_W_m2']:.2e} Вт/м2")
        print(f"  [I/O-ШИНА] уровень S{level}: σ_req = {b['sigma_req']:.2f} "
              f"({'OK' if b['sigma_ok'] else 'НЕДОСТАТОЧНО'}), "
              f"Q = {b['Q_J']:.3e} Дж ({b['budget_fraction']*100:.2f}% бюджета), "
              f"t_cool = {b['t_cool_s']:.3g} с")
        print(f"  [ЗСЭР    ] ΔS_tot = {zser['dS_tot']:.3e} "
              f"({'СОВМЕСТИМО' if zser['compatible'] else 'ДЕФИЦИТ ЭНТРОПИИ'})")
        if not zser["compatible"]:
            # Разрешение дефицита: флот или медленный разряд
            ports_inst = math.ceil(zser["deficit"] / (P_COOL * 1.0 / E_BIT))
            t_slow = b["Q_J"] / P_COOL
            print(f"  [РЕШЕНИЕ ] Вариант 1: распределить на {ports_inst} портов (мгновенно)")
            print(f"             Вариант 2: медленный разряд одного порта за {t_slow/3600:.2f} ч")
        print(f"  [ЗАЩИТА  ] класс четности = {parity_loops % 2} ∈ Z/2Z → верифицирован")
        print(f"  [ВЕРДИКТ ] {'ШТАТНЫЙ РЕЖИМ' if verdict_ok else 'ОТКЛОНЕНИЕ'}")
        out = {"name": name, "metric": m, "filter": f, "bio": b,
               "zser": zser, "z2z_ok": z2z,
               "verdict": "NOMINAL" if verdict_ok else "DEVIATION"}
    print()
    results["scenarios"].append(out)
    return out


# ════════════════════════════════════════════════════════════════════════════
# СЦЕНАРИИ
# ════════════════════════════════════════════════════════════════════════════

# A. Номинал: порт в 300 км от шлюза, вызов S12, σ_e = 9.4, четность OK
theta_a = (300e3) / (2 * R_m)
run_scenario("A-НОМИНАЛ: вызов S12 на 300 км",
             [math.sin(theta_a) * 0.6, math.sin(theta_a) * 0.8, 0.0, math.cos(theta_a)],
             level=12, sigma_port=9.4, parity_loops=2,
             dS_chi_avail=P_COOL * 1.0)

# B. Пик: вызов S22 в центре шлюза, σ_e = 10.0, четность OK
run_scenario("B-ПИК: вызов S22 у шлюза",
             [0.0, 0.0, 0.0, 1.0],
             level=22, sigma_port=10.0, parity_loops=2,
             dS_chi_avail=P_COOL * 1.0)

# C. Инжекция внешнего кода без четности (класс 1) → Kernel Panic
theta_c = (50e3) / (2 * R_m)
run_scenario("C-ИНЖЕКЦИЯ: несовместимый код (1 цикл)",
             [math.sin(theta_c), 0.0, 0.0, math.cos(theta_c)],
             level=14, sigma_port=9.5, parity_loops=1,
             dS_chi_avail=P_COOL * 1.0)

# ════════════════════════════════════════════════════════════════════════════
# СВОДНЫЙ БАЛАНС СИСТЕМЫ
# ════════════════════════════════════════════════════════════════════════════

print("=" * 78)
print("СВОДНЫЙ ЭНЕРГО-ЭНТРОПИЙНЫЙ БАЛАНС ШЛЮЗА (100 м2)")
print("=" * 78)
n_ports = BIO["fleet"]["n_ports_design"]
balance = {
    "absorbed_THz_W": P_ABS,
    "siphon_capacity_W": FLT["siphon"]["capacity_W"],
    "OS_dissipation_W": BIO["fleet"]["P_OS_W"],
    "fleet_ground_W": BIO["fleet"]["fleet_capacity_W"],
    "ports": n_ports,
    "clock_power_W": FLT["clock_bus"]["power_W"],
}
print(f"  Поглощение ТГц-поля:        {P_ABS/1e3:8.2f} кВт  → сифоны в базальт (×{FLT['siphon']['count_for_gateway']} шт, "
      f"{FLT['siphon']['capacity_W']/1e3:.0f} кВт каждый)")
print(f"  Диссипация ОС (5%):         {BIO['fleet']['P_OS_W']/1e3:8.2f} кВт  → флот {n_ports} портов "
      f"(емкость {BIO['fleet']['fleet_capacity_W']/1e3:.1f} кВт)")
print(f"  Тактовая шина 18.7 Гц:      {FLT['clock_bus']['power_W']:8.2f} Вт  "
      f"({FLT['clock_bus']['quanta_per_cycle']:.2e} квант/такт)")
print(f"  κ (ЗСЭР) = 7/9 = {KAPPA:.6f}")
results["system_balance"] = balance

with open(os.path.join(OUT_DIR, "04_simulator.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print()
print(f"[OK] Сохранено: {os.path.join(OUT_DIR, '04_simulator.json')}")
