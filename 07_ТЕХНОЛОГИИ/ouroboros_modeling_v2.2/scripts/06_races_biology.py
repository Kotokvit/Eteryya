#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
СКРИПТ 06 — БИОЛОГИЧЕСКОЕ ЖЕЛЕЗО ЭТЕРИИ: РАСЧЕТНЫЕ ПАСПОРТА ВСЕХ КЛАССОВ
==========================================================================
Раса = аппаратный узел с паспортными характеристиками. Никакого «преодоления
через силу воли»: лимиты задаются физикой.

Верифицируемые канонические законы:
  * ρ_φ = bio_factor × (σ_e/σ_raw) × ρ_φ_max, ρ_φ_max = 12.2 г/см³, σ_raw = 10
  * BSA (Дю Буа) = 0.007184 · H^0.725 · M^0.425
  * BMR (Клейбер) = 70 · M^0.75 ккал/сутки
  * Гипотермия при T_амб = −60.1 °C (модель охлаждения h = 5 Вт/м²К)

Новые инженерные модели:
  * Тепловой бюджет расы Q_max = c·m·ΔT_crit (демоны: T_crit = кипение крови)
  * CNED-утечка ниже порога σ 5.0: P_CUED = k_cned·(5 − σ)
  * Деградация при удержании Сфер выше класса: P_dump, t_boil
  * Регрессия продолжительности жизни и регенерации от φ-доли

Инструменты: numpy, scipy, CoolProp (свойства воды), pint (единицы).
Выход: results/06_races.json + charts/ (PNG для отчета).
"""
import json
import math
import os

import numpy as np
from CoolProp.CoolProp import PropsSI

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "results")
CHART_DIR = os.path.join(HERE, "charts")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(CHART_DIR, exist_ok=True)

# ── Физические константы и верифицированный базис ───────────────────────────
SIGMA_RAW = 10.0
RHO_PHI_MAX = 12.2           # г/см³, потолок (сырой фредерит)
T_AMB_C = -60.1              # °C, внешняя среда
H_CONV = 5.0                 # Вт/(м²·К)
E_BIT = 2.968114e-21         # Дж/бит (310.15 K)
BETA = 5.85 / 7.8            # Вт на единицу σ (несущая шины, Том 2)
EPS0_BUS = math.sqrt(BETA)   # 0.866 φВ
C_TISSUE = 3470.0            # Дж/(кг·К)
T_DENAT_C = 41.8             # °C, порог денатурации белка

# Свойства воды при температуре тела (CoolProp, верификация тепл модели)
L_VAP_310 = PropsSI("HMASS", "T", 310.15, "Q", 1, "Water") - PropsSI("HMASS", "T", 310.15, "Q", 0, "Water")
C_WATER_310 = PropsSI("C", "T", 310.15, "P", 101325, "Water") / 1000.0  # Дж/(кг·К)
print(f"[CoolProp] Вода @310 K: L_пар = {L_VAP_310/1e3:.1f} кДж/кг, c_р = {C_WATER_310:.0f} Дж/(кг·К)")

# σ-лестница Сфер (Том 2, верифицирована)
def sigma_req(k):
    if k <= 0:
        return 1.5
    if k <= 7:
        return 1.5 + (9.0 - 1.5) * k / 7.0
    return 9.0 + (10.0 - 9.0) * (k - 7) / 15.0

def max_level(sigma):
    k = 0
    for lvl in range(23):
        if sigma_req(lvl) <= sigma + 1e-9:
            k = lvl
    return k

# ── Канонический реестр биологического железа ───────────────────────────────
# Поля: name, cat(егория), H_cm, M_kg, BSA_canon, rho, rho_bone, T_C, sigma,
#       bio_factor, life_yr, rho_phi_canon, phi_pct_canon, BMR_W, phi_sub_W,
#       regen, aging, hypo_min (голый), T_crit_C (default 41.8)
RACES = [
    dict(name="H.e. видовая норма", cat="base", H=140, M=36.5, BSA=1.192,
         rho=1.040, rho_bone=1.45, T=36.8, sigma=6.5, bf=0.035, life=220,
         rho_phi=0.278, phi=21.1, BMR=50.3, phi_sub=4.88, regen=7.8, aging=0.128, hypo=19),
    dict(name="H.e. шахтер (профессия)", cat="prof", H=138, M=38.0, BSA=1.200,
         rho=1.060, rho_bone=1.50, T=37.2, sigma=7.8, bf=0.045, life=180,
         rho_phi=0.428, phi=28.8, BMR=51.9, phi_sub=5.85, regen=11.5, aging=0.087, hypo=None),
    dict(name="H.e. акме (фаза онтогенеза)", cat="phase", H=140, M=35.0, BSA=1.171,
         rho=1.030, rho_bone=1.42, T=36.6, sigma=7.8, bf=0.040, life=250,
         rho_phi=0.381, phi=27.0, BMR=48.8, phi_sub=5.85, regen=10.4, aging=0.097, hypo=None),
    dict(name="Эльф (Sylva aetheriensis)", cat="base", H=135, M=28.0, BSA=0.979,
         rho=1.000, rho_bone=1.30, T=36.2, sigma=7.0, bf=0.050, life=300,
         rho_phi=0.427, phi=29.9, BMR=41.3, phi_sub=5.25, regen=11.5, aging=0.087, hypo=17),
    dict(name="Орк (Orcus industrialis)", cat="base", H=190, M=105.0, BSA=2.225,
         rho=1.150, rho_bone=1.90, T=37.8, sigma=5.5, bf=0.028, life=140,
         rho_phi=0.188, phi=14.0, BMR=111.2, phi_sub=4.12, regen=5.6, aging=0.178, hypo=28),
    dict(name="Дриада (Dryadis collective)", cat="base", H=165, M=48.0, BSA=1.469,
         rho=0.920, rho_bone=1.15, T=34.5, sigma=6.0, bf=0.065, life=500,
         rho_phi=0.476, phi=34.1, BMR=61.8, phi_sub=4.50, regen=12.7, aging=0.079, hypo=21),
    dict(name="Гоблин (Goblinus subterraneus)", cat="base", H=105, M=20.0, BSA=0.732,
         rho=1.050, rho_bone=1.35, T=36.0, sigma=4.0, bf=0.018, life=70,
         rho_phi=0.088, phi=7.7, BMR=32.1, phi_sub=3.00, regen=3.2, aging=0.316, hypo=17,
         cned=2.6),
    dict(name="Драконит (Draconis progenies)", cat="base", H=165, M=62.0, BSA=1.682,
         rho=1.080, rho_bone=1.65, T=38.5, sigma=7.0, bf=0.050, life=350,
         rho_phi=0.427, phi=28.3, BMR=74.9, phi_sub=5.25, regen=11.5, aging=0.087, hypo=None),
    dict(name="Демон нижний (Daemon relictus minor)", cat="base", H=180, M=85.0, BSA=2.049,
         rho=1.200, rho_bone=2.10, T=40.0, sigma=5.0, bf=0.025, life=1000,
         rho_phi=0.153, phi=11.3, BMR=94.9, phi_sub=3.75, regen=4.8, aging=0.211, hypo=None,
         T_crit=120.0),   # χ-физиология: кровь кипит при 120 °C
    dict(name="Демон-Повелитель (Daemon dominus)", cat="base", H=195, M=110.0, BSA=2.422,
         rho=1.350, rho_bone=2.40, T=42.0, sigma=8.5, bf=0.060, life=50000,
         rho_phi=0.622, phi=31.5, BMR=115.1, phi_sub=None, regen=None, aging=None, hypo=None,
         T_crit=120.0),
    dict(name="Землянин (биологический фон)", cat="off", H=178, M=74.0, BSA=1.916,
         rho=1.070, rho_bone=1.90, T=36.6, sigma=1.5, bf=0.005, life=80,
         rho_phi=0.006, phi=0.8, BMR=85.5, phi_sub=0.0, regen=1.0, aging=1.0, hypo=None),
    dict(name="Оголённый (постмортемный каркас, Ω=0)", cat="post", H=160, M=22.0, BSA=None,
         rho=0.850, rho_bone=2.50, T=None, sigma=0.0, bf=0.0, life=0.02,   # 14.5 дней
         rho_phi=0.0, phi=0.0, BMR=0.0, phi_sub=0.0, regen=1.0, aging=1.0, hypo=None,
         leak=8.8, chi_reserve=1.1e7),
]

OVERLAYS = {
    "Мнемар": dict(d_sigma=3.0, d_bf=0.040, life_x=10, dT=-2.5),
    "Лич":    dict(d_sigma=2.0, d_bf=-0.020, life_x=50, dT=-30.0),
}

print("=" * 78)
print("ЭТАП 1. ВЕРИФИКАЦИЯ КАЗНОННЫХ ЗАКОНОВ (BSA, BMR, ρ_φ, гипотермия)")
print("=" * 78)

registry = []
print(f"  {'Класс':34s} {'BSA Δ%':>8s} {'BMR Δ%':>8s} {'ρ_φ Δ%':>8s} {'гипо Δ%':>8s}")
print("  " + "-" * 76)
for r in RACES:
    row = dict(r)
    # BSA Дю Буа
    if r["BSA"] and r["M"]:
        bsa_calc = 0.007184 * r["H"] ** 0.725 * r["M"] ** 0.425
        row["bsa_calc"] = bsa_calc
        row["bsa_err"] = abs(bsa_calc - r["BSA"]) / r["BSA"] * 100
    else:
        row["bsa_calc"] = r["BSA"]
        row["bsa_err"] = None
    # BMR Клейбер (ккал/сут → Вт)
    if r["BMR"]:
        bmr_kcal = 70.0 * r["M"] ** 0.75
        bmr_calc = bmr_kcal * 4184.0 / 86400.0
        row["bmr_calc"] = bmr_calc
        row["bmr_err"] = abs(bmr_calc - r["BMR"]) / r["BMR"] * 100
    else:
        row["bmr_calc"], row["bmr_err"] = r["BMR"], None
    # ρ_φ формула канона
    rho_phi_calc = r["bf"] * (r["sigma"] / SIGMA_RAW) * RHO_PHI_MAX
    row["rho_phi_calc"] = rho_phi_calc
    row["rho_phi_err"] = abs(rho_phi_calc - r["rho_phi"]) / r["rho_phi"] * 100 if r["rho_phi"] else None
    # φ-доля: ρ_φ / ρ_эфф, ρ_эфф = ρ_тела + ρ_φ
    if r["rho_phi"]:
        phi_calc = r["rho_phi"] / (r["rho"] + r["rho_phi"]) * 100
        row["phi_calc"] = phi_calc
        row["phi_err"] = abs(phi_calc - r["phi"]) / r["phi"] * 100
    # Гипотермия: t = c·m·ΔT_hypo / (h·BSA·(T_body − T_amb)), ΔT_hypo ≈ 5 K
    if r["hypo"] and r["BSA"] and r["T"] is not None:
        dT_hypo = 5.0
        p_loss = H_CONV * r["BSA"] * (r["T"] - T_AMB_C)
        t_hyp = C_TISSUE * r["M"] * dT_hypo / p_loss / 60.0
        row["hypo_calc"] = t_hyp
        row["hypo_err"] = abs(t_hyp - r["hypo"]) / r["hypo"] * 100
    # Тепловой бюджет и охлаждение
    if r["T"] is not None:
        T_crit = r.get("T_crit", T_DENAT_C)
        dT_crit = T_crit - r["T"]
        row["dT_crit"] = dT_crit
        row["Q_max"] = C_TISSUE * r["M"] * dT_crit
        row["P_cool"] = H_CONV * (row["bsa_calc"] or 1.0) * dT_crit
    # CNED-утечка (порог σ 5.0; калибровка по гоблину: 2.6 Вт при σ 4.0)
    k_cned = 2.6 / (5.0 - 4.0)
    if r["sigma"] < 5.0 and r["cat"] == "base":
        row["cned_calc"] = k_cned * (5.0 - r["sigma"])
    elif r["cat"] == "off":
        row["cned_calc"] = k_cned * (5.0 - r["sigma"])   # землянин: фон
    else:
        row["cned_calc"] = 0.0
    # Лестница уровней
    row["max_level"] = max_level(r["sigma"])
    # Деградация при удержании S7 и S22
    for k in (7, 22):
        I_k = BETA * sigma_req(k) / EPS0_BUS
        I_op = EPS0_BUS * r["sigma"]
        dI = max(0.0, I_k - I_op)
        P_dump = dI ** 2 / r["sigma"] if r["sigma"] > 0 else float("inf")
        row[f"P_dump_S{k}"] = P_dump
        row[f"t_boil_S{k}"] = row["Q_max"] / P_dump if P_dump > 0 and "Q_max" in row else None
    registry.append(row)
    def _e(v):
        return f"{v:7.1f}%" if v is not None else "   —   "
    print(f"  {r['name'][:34]:34s} {_e(row.get('bsa_err'))} {_e(row.get('bmr_err'))} "
          f"{_e(row.get('rho_phi_err'))} {_e(row.get('hypo_err'))}")

print()
print("  → Формула ρ_φ канона воспроизводится с невязкой < 0.1% (аппарат φ-насыщения верен).")
print("  → BMR канона = Клейбер (70·M^0.75) с точностью до 0.1%: метаболизм масштабируется")
print("    по массе универсально, φ-подпитка — надстройка сверху, не заменитель.")
print("  → BSA Дю Буа: точна для этерианцев (Δ<0.1%), расхождение 2-6% у нестандартных")
print("    пропорций (эльф, орк) — архитектура тел негабаритна для земной формулы.")

print()
print("=" * 78)
print("ЭТАП 2. РЕГРЕССИИ: ЖИЗНЬ И РЕГЕНЕРАЦИЯ ОТ φ-ДОЛИ")
print("=" * 78)

# Жизнь от φ-доли: УГЛЕРОДНАЯ БИОЛОГИЯ ТОЛЬКО. Демон-реликт — χ-выброс:
# его 1000 лет держатся не φ-конденсатом, а χ-фазой (иной механизм — исключен).
fit_races = [r for r in RACES if r["cat"] == "base" and r["life"] <= 500]
phi_arr = np.array([r["phi"] for r in fit_races])
life_arr = np.array([r["life"] for r in fit_races])
A = np.vstack([phi_arr, np.ones_like(phi_arr)]).T
k_life, b_life = np.linalg.lstsq(A, life_arr, rcond=None)[0]
pred_life = k_life * phi_arr + b_life
r2_life = 1 - np.sum((life_arr - pred_life) ** 2) / np.sum((life_arr - life_arr.mean()) ** 2)
print(f"  Углеродные расы: Жизнь (лет) ≈ {k_life:.2f}·φ% + {b_life:.1f};  R² = {r2_life:.4f}")
for r, p in zip(fit_races, pred_life):
    print(f"    {r['name'][:34]:34s} канон {r['life']:5.0f} → модель {p:6.0f} (Δ {p-r['life']:+.0f})")
demon = next(r for r in RACES if "нижний" in r["name"])
pred_d = k_life * demon["phi"] + b_life
print(f"    Демон нижний (χ-реликт):        канон {demon['life']:5.0f} → модель {pred_d:6.0f}: χ-фаза")
print(f"    дает +{demon['life']-pred_d:.0f} лет сверх углеродного тренда (якорь энтропии, не φ)")

# Регенерация от φ-доли
reg_races = [r for r in RACES if r.get("regen") and r["cat"] == "base"]
phi_r = np.array([r["phi"] for r in reg_races])
regen_arr = np.array([r["regen"] for r in reg_races])
A2 = np.vstack([phi_r, np.ones_like(phi_r)]).T
k_reg, b_reg = np.linalg.lstsq(A2, regen_arr, rcond=None)[0]
pred_reg = k_reg * phi_r + b_reg
r2_reg = 1 - np.sum((regen_arr - pred_reg) ** 2) / np.sum((regen_arr - regen_arr.mean()) ** 2)
print(f"  Регенерация (×земной) ≈ {k_reg:.3f}·φ% + {b_reg:.2f};  R² = {r2_reg:.4f}")
print("  → Обе шкалы углеродной биологии линейны по φ-доли: продолжительность жизни")
print("    и скорость регенерации — прямые следствия плотности φ-конденсата.")
print("    Демоны выбывают из тренда: их долголетие — χ-фазовый якорь.")

print()
print("=" * 78)
print("ЭТАП 3. ТЕПЛОВЫЕ ПАСПОРА И ЛЕСТНИЦА СФЕР")
print("=" * 78)

print(f"  {'Класс':34s} {'σ_e':>5s} {'макс.Сф':>8s} {'Q_max,кДж':>10s} {'P_охл,Вт':>9s} "
      f"{'CNED,Вт':>8s} {'S7:t_кип':>9s} {'S22:t_кип':>9s}")
print("  " + "-" * 90)
for row in registry:
    if row["cat"] == "post":
        # Постмортемный каркас: запас χ и часы смерти
        t_death = row["chi_reserve"] / row["leak"] / 86400.0
        print(f"  {row['name'][:34]:34s} {0.0:5.1f} {0:8d} "
              f"{'χ-запас':>10s} {row['leak']:9.1f} {0.0:8.1f} "
              f"{'—':>9s} {f'{t_death:.1f} д':>9s}")
        continue
    q = row.get("Q_max", 0) / 1e3
    t7 = row.get("t_boil_S7")
    t22 = row.get("t_boil_S22")
    def _t(v):
        if v is None or v > 3.2e10:
            return "∞"
        if v > 3.15e7:
            return f"{v/3.156e7:.1f} г"
        if v > 86400:
            return f"{v/86400:.1f} д"
        if v > 3600:
            return f"{v/3600:.1f} ч"
        return f"{v/60:.1f} мин"
    print(f"  {row['name'][:34]:34s} {row['sigma']:5.1f} S{row['max_level']:<7d} "
          f"{q:10.1f} {row['P_cool']:9.1f} {row['cned_calc']:8.2f} "
          f"{_t(t7):>9s} {_t(t22):>9s}")

print()
print("  КЛЮЧЕВЫЕ ФИЗИЧЕСКИЕ СЛЕДСТВИЯ:")
print("  1. Дриада (σ 6.0 → макс S4): рекордное φ-насыщение НЕ дает доступа к Сферам —")
print("     у древесных резонаторов нет силовых меридианов. φ-доля и σ — независимые оси.")
print("  2. Демон-Повелитель (σ 8.5): даже ему недоступна Сфера 7 без культивации;")
print("     χ-ткань кипит при 120 °C → ΔT_crit = 78 К → Q_max = 29.9 МДж:")
print("     обратная сторона — дикая теплоемкость, недоступная углеродной биологии.")
print("  3. Землянин (σ 1.5): фон CNED 9.1 Вт (11% BMR) даже без варп-повреждений;")
print("     варп-декомпрессия транзита поднимает утечку до 23.9 Вт (28% BMR).")
print("  4. Гоблин: при σ 4.0 утечка 2.6 Вт съедает 87% φ-подпитки (3.0 Вт) —")
print("     раса живет на грани φ-банкротства, что и дает 70 лет вместо 220.")

# Демон-Повелитель: пересчет Q_max с T_crit=120
lord = next(r for r in registry if "Повелитель" in r["name"])
print()
print(f"  Демон-Повелитель: Q_max = c·m·ΔT = 3470·110·(120−42) = {lord['Q_max']/1e6:.1f} МДж")
print(f"  Удержание S22: P_dump = {lord['P_dump_S22']:.2f} Вт → выживание {lord['t_boil_S22']/86400:.0f} суток непрерывно")

# ── Оверлеи культивации ─────────────────────────────────────────────────────
print()
print("=" * 78)
print("ЭТАП 4. ОВЕРЛЕИ КУЛЬТИВАЦИИ (Мнемар / Лич)")
print("=" * 78)
overlay_results = {}
for base_name in ("H.e. видовая норма", "Эльф (Sylva aetheriensis)",
                  "Дриада (Dryadis collective)", "Гоблин (Goblinus subterraneus)"):
    base = next(r for r in RACES if r["name"] == base_name)
    for ov_name, ov in OVERLAYS.items():
        sigma = min(10.0, base["sigma"] + ov["d_sigma"])
        bf = base["bf"] + ov["d_bf"]
        rho_phi = bf * (sigma / SIGMA_RAW) * RHO_PHI_MAX
        phi_pct = rho_phi / (base["rho"] + rho_phi) * 100
        life = base["life"] * ov["life_x"]
        lvl = max_level(sigma)
        overlay_results[f"{base_name.split(' (')[0]} + {ov_name}"] = {
            "sigma": sigma, "rho_phi": rho_phi, "phi_pct": phi_pct,
            "life_yr": life, "max_level": lvl,
        }
        print(f"  {base_name.split(' (')[0][:14]:14s} + {ov_name:6s}: σ = {sigma:4.1f} → S{lvl:<2d}; "
              f"φ-доля {phi_pct:5.1f}%; жизнь {life:6.0f} лет")

# Критические кейсы канона
print()
print("  КРИТИЧЕСКИЕ КЕЙСЫ (проверка против канона):")
mn_elf = overlay_results["Эльф + Мнемар"]
print(f"    Эльф+Мнемар: φ = {mn_elf['phi_pct']:.1f}% (канон: 52.3% — физпредел углерода)")
mn_dry = overlay_results["Дриада + Мнемар"]
print(f"    Дриада+Мнемар: φ = {mn_dry['phi_pct']:.1f}% (канон: 55.6% — абсолютный рекорд)")
lc_gob = overlay_results["Гоблин + Лич"]
print(f"    Гоблин+Лич: σ = {lc_gob['sigma']:.1f}, φ-структуры деградировали → некро-якорь")

# ── Сохранение ──────────────────────────────────────────────────────────────
out = {
    "water_props": {"L_vap_kJ_kg": L_VAP_310 / 1e3, "c_p": C_WATER_310},
    "registry": registry,
    "regressions": {
        "life_vs_phi": {"k": float(k_life), "b": float(b_life), "r2": float(r2_life)},
        "regen_vs_phi": {"k": float(k_reg), "b": float(b_reg), "r2": float(r2_reg)},
    },
    "overlays": overlay_results,
    "cned_model": {"threshold_sigma": 5.0, "k_W_per_sigma": 2.6},
}
with open(os.path.join(OUT_DIR, "06_races.json"), "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2, default=float)
print()
print(f"[OK] Сохранено: {os.path.join(OUT_DIR, '06_races.json')}")

# ════════════════════════════════════════════════════════════════════════════
# ГРАФИКИ (для PDF Тома 3)
# ════════════════════════════════════════════════════════════════════════════
print()
print("=" * 78)
print("ЭТАП 5. ГРАФИКИ ДЛЯ ОТЧЕТА")
print("=" * 78)

import matplotlib
matplotlib.use("Agg")
import matplotlib.font_manager as fm
fm.fontManager.addfont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
import matplotlib.pyplot as plt
plt.rcParams["font.sans-serif"] = ["DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False

# Палитра документа (cascade, intent=cold)
C_ACCENT = "#1f6c92"
C_ACCENT2 = "#c23a50"
C_MID = "#32454e"
C_ICON = "#4b86a4"
C_MUTED = "#747b7e"

# ── График 1: кривые тепловой деградации при удержании S7 ───────────────────
fig, ax = plt.subplots(figsize=(8.4, 4.6), constrained_layout=True)
t_hours = np.linspace(0, 48, 500)
plot_set = [
    ("Гоблин (σ 4.0)", "Гоблин (Goblinus subterraneus)", C_ACCENT2),
    ("Орк (σ 5.5)", "Орк (Orcus industrialis)", C_ICON),
    ("H.e. норма (σ 6.5)", "H.e. видовая норма", C_MID),
    ("Эльф (σ 7.0)", "Эльф (Sylva aetheriensis)", C_ACCENT),
]
for label, key, color in plot_set:
    row = next(r for r in registry if r["name"] == key)
    P = row["P_dump_S7"]
    if P <= 0:
        continue
    dT = P * t_hours * 3600 / (C_TISSUE * row["M"])
    T = row["T"] + dT
    mask = T <= T_DENAT_C
    ax.plot(t_hours[mask], T[mask], label=label, color=color, lw=2.0)
    if not mask.all():
        i = np.argmax(~mask)
        ax.plot(t_hours[i], T_DENAT_C, "x", color=color, markersize=8, markeredgewidth=2)
        ax.annotate(f"{t_hours[i]:.1f} ч", (t_hours[i], T_DENAT_C),
                    textcoords="offset points", xytext=(-30, -14),
                    fontsize=8.5, color=color)
ax.axhline(T_DENAT_C, color=C_MUTED, ls="--", lw=1.0, alpha=0.8)
ax.text(0.4, T_DENAT_C + 0.15, "порог денатурации 41.8 °C", fontsize=8.5, color=C_MUTED)
ax.set_xlabel("Время удержания Сферы 7, часов", fontsize=10)
ax.set_ylabel("Температура тела, °C", fontsize=10)
ax.set_title("Тепловая деградация при удержании Сферы 7 выше класса проводимости",
             fontsize=11, color=C_MID, pad=10)
ax.legend(fontsize=9, frameon=False, loc="upper left")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.grid(True, ls="--", alpha=0.2)
ax.set_xlim(0, 48)
fig.savefig(os.path.join(CHART_DIR, "chart1_S7_degradation.png"), dpi=200)
plt.close(fig)
print("  [OK] chart1_S7_degradation.png")

# ── График 2: жизнь и регенерация от φ-доли ─────────────────────────────────
fig, ax1 = plt.subplots(figsize=(8.4, 4.4), constrained_layout=True)
ax2 = ax1.twinx()
phi_all = [r["phi"] for r in RACES if r["cat"] == "base" and r["life"] <= 500]
life_all = [r["life"] for r in RACES if r["cat"] == "base" and r["life"] <= 500]
lbl_all = [r["name"].split(" (")[0] for r in RACES if r["cat"] == "base" and r["life"] <= 500]
ax1.scatter(phi_all, life_all, s=60, color=C_ACCENT, zorder=3, label="Жизнь, лет (левая ось)")
xs = np.linspace(5, 36, 100)
ax1.plot(xs, k_life * xs + b_life, color=C_ACCENT, lw=1.4, ls="--", alpha=0.7,
         label=f"модель: {k_life:.1f}·φ% + {b_life:.0f}")
for x, y, lbl in zip(phi_all, life_all, lbl_all):
    ax1.annotate(lbl, (x, y), textcoords="offset points", xytext=(6, 5), fontsize=8, color=C_MID)
# Демон-реликт: χ-выброс вне тренда
ax1.scatter([demon["phi"]], [demon["life"]], s=70, color=C_MUTED, marker="^", zorder=3,
            label="Демон: χ-якорь, лет (левая ось)")
ax1.annotate("Демон (χ)", (demon["phi"], demon["life"]),
             textcoords="offset points", xytext=(6, -2), fontsize=8, color=C_MUTED)
phi_r2 = [r["phi"] for r in reg_races]
regen_all = [r["regen"] for r in reg_races]
ax2.scatter(phi_r2, regen_all, s=55, color=C_ACCENT2, marker="s", zorder=3, label="Регенерация, × земной (правая ось)")
ax2.plot(xs, k_reg * xs + b_reg, color=C_ACCENT2, lw=1.4, ls="--", alpha=0.7)
ax1.set_xlabel("φ-доля тканей, %", fontsize=10)
ax1.set_ylabel("Жизнь, лет", fontsize=10, color=C_ACCENT)
ax2.set_ylabel("Регенерация, × земной", fontsize=10, color=C_ACCENT2)
ax1.set_title("Жизнь и регенерация линейны по φ-доли: два следствия одного конденсата",
              fontsize=11, color=C_MID, pad=10)
h1, l1 = ax1.get_legend_handles_labels()
h2, l2 = ax2.get_legend_handles_labels()
ax1.legend(h1 + h2, l1 + l2, fontsize=9, frameon=False, loc="upper left")
ax1.spines["top"].set_visible(False)
ax2.spines["top"].set_visible(False)
ax1.grid(True, ls="--", alpha=0.2)
fig.savefig(os.path.join(CHART_DIR, "chart2_life_phi.png"), dpi=200)
plt.close(fig)
print("  [OK] chart2_life_phi.png")

# ── График 3: карта «железа» σ × Q_max (лог-оси) ────────────────────────────
fig, ax = plt.subplots(figsize=(8.4, 4.8), constrained_layout=True)
for row in registry:
    if row["cat"] == "post" or "Q_max" not in row:
        continue
    color = C_ACCENT if row["sigma"] >= 5 else C_ACCENT2
    ax.scatter(row["sigma"], row["Q_max"] / 1e3, s=70, color=color, zorder=3)
    lbl = row["name"].split(" (")[0].replace("H.e. ", "")
    ax.annotate(lbl, (row["sigma"], row["Q_max"] / 1e3),
                textcoords="offset points", xytext=(7, 5), fontsize=8, color=C_MID)
# Пороговые линии Сфер
for k, sty in ((2, ":"), (4, "--"), (7, "-")):
    s = sigma_req(k)
    ax.axvline(s, color=C_MUTED, ls=sty, lw=1.0, alpha=0.7)
    ax.text(s + 0.05, 0.6, f"S{k}: σ={s:.1f}", fontsize=8, color=C_MUTED, rotation=90, va="bottom")
ax.set_yscale("log")
ax.set_xlabel("Проводимость меридианов σ_e", fontsize=10)
ax.set_ylabel("Тепловой бюджет Q_max, кДж (лог)", fontsize=10)
ax.set_title("Карта биологического железа: классы проводимости × тепловые бюджеты",
             fontsize=11, color=C_MID, pad=10)
ax.set_xlim(0, 10.8)
ax.set_ylim(0.5, 60000)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.grid(True, ls="--", alpha=0.2, which="both")
fig.savefig(os.path.join(CHART_DIR, "chart3_hardware_map.png"), dpi=200)
plt.close(fig)
print("  [OK] chart3_hardware_map.png")

print()
print("[ГОТОВО] Модуль биологии: 3 графика + JSON реестр")
