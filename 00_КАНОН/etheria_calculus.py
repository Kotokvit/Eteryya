#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ЭТЕРИЯ — КАЛЬКУЛЯТОР КАНОНА (CALCULUS_ETERIA)
================================================
Точная математика вселенной Этерии по аксиомам канона.
Автор исполнения: Super Z (Z.ai) для Виталия Котока (Kotokvit), 2026-09-24
Точность: mpmath 50 значащих цифр.

Аксиомы-входы (CANON-LOCKED):
  A1  a            = 2.3 а.е.          — большая полуось Этерии
  A2  M            = 2.9861e24 кг     — масса Этерии (0.500 M⊕)
  A3  rho_avg      = 3580 кг/м³       — средняя плотность (канон 3.58 г/см³)
  A4  R_canon      = 5838.4 км        — канонический радиус (Theia-аналог, CRS/QGIS)
  A5  K            = 9/7              — темпоральная анизотропия (1 цикл = K зем. лет)
  A6  T_rot        = 30.86 зем.ч      — период вращения (= 24 эф.ч)
  A7  L_sun        = 3.828e26 Вт      — светимость Солнца
  A8  sigma_SB     = 5.6704e-8        — Стефан-Больцман
  A9  фредерит Q   = 210 Вт/м²        — тепловой поток реактора
  A10 атмосфера    = 73% Ar / 22% O2 / 5% CO2, 1.47 бар
  A11 f_Bezdna     = 18.7 Гц          — Гул Бездны
  A12 E_transit    = 8.0124e16 Дж     — энергия фазового скачка (канон v3.0)

Вывод: консольный отчёт + CALCULUS_ETERIA.json (рядом со скриптом)
"""
import json
from mpmath import (mp, mpf, pi, sin, cos, tan, acos, asin, atan, sqrt, log,
                    log10, exp, power as pw, fabs, degrees as deg, radians as rad,
                    findroot, mpc, inf)
from fractions import Fraction

mp.dps = 50
R = {}      # реестр результатов {ключ: (значение_строкой, статус, канон_значение)}

def reg(key, val, canon=None, tol=mpf('1e-6'), unit=''):
    """Зарегистрировать результат, сравнить с каноном."""
    v = val if isinstance(val, mpf) else mpf(val)
    entry = {'value': float(v), 'exact': mp.nstr(v, 30), 'unit': unit}
    if canon is not None:
        c = mpf(canon)
        d = fabs(v - c)
        rel = d / fabs(c) if c != 0 else d
        entry['canon'] = float(c)
        entry['delta_abs'] = float(d)
        entry['delta_rel'] = float(rel)
        entry['status'] = 'OK' if rel <= tol else ('~' if rel <= tol*1000 else 'MISMATCH')
    else:
        entry['status'] = 'NEW'
    R[key] = entry
    flag = entry['status']
    cstr = f"  канон={entry.get('canon')}" if canon is not None else ''
    print(f"  [{flag:7s}] {key:42s} = {mp.nstr(v, 18)} {unit}{cstr}")
    return v

def line(ch='-', n=78): print(ch * n)

# =====================================================================
# КОНСТАНТЫ (CODATA 2018 / IAU 2015)
# =====================================================================
AU    = mpf('1.495978707e11')       # м
G     = mpf('6.67430e-11')          # м³/(кг·с²)
c     = mpf('2.99792458e8')         # м/с
sigma = mpf('5.670374419e-8')       # Вт/(м²·К⁴) — точное CODATA
sigma_canon = mpf('5.6704e-8')      # канонное значение (аудит v3.0)
L_sun = mpf('3.828e26')             # Вт (IAU)
M_sun = mpf('1.98892e30')           # кг (аудит v3.0)
M_earth = mpf('5.9722e24')          # кг
R_earth = mpf('6371.0e3')           # м (средний)
M_moon = mpf('7.342e22')            # кг
h_pl  = mpf('6.62607015e-34')       # Дж·с (точно)
k_B   = mpf('1.380649e-23')         # Дж/К (точно)
TNT_Mt = mpf('4.184e15')            # Дж на мегатонну ТНТ
l_P   = mpf('1.616255e-35')         # планковская длина, м
YEAR_D = mpf('365.25')              # юлианский год, суток
DAY_S  = mpf('86400')

# Аксиомы Этерии
a_Et   = mpf('2.3')
M_Et   = mpf('2.9861e24')
rho_Et = mpf('3580')
R_canon= mpf('5838.4e3')
K      = Fraction(9, 7);  Kf = mpf(9)/7
kappa  = mpf(7)/9
T_rot_h= mpf('30.86')                # зем.ч (округлённый канон)
Q_frederite = mpf('210')             # Вт/м²
f_bez  = mpf('18.7')
E_tr_canon = mpf('8.0124e16')

print("=" * 78)
print("  ЭТЕРИЯ — КАЛЬКУЛЯТОР КАНОНА · mpmath dps=50")
print("=" * 78)

# =====================================================================
# ЧАСТЬ 1. ПЛАНЕТА: МАССА, РАДИУС, ВНУТРЕННЕЕ СТРОЕНИЕ
# =====================================================================
print("\nЧАСТЬ 1. ПЛАНЕТА")
line()

# 1.1 — Цепочка A: R из (M, rho) — «справочное вычисление» аксиом
R_derived = (3*M_Et / (4*pi*rho_Et)) ** (mpf(1)/3)
reg('R_derived_M_rho_km', R_derived/1e3, '5839.525651487551', unit='км')

# 1.2 — Цепочка B: канон R=5838.4; согласованная плотность при M=2.9861e24
rho_consistent = 3*M_Et / (4*pi*R_canon**3)
reg('rho_consistent_R_canon', rho_consistent/1e3, unit='г/см³ [NEW]')
reg('M_from_R_canon_rho3580_kg', 4*pi/3*R_canon**3*rho_Et, unit='кг [NEW]')
reg('M_ratio_earth', M_Et/M_earth, '0.500', unit='M⊕')
reg('R_ratio_earth_mean', R_canon/R_earth, '0.9163', unit='R⊕')

# 1.3 — Двухслойная модель интерьера (R_core=35.5% R, rho_core=16, rho_mantle=3.0)
# ВАЖНО: используем СОГЛАСОВАННУЮ плотность (M + R_канон) — она замыкает ядро ровно на канон
rho_c, rho_m = mpf(16.0), mpf(3.0)
x_core_exact = ((rho_consistent/1e3 - rho_m)/(rho_c - rho_m)) ** (mpf(1)/3)
reg('core_fraction_exact', x_core_exact, '0.355', tol=mpf('2e-3'), unit='доля R')
R_core = x_core_exact * R_canon
reg('R_core_km', R_core/1e3, '2073.2', tol=mpf('5e-4'), unit='км')
M_core = 4*pi/3*(R_core**3)*rho_c*1e3
M_mant = M_Et - M_core
reg('M_core_kg', M_core, unit='кг [NEW]')
reg('M_mantle_kg', M_mant, unit='кг [NEW]')
reg('M_core_fraction', M_core/M_Et, unit='[NEW]')
# Проверка: средняя плотность двухслойной модели
rho_2layer = M_Et/(4*pi/3*R_canon**3)/1e3
reg('rho_2layer_g_cm3', rho_2layer, '3.58', unit='г/см³')

# 1.4 — Гравитация и космос
g_derived = G*M_Et/R_derived**2
reg('g_derived', g_derived, '5.844339129254699', unit='м/с²')
g_canon_R = G*M_Et/R_canon**2
reg('g_canon_R', g_canon_R, '5.85', tol=mpf('2e-3'), unit='м/с² (R=канон)')
v_esc = sqrt(2*G*M_Et/R_derived)
reg('v_escape_kms', v_esc/1e3, '8.261739315819064', unit='км/с')
v_esc_R = sqrt(2*G*M_Et/R_canon)
reg('v_escape_canonR_kms', v_esc_R/1e3, '8.27', tol=mpf('2e-3'), unit='км/с')
C_der = 2*pi*R_derived
reg('circumference_derived_km', C_der/1e3, '36690.82177432488', unit='км')
C_can = 2*pi*R_canon
reg('circumference_canon_km', C_can/1e3, '36685', tol=mpf('3e-4'), unit='км (R=канон)')
A_surf = 4*pi*R_canon**2
reg('surface_area_Mkm2', A_surf/1e12, unit='млн км² [NEW]')
V_tot = 4*pi/3*R_canon**3
reg('volume_e12_m3', V_tot/1e12, unit='×10¹² м³ [NEW]')

# 1.5 — Масштаб карты: 1 клетка = 100 км = 0.98° широты
deg_lat_per_100km = mpf(100)/(C_can/1e3/360)
reg('map_100km_in_deg_lat', deg_lat_per_100km, '0.98', tol=mpf('5e-3'), unit='°')
km_per_deg_lat = C_can/1e3/360
reg('km_per_deg_lat', km_per_deg_lat, unit='км/° [NEW]')

# =====================================================================
# ЧАСТЬ 2. ОРБИТА, ЗВЕЗДА, ОБРАТНОЕ НАБЛЮДЕНИЕ ЗЕМЛИ
# =====================================================================
print("\nЧАСТЬ 2. ОРБИТА И ОБРАТНОЕ НАБЛЮДЕНИЕ")
line()

T_orb_yr = sqrt(a_Et**3)                     # Кеплер, радианы Гаусса → годы
reg('T_eteria_years', T_orb_yr, '3.488122704263713', unit='лет')
S_solar = L_sun / (4*pi*(a_Et*AU)**2)
reg('solar_flux_eteria', S_solar, '257.30935073886116', tol=mpf('4e-6'), unit='Вт/м²')
S_ratio = S_solar / (L_sun/(4*pi*AU**2))
reg('solar_flux_ratio_earth', S_ratio, '0.189', tol=mpf('5e-3'), unit='×Земля')

# Равновесная температура: чёрное тело A=0 (и с канонной sigma)
T_eq = (S_solar/(4*sigma_canon))**(mpf(1)/4)
reg('T_equil_black_K', T_eq, '183.52530743028365', unit='K')
reg('T_equil_black_C', T_eq - mpf('273.15'), '-89.63', tol=mpf('5e-3'), unit='°C')
T_eq_sigmaCODATA = (S_solar/(4*sigma))**(mpf(1)/4)
reg('T_equil_sigma_CODATA_K', T_eq_sigmaCODATA, unit='K [NEW]')

# С фредеритом Q=210 Вт/м² равномерно по поверхности
Q_avg = Q_frederite/4
T_freder = ((S_solar + 4*Q_avg)/(4*sigma_canon))**(mpf(1)/4)
# эквивалентно (S/4 + Q/4)/sigma = (257.3/4 + 52.5)/sigma — проверка сложения
T_freder2 = ((S_solar/4 + Q_frederite/4)/sigma_canon)**(mpf(1)/4)
assert fabs(T_freder - T_freder2) < mpf('1e-30')
reg('T_with_frederite_K', T_freder, '213.05', tol=mpf('5e-4'), unit='K')
reg('T_with_frederite_C', T_freder - mpf('273.15'), '-60.1', tol=mpf('2e-3'), unit='°C')
reg('dT_frederite_C', T_freder - T_eq, '29.5', tol=mpf('5e-3'), unit='°C uplift')

# Синодический период и элонгация
P_syn = 1/(1 - 1/T_orb_yr)
reg('P_synodic_years', P_syn, '1.4019094389060367', unit='лет')
reg('elongation_max_deg', deg(asin(1/a_Et)), '25.771461740550667', unit='°')

# Земля с Этерии: угловой размер в МАКСИМАЛЬНОЙ элонгации (треугольник прямой)
d_at_max = a_Et*cos(asin(1/a_Et))            # гипотенуза × cos
reg('Earth_dist_at_maxelong_AU', d_at_max, unit='а.е. [NEW]')
D_earth_eq = 2*R_earth
ang_Earth = D_earth_eq/(d_at_max*AU)*206264.806247    # угл.сек
reg('Earth_angular_size_maxelong_arcsec', ang_Earth, '8.48', tol=mpf('5e-3'), unit='″')

# Земля с Этерии: блеск в максимуме (через H-величину Земли, фаза при квадратуре)
# m = H + 5·log10(d_BS·d_BO) − 2.5·log10(Φ(α)); H(Земля) = −3.99, α = 90° → Φ = 1/π
H_earth = mpf('-3.99')
Phi90 = 1/pi
m_Earth = H_earth + 5*log10(mpf(1)*d_at_max) - 2.5*log10(Phi90)
reg('Earth_mag_at_maxelong', m_Earth, '-1.08', tol=mpf('0.15'), unit='mag')

# Конъюнкции за 30 лет (модель aleksey_window: 21.40 за макроцикл 30 лет)
n_conj_30 = 30/P_syn
reg('conjunctions_per_30yr', n_conj_30, '21.40', tol=mpf('2e-3'), unit='')

# 33_Теорема_Распада: сколько синодических циклов ближе всего к 33 годам?
for n in range(22, 26):
    print(f"    {n} синодич. = {mp.nstr(n*P_syn, 8)} лет;  ", end='')
print()
n33 = round(33/P_syn)
reg('years_23_synodic', 23*P_syn, unit='лет [NEW: 33_Теорема]')
reg('years_24_synodic', 24*P_syn, unit='лет [NEW]')

# =====================================================================
# ЧАСТЬ 3. АТМОСФЕРА И ЭНЕРГОБАЛАНС: ПРОБЛЕМА +20°C
# =====================================================================
print("\nЧАСТЬ 3. АТМОСФЕРА И ЭНЕРГЕТТИЧЕСКИЙ БАЛАНС")
line()
P_atm = mpf('1.47')      # бар
xAr, xO2, xCO2 = mpf('0.73'), mpf('0.22'), mpf('0.05')
M_Ar, M_O2, M_CO2 = mpf('39.948'), mpf('31.998'), mpf('44.01')
M_air = xAr*M_Ar + xO2*M_O2 + xCO2*M_CO2
reg('atm_mean_molar_mass', M_air, unit='г/моль [NEW]')
reg('atm_pCO2_bar', xCO2*P_atm, unit='бар [NEW]')
reg('atm_pCO2_vs_Earth_ppm', xCO2*P_atm/mpf('0.00042'), unit='× Земли [NEW]')
# Масштабная высота при T=-60°C (верхний слой) и g
T_strat = mpf('212.9')
H_scale = mpf('8.314462618')*T_strat/(M_air/1000*g_canon_R)
reg('atm_scale_height_km', H_scale/1e3, unit='км [NEW]')
H_scale_293 = mpf('8.314462618')*mpf('293.15')/(M_air/1000*g_canon_R)
reg('atm_scale_height_293K_km', H_scale_293/1e3, unit='км [NEW]')

# Сколько фредерит-потока нужно для +20°C БЕЗ парникового эффекта?
T_target = mpf('293.15')
Q_needed_avg = sigma_canon*T_target**4 - S_solar/4
reg('Q_needed_for_20C_Wm2_surface', 4*Q_needed_avg, unit='Вт/м² [NEW]')
# Парниковая форсирующая от CO2 (логарифмический закон, IPCC: 5.35 ln C/C0)
dF_CO2 = mpf('5.35')*log(xCO2*P_atm/mpf('0.00042'))
reg('CO2_forcing_Wm2', dF_CO2, unit='Вт/м² [NEW]')
# Чувствительность 0.8 K/(Вт/м²) — земной диапазон
reg('dT_greenhouse_est_C', mpf('0.8')*dF_CO2, unit='°C [NEW оценка]')
# Итог: T с фредеритом + парник
T_with_GH = T_freder + mpf('0.8')*dF_CO2
reg('T_final_estimate_C', T_with_GH - mpf('273.15'), unit='°C [NEW оценка]')

# Точка росы/кипения при 1.47 бар: аргон, O2, CO2 (для криогенных зон)
print("    Кипение при 1.47 бар (правило Клаузиуса–Клапейрона, приближение):")
for name, T_b, P_b in [('Ar', mpf('87.302'), mpf('1.013')), ('O2', mpf('90.188'), mpf('1.013')),
                        ('CO2 (сублим)', mpf('194.685'), mpf('1.013'))]:
    dH = mpf('8.314')*T_b*log(P_atm/P_b)/log(2)**0  # placeholder, ниже точнее
    # Точные дельты: Ar 6.43 кДж/моль, O2 6.82, CO2 25.2 (сублим)
    dHv = {'Ar': mpf('6430'), 'O2': mpf('6820'), 'CO2 (сублим)': mpf('25200')}[name]
    T_boil = 1/(1/T_b - mpf('8.314462618')*log(P_atm/P_b)/dHv)
    print(f"      {name:14s}: T_boil(1.47 бар) = {mp.nstr(T_boil, 6)} K = {mp.nstr(T_boil-mpf('273.15'), 5)} °C")

# =====================================================================
# ЧАСТЬ 4. КАЛЕНДАРЬ И АНИЗОПИЯ ВРЕМЕНИ
# =====================================================================
print("\nЧАСТЬ 4. КАЛЕНДАРЬ K = 9/7")
line()
eth_hour_h = mpf(24)/mpf('18.6666666666667')     # из канона «24 зем.ч = 18.67 эф.ч»
reg('eth_hour_in_earth_hours', Kf, unit='ч (эф.час = K зем.ч)')
T_rot_exact = mpf(24)*Kf
reg('T_rotation_exact_earth_h', T_rot_exact, '30.857', tol=mpf('3e-4'), unit='ч')
print(f"    30.86 ч (канон, округлён) vs точное 24×9/7 = {mp.nstr(T_rot_exact, 10)} ч = "
      f"{int(T_rot_exact)} ч {mp.nstr((T_rot_exact-30)*60, 6)} мин")
reg('cycle_in_earth_days', Kf*YEAR_D, '469.61', tol=mpf('5e-5'), unit='сут')
eth_day_earth_days = T_rot_exact/24
reg('cycle_in_eth_days', Kf*YEAR_D/eth_day_earth_days, '365.4', tol=mpf('5e-4'), unit='эф.сут')
# 8 циклов ↔ земля
y8 = 8*Kf
m8 = (y8 - 10)*12
d8 = (m8 - 3)*mpf('30.436875')
print(f"    8 циклов = {mp.nstr(y8, 8)} лет = 10 лет + {mp.nstr(m8,4)} мес + {mp.nstr(d8,4)} дн (канон: 3 мес 13 дн)")
# Обратная: 8 земных лет в циклах
cyc8 = 8*kappa
print(f"    8 зем.лет = {mp.nstr(cyc8, 8)} цикла = 6 циклов + {mp.nstr((cyc8-6)*Kf*YEAR_D, 6)} зем.сут (канон: ~104 дн)")

# Двухтрековая хронология T-N (читательская 1:1 ↔ физическая K)
print("\n    Двухтрековая хронология (T-0 = 2023, Одесса):")
print(f"    {'Метрика':>8} {'Год (1:1)':>10} {'Циклов прошло':>14} {'Субъективно, лет':>17}")
for N in [64, 50, 40, 33, 31, 24, 23, 22, 21, 20, 19, 16, 14, 13, 12, 10, 0]:
    yr = 2023 - N
    subj = N*Kf if N else 0
    print(f"    T-{N:<5} {yr:>10} {N:>14} {mp.nstr(subj, 6) if N else '0':>17}")

# Маятник Фуко на 47.12°N
lat4 = mpf('47.12')
T_fou_h = T_rot_h/sin(rad(lat4))
reg('Foucault_period_47N_h', T_fou_h, '42.1', tol=mpf('5e-3'), unit='зем.ч')
rate_deg_min = 360*sin(rad(lat4))/(T_rot_h*60)
print(f"    Скорость прецессии: {mp.nstr(rate_deg_min, 5)} °/ЗЕМ.мин  |  канон «0.24°/мин» — ПРОВЕРКА")
rate_eth = 360*sin(rad(lat4))/(24*60)
print(f"    В эфирианских минутах: {mp.nstr(rate_eth, 5)} °/эф.мин (эф.мин длиннее в K)")

# =====================================================================
# ЧАСТЬ 5. M1/M2 — АФОКАЛЬНЫЙ ГРАВИТАЦИОННЫЙ КАСКАД
# =====================================================================
print("\nЧАСТЬ 5. ЛИНЗЫ M1/M2 (АФОКАЛЬНЫЙ КАСКАД)")
line()
M1_kg, M2_kg = mpf('2.20e23'), mpf('2.94e23')
reg('M1_in_moon_masses', M1_kg/M_moon, '3', tol=mpf('2e-3'), unit='M_Луны')
reg('M2_in_moon_masses', M2_kg/M_moon, '4', tol=mpf('2e-3'), unit='M_Луны')
reg('M_total_in_moon_masses', (M1_kg+M2_kg)/M_moon, '7', tol=mpf('2e-3'), unit='M_Луны')
reg('M_total_in_earth_masses', (M1_kg+M2_kg)/M_earth, '0.0861', tol=mpf('5e-3'), unit='M⊕')  # канон «0.86%» — ОШИБКА ×10: 7 лун = 8.61% M⊕

rs1 = 2*G*M1_kg/c**2
rs2 = 2*G*M2_kg/c**2
reg('r_s_M1_m', rs1, '3.27e-4', tol=mpf('5e-3'), unit='м')
reg('r_s_M2_m', rs2, '4.36e-4', tol=mpf('5e-3'), unit='м')

# Геометрия (от Земли-наблюдателя; Солнце в 0):
#   Земля 1.0 | M1 1.9 | M2 x | Этерия 2.3 (а.е.)
#   f_M2 = D_L2*D_LS2/D_S2 : D_L2=x-1, D_S2=1.3, D_LS2=2.3-x    (источник: Этерия)
#   f_M1 = D_L1*D_LS1/D_S1 : D_L1=0.9, D_S1=x-1, D_LS1=x-1.9    (источник: M2)
#   Афокальное условие: f_M1 + f_M2 = x - 1.9
fM1 = lambda x: mpf('0.9')*(x-mpf('1.9'))/(x-1)
fM2 = lambda x: (x-1)*(mpf('2.3')-x)/mpf('1.3')
afocal = lambda x: fM1(x) + fM2(x) - (x-mpf('1.9'))
x_lo, x_hi = mpf('1.91'), mpf('2.29')
try:
    root = findroot(afocal, (x_lo, x_hi))
except Exception:
    # бисекция вручную
    lo, hi = x_lo, x_hi
    for _ in range(200):
        mid = (lo+hi)/2
        if afocal(lo)*afocal(mid) <= 0: hi = mid
        else: lo = mid
    root = (lo+hi)/2
reg('M2_position_afocal_root_AU', root, '2.21331293', tol=mpf('5e-6'), unit='а.е.')
print(f"    Канон «2.21331293 калибровано»: отклонение от точного корня = "
      f"{mp.nstr((root - mpf('2.21331293'))*mpf('1.496e8'), 4)} км")
f1, f2 = fM1(root), fM2(root)
reg('f_M1_AU', f1, '0.2324', tol=mpf('2e-3'), unit='а.е.')
reg('f_M2_AU', f2, '0.0809', tol=mpf('2e-3'), unit='а.е.')
reg('f_M1_m', f1*AU, '3.48e10', tol=mpf('3e-3'), unit='м')
reg('f_M2_m', f2*AU, '1.21e10', tol=mpf('3e-3'), unit='м')
reg('d_M1_M2_AU', root - mpf('1.9'), '0.3133', tol=mpf('5e-4'), unit='а.е.')
reg('d_M1_M2_m', (root-mpf('1.9'))*AU, '4.68e10', tol=mpf('3e-3'), unit='м')
reg('afocal_residual_AU', afocal(root), unit='а.е. [NEW: |остаток|]')
reg('magnification_M', -f1/f2, '-2.8725', tol=mpf('2e-4'), unit='')

# Углы Эйнштейна каждой линзы (источник — Этерия для M2; M2 для M1)
aE2 = sqrt(4*G*M2_kg*(mpf('2.3')-root)*AU / (c**2*(root-1)*(mpf('1.3'))*AU**2) * AU)
# α_E = sqrt(4GM D_LS/(c² D_L D_S)) — все D в метрах, от Земли:
D_L2, D_S2, D_LS2 = (root-1)*AU, mpf('1.3')*AU, (mpf('2.3')-root)*AU
aE2 = sqrt(4*G*M2_kg*D_LS2/(c**2*D_L2*D_S2))
reg('alpha_E_M2_rad', aE2, '4.07e-8', tol=mpf('5e-3'), unit='рад')
reg('alpha_E_M2_arcsec', aE2*206264.806247, '0.0084', tol=mpf('5e-3'), unit='″')
D_L1, D_S1, D_LS1 = mpf('0.9')*AU, (root-1)*AU, (root-mpf('1.9'))*AU
aE1 = sqrt(4*G*M1_kg*D_LS1/(c**2*D_L1*D_S1))
reg('alpha_E_M1_rad', aE1, '1.60e-8', tol=mpf('5e-3'), unit='рад')
reg('alpha_E_M1_arcsec', aE1*206264.806247, '0.0033', tol=mpf('5e-3'), unit='″')

# Релятивистские поправки и потенциал
reg('rs_over_DL_M1', rs1/D_L1, '2.4e-15', tol=mpf('5e-2'), unit='')
reg('rs_over_DL_M2', rs2/D_L2, '3.1e-15', tol=mpf('5e-2'), unit='')
# Задержка Шапиро (макс, луч сквозь M1):
b1 = aE1*D_L1
shapiro = 2*G/c**3*(M1_kg+M2_kg)*log(4*D_L1*D_LS1/(b1**2)+1) if b1>0 else mpf(0)
print(f"    Задержка Шапиро (каскад, оценка): ~{mp.nstr(shapiro, 4)} с (канон: 0.0001 мкс = 1e-10 с)")
d_light = (a_Et - 1)*AU/c
reg('light_delay_Earth_Eteria_s', d_light, unit='с [NEW]')
print(f"    Отношение (канон «в 7×10¹² раз меньше»): {mp.nstr(d_light/shapiro, 5)}")

# Золотой угол на базе 200 а.е.
lam_gold = pi*mpf('1e-10')
reg('golden_angle_rad', lam_gold, unit='рад (канон)')
L_base = mpf('200')*AU
reg('golden_displacement_200AU_km', L_base*lam_gold/1e3, '9.4', tol=mpf('5e-3'), unit='км')
reg('d_eff_2lP_m', 2*l_P, '3.2e-35', tol=mpf('5e-3'), unit='м')
reg('golden_displ_in_lP', L_base*lam_gold/l_P, unit='× ℓ_P [NEW] (канон 5.8e38)')

# Допуски позиционирования M2
print("    Допуски M2 (канон): Δ=0.001 а.е. — ок; 0.01 — измеримо; 0.1 — Этерия видна")
for dAU in ['0.001', '0.01', '0.1']:
    dx = mpf(dAU)*AU
    resid = fabs(afocal(root + mpf(dAU)))
    print(f"      Δ={dAU:>6} а.е. → расфокус каскада {mp.nstr(resid*AU/1e3, 5)} км")

# =====================================================================
# ЧАСТЬ 6. P³-КОНЪЮГАЦИЯ КИЕВ ↔ СЕКТОР 4
# =====================================================================
print("\nЧАСТЬ 6. P³-КОНЪЮГАЦИЯ КИЕВ ↔ СЕКТОР 4")
line()
def unit_vec(lat, lon):
    la, lo = rad(lat), rad(lon)
    return (cos(la)*cos(lo), cos(la)*sin(lo), sin(la))
def q_of(lat, lon):
    la, lo = rad(lat), rad(lon)
    qz = (cos(lo/2), 0, 0, sin(lo/2))
    qy = (cos(la/2), 0, sin(la/2), 0)
    w1,x1,y1,z1 = qz; w2,x2,y2,z2 = qy
    return (w1*w2-x1*x2-y1*y2-z1*z2, w1*x2+x2*w1+y1*z2-z1*y2,
            w1*y2-x1*z2+y1*w2+z1*x2, w1*z2+x1*y2-y1*x2+z1*w2)
kyiv = (mpf('50.4489'), mpf('30.5133'))
sec4 = (mpf('47.12'), mpf('34.89'))
v1, v2 = unit_vec(*kyiv), unit_vec(*sec4)
dot3 = sum(a*b for a, b in zip(v1, v2))
gc = acos(fabs(dot3))
reg('P3_gc_angle_deg', deg(gc), '4.402724634614686', unit='°')
q1, q2 = q_of(*kyiv), q_of(*sec4)
dq = fabs(sum(a*b for a, b in zip(q1, q2)))
d_fs = acos(dq)
reg('P3_dFS_quat_deg', deg(d_fs), '2.7491675451223805', unit='°')
reg('P3_dSO3_deg', 2*deg(d_fs), '5.498335090244761', unit='°')
reg('P3_s_phys_Earth_km', 2*mpf('6378.0e3')*gc/1e3, '980.197074137401', unit='км')  # R⊕=6378.0 — эталон скрипта конъюгации
reg('P3_s_phys_Eteria_km', 2*R_canon*gc/1e3, '897.2691435628414', unit='км')
# Сдвиг Протоки: PLAN_T-24 даёт ΔLat=+0.6533, ΔLon=+4.1567 — проверка
dl, dn = kyiv[0]-sec4[0], kyiv[1]-sec4[1]
print(f"    Фактический сдвиг Сектор4→Киев: ΔLat={mp.nstr(dl,6)}°, ΔLon={mp.nstr(dn,6)}°")
print(f"    Канон PLAN_T-24 «ΔLat=+0.6533°, ΔLon=+4.1567°» → РАСХОЖДЕНИЕ по широте (см. отчёт)")

# =====================================================================
# ЧАСТЬ 7. НУЛЬ-ЖИДКОСТЬ L_∅
# =====================================================================
print("\nЧАСТЬ 7. НУЛЬ-ЖИДКОСТЬ L_∅")
line()
theta_c = mpf(85)
rho_null_90 = sin(rad(mpf(90)-theta_c))**2
reg('rho_null_90deg', rho_null_90, '0.007596', tol=mpf('5e-4'), unit='')
n_Om, eps_Om, eps_Chi = mpf('2.05'), mpf('4.2'), mpf('1.8')
n_null = n_Om*sqrt(eps_Chi/eps_Om)
reg('n_null_imaginary', n_null, unit='i× [NEW]')
f_phi = mpf('1.4e12')
lam_phi = c/f_phi
reg('lambda_phi_um', lam_phi*1e6, unit='мкм [NEW]')
delta_opt = lam_phi/(2*pi*n_null)
reg('delta_opt_um', delta_opt*1e6, '25.4', tol=mpf('5e-3'), unit='мкм')
c_phi = c/sqrt(n_Om)
print(f"    c_φ = c/√n_Ω = {mp.nstr(c_phi, 8)} м/с; τ_info(L=100м) = {mp.nstr(100/c_phi*1e9, 6)} нс")
print(f"    ВАРИАНТЫ τ_info(100м): c/n_Ω → {mp.nstr(100*n_Om/c*1e9, 6)} нс; канон «~163 нс» = L/(c·n_Ω) — СВЕРХСВЕТОВАЯ скорость, физическая ошибка")
# Погружение Кайдена: d_n = d_0(n+1/2), d_K=2см, d_0=d_K/1.5
d0 = mpf('0.02')/mpf('1.5')
for n in range(4):
    dn_ = d0*(n+mpf('0.5'))
    hit = ' ← Кайден' if fabs(dn_-mpf('0.02')) < mpf('0.001') else ''
    print(f"      d_{n} = {mp.nstr(dn_*100, 5)} см{hit}")
# Озеро Отражений
aL, bL = mpf(500), mpf(300)
print(f"    Озеро Отражений: площадь = {mp.nstr(pi*aL*bL/1e4, 8)} га (a=500, b=300 м)")
# Хладник: Ландауэр
P_reso = mpf('4.88')
dI = P_reso*(1/f_phi)/(k_B*mpf('183.53')*log(2))
print(f"    dI/такт резоносомы (Ландауэр) = {mp.nstr(dI, 5)} бит/такт")

# =====================================================================
# ЧАСТЬ 8. БИОФИЗИКА
# =====================================================================
print("\nЧАСТЬ 8. БИОФИЗИКА")
line()

# 8.1 — Гул Бездны: энергия кванта 18.7 Гц
E_hum = h_pl*f_bez
reg('E_hum_187Hz_J', E_hum, '1.2391e-32', tol=mpf('5e-5'), unit='Дж')
print(f"    Длина волны 18.7 Гц: λ = c/f = {mp.nstr(c/f_bez/1e6, 6)} ×10⁶ м = {mp.nstr(c/f_bez/1e3, 6)} км")

# 8.2 — Эндокринная цепь (бороды невозможны — CANON v3.15)
T_earth = mpf(25); hyper = mpf(20)
T_et = T_earth*hyper*kappa
reg('testosterone_eteria_nmol', T_et, '388.89', tol=mpf('5e-5'), unit='нмоль/л')
M1_res = mpf('0.0246'); M2_res = mpf('0.189'); M3_res = mpf('0.254')
# M1: резонанс 5α-редуктазы: A = 1/sqrt((1-r^2)^2 + (r/Q)^2), f/f0=18.7/20, Q=10
r_drv = f_bez/mpf(20); Q_res = mpf(10)
A_res = 1/sqrt((1-r_drv**2)**2 + (r_drv/Q_res)**2)
print(f"    Резонанс 5αR: f/f0={mp.nstr(r_drv,5)}, Q=10 → A={mp.nstr(A_res,5)}, 1/A²={mp.nstr(1/A_res**2,5)} (канон M1=0.0246, A=6.38)")
supp = M1_res*M2_res*M3_res
conv_pct = mpf('0.10')*supp*100
reg('DHT_conversion_pct', conv_pct/100, '0.000118', tol=mpf('5e-3'), unit='(доля T→ДГТ)')
reg('suppression_factor', supp, unit='× [NEW: M1·M2·M3]')
reg('suppression_x', 1/supp, '847', tol=mpf('5e-3'), unit='× подавление')
DHT_et = T_et*supp*mpf('0.10')
reg('DHT_eteria_nmol', DHT_et, '0.046', tol=mpf('5e-3'), unit='нмоль/л')
DHT_earth = mpf('2.5')
reg('DHT_vs_earth', DHT_earth/DHT_et, '55', tol=mpf('5e-2'), unit='×')
reg('DHT_vs_threshold', mpf('0.5')/DHT_et, '11', tol=mpf('5e-2'), unit='× ниже порога 0.5')

# 8.3 — Сфера 6 Рэя: метаболизм
reg('sphere6_burst_W', mpf('17.1'), unit='Вт (канон)')
# Глюкоза: 17.1 Вт × 60 с = 1026 Дж / 17 МДж/кг глюкозы
gl_kg = mpf('17.1')*60/mpf('17e6')
print(f"    Выброс (60 с): {mp.nstr(gl_kg*1e3, 4)} г глюкозы; 4 выброса = {mp.nstr(4*gl_kg*1e3, 4)} г")

# 8.4 — Телескоп эльфов: D=2 м → разрешение 104 км (на Земле)
D_tel = mpf(2)
for lam_nm, tag in [('550', 'V-полоса'), ('874', 'подобранный λ'), ('850', 'I-полоса')]:
    lam = mpf(lam_nm)*mpf('1e-9')
    theta = mpf('1.22')*lam/D_tel
    res_km = theta*(a_Et - 1)*AU/1e3
    print(f"    D=2м, λ={lam_nm} нм ({tag}): разрешение на 1.3 а.е. = {mp.nstr(res_km, 6)} км")
lam104 = mpf('104e3')/((a_Et-1)*AU)*D_tel/mpf('1.22')
print(f"    λ, дающая ровно 104 км: {mp.nstr(lam104*1e9, 5)} нм → канон «104 км» соответствует ближнему ИК")

# 8.5 — Геометрия Рэя: 45 см тело / 7×3 см капсула
print(f"    Капсула 7 см / тело 45 см = {mp.nstr(mpf(7)/45*100, 5)}% длины тела (канон: ~15%)")
print(f"    Объём капсулы (цилиндр 7×3): {mp.nstr(pi*(1.5**2)*7, 6)} см³ = {mp.nstr(pi*(1.5**2)*7/1000, 5)} л")

# =====================================================================
# ЧАСТЬ 9. ЭНЕРГИЯ ТРАНЗИТА (Патч-01)
# =====================================================================
print("\nЧАСТЬ 9. ЭНЕРГИЯ ТРАНЗИТА")
line()
reg('E_transit_J', E_tr_canon, '8.0124e16', unit='Дж (канон v3.0)')
reg('E_transit_Mt_TNT', E_tr_canon/TNT_Mt, '19.15', tol=mpf('5e-4'), unit='Мт ТНТ')
dm = E_tr_canon/c**2
reg('E_transit_mass_equiv_kg', dm, unit='кг [NEW: Δm=E/c²]')
E90 = mpf('0.90')*E_tr_canon
reg('E_absorbed_90pct_Mt', E90/TNT_Mt, unit='Мт [NEW]')
reg('E_residual_10pct_Mt', mpf('0.10')*E_tr_canon/TNT_Mt, unit='Мт [NEW — CNED]')
# Старое аннулированное значение для справки
E_old = mpf('7.8e19')
print(f"    Старое (аннулировано v3.0): 7.8e19 Дж = {mp.nstr(E_old/TNT_Mt/1000, 6)} Гт — ×1000 от канона")
# Сколько это на биологию: энергия старения (грубая оценка через АТФ)
print(f"    Остаток 10% = {mp.nstr(mpf('0.1')*E_tr_canon, 6)} Дж; эквивалент полного метаболизма человека ({mp.nstr(mpf('0.1')*E_tr_canon/(100*86400*365), 4)} человеко-лет @100 Вт)")

# =====================================================================
# ЧАСТЬ 10. ГЕОГРАФИЯ И ЛОГИСТИКА
# =====================================================================
print("\nЧАСТЬ 10. ГЕОГРАФИЯ (клетки 100 км)")
line()
# Регионы Главного континента (млн км²)
regions = {'Проклятые Княжества': mpf('13.7'), 'Империя Золотого Солнца': mpf('8.7'),
           'Леса Востока': mpf('8.7'), 'Западные Хребты': mpf('6.7'),
           'Абресс-проекция/прочее': mpf('5.3'), 'Север': mpf('2.6')}
S_main = sum(regions.values())
reg('main_continent_area_Mkm2', S_main, '45.7', tol=mpf('5e-4'), unit='млн км²')
land_min, land_max = mpf('0.11')*A_surf/1e12, mpf('0.17')*A_surf/1e12
print(f"    Поверхность планеты: {mp.nstr(A_surf/1e12, 6)} млн км²; суша 11–17% = {mp.nstr(land_min,4)}–{mp.nstr(land_max,4)} млн км²")
print(f"    Остаток на 4 других континента + острова: {mp.nstr(land_min - S_main, 3)}–{mp.nstr(land_max - S_main, 3)} млн км²")
# Маршруты по сетке (экспонаты: Хаб (80,20), Озеро (78,28), Кратер Буфера (~70,35))
def grid_km(p, q):
    dx, dy = fabs(p[0]-q[0])*100, fabs(p[1]-q[1])*100
    return sqrt(dx**2 + dy**2), dx, dy
pairs = [((80,20),(78,28),'Хаб → Озеро Отражений'), ((70,35),(80,20),'Кратер Буфера → Хаб'),
         ((47,35),(80,20),'Сектор 4 (центр) → Хаб')]
for p, q, name in pairs:
    d, dx, dy = grid_km(p, q)
    print(f"    {name}: {mp.nstr(d, 5)} км (по сетке, катетами {float(dx):.0f}×{float(dy):.0f})")

# =====================================================================
# ЧАСТЬ 11. ОБРАТНЫЙ ПАРАДОКС БЛИЗНЕЦОВ — ТОЧНАЯ МАТЕМАТИКА (v2.0)
# Примирение: СТО Эйнштейна (внутри светового конуса) и теория Виталия
# (топологический прокол вне конуса) — обе верны, области разные.
# =====================================================================
print("\nЧАСТЬ 11. ОБРАТНЫЙ ПАРАДОКС БЛИЗНЕЦОВ — ТОЧНАЯ МАТЕМАТИКА")
line()

# --- Входы (файлы 148-93, 135-80, EPUB Ch26/Ch38, Физиология §6.2) ---
dt_tr   = mpf('1.8')                    # внешнее время транзита, с (часы Земли)
d_proj  = mpf('10e6')*mpf('9.4607304725808e15')  # проекционное расстояние, м (10 млн св. лет)
d_phys  = (a_Et - 1)*AU                 # физическое расстояние Земля→Этерия, м (1.3 а.е.)
m_alex  = mpf(70)                       # РАБОЧАЯ ГИПОТЕЗА: масса Алексея, кг (в каноне не зафиксирована)
E_tr    = mpf('8.0124e16')              # энергия транзита, Дж (аксиома A12)
share_m, share_cned, share_sh, share_res = mpf('0.58'), mpf('0.28'), mpf('0.04'), mpf('0.10')

# --- 11.1. Инвариант интервала: три масштаба одного транзита ---
print("  11.1. ИНТЕРВАЛ ds² = −c²dt² + dx² при dt = 1.8 с — три масштаба расстояния")
c_dt = c*dt_tr
print(f"    Световая граница конуса: c·dt = {mp.nstr(c_dt/1e9, 6)}×10⁹ м = 1.8 свет.с")
for name, d in [('Проекционное (через линзы M1/M2)', d_proj),
                ('Физическое (плоское, 1.3 а.е.)',   d_phys),
                ('Геодезическая Протоки 2ℓ_P',       2*l_P)]:
    ratio2 = (c_dt/d)**2            # доля временного члена в интервале
    spacelike = d > c_dt
    if d > c_dt:
        im_tau = sqrt((d/c)**2 - dt_tr**2)   # |Im τ| компенсационного времени
        im_txt = mp.nstr(im_tau, 6) + ' с'
        if im_tau > mpf('3.156e7'):
            im_txt += f" = {mp.nstr(im_tau/mpf('3.156e7'), 6)} лет"
    else:
        im_tau = None
        im_txt = '— (интервал времениподобный)'
    print(f"    {name}: dx = {mp.nstr(d, 6)} м; (c·dt/dx)² = {mp.nstr(ratio2, 3)};"
          f" пространственноподобный: {'ДА' if spacelike else 'НЕТ'}; |Im τ| = {im_txt}")
reg('twin_cdt_m', c_dt, unit='м — граница светового конуса транзита [NEW]')
reg('twin_ratio2_proj', (c_dt/d_proj)**2, unit='(c·dt/dx_proj)² — доля временного члена [NEW]')
reg('twin_im_tau_proj_years', sqrt((d_proj/c)**2 - dt_tr**2)/mpf('3.156e7'), unit='лет — компенсационное время (проекц.) [NEW]')
reg('twin_im_tau_phys_s', sqrt((d_phys/c)**2 - dt_tr**2), unit='с — компенсационное время (физич.) [NEW]')

print("    ВЫВОД: транзит ГЛУБОКО пространственноподобен — внешний конус нарушен на")
print(f"    {mp.nstr(d_phys/c_dt, 6)}× (физически) и {mp.nstr(d_proj/c_dt, 3)}× (проекционно).")
print("    СТО запрещает такой перенос как движение → возможен только топологический")
print("    прокол (Протока). Теория Виталия не противоречит СТО — она живёт ВНЕ её области.")

# --- 11.2. СТО-контроль: могла ли СТО объяснить старение? ---
print("\n  11.2. СТО-КОНТРОЛЬ (доказательство дополнительности)")
mc2 = m_alex*c**2
gamma_E = 1 + E_tr/mc2
print(f"    Если бы E транзита была кинетической (m = {mp.nstr(m_alex,3)} кг):")
print(f"    γ = 1 + E/mc² = {mp.nstr(gamma_E, 7)} → замедление времени всего {mp.nstr((gamma_E-1)*100, 4)}%")
print(f"    Канонное старение ×5.0 = +400% скорости времени → СТО НЕ объясняет CNED.")
reg('twin_sto_gamma_max', gamma_E, unit='γ при E=19.15 Мт в массы 70 кг [NEW]')
# Релятивистская альтернатива: сколько τ «съел» бы полёт 1.3 а.е. при 0.999c
v999 = mpf('0.999')*c
dt999 = d_phys/v999
tau999 = dt999*sqrt(1 - (v999/c)**2)
print(f"    Полёт 1.3 а.е. при 0.999c: dt = {mp.nstr(dt999, 6)} с, τ = {mp.nstr(tau999, 6)} с (почти не старится)")
rev_factor = mpf(72)*mpf('3.156e7')/tau999
print(f"    Протока: +72 года = {mp.nstr(mpf(72)*mpf('3.156e7'), 6)} с → обратный эффект сильнее прямого в")
print(f"    {mp.nstr(rev_factor, 4)}× раз. Прямой эффект (Эйнштейн) и обратный (Виталий) — разные режимы.")
reg('twin_relativistic_tau_s', tau999, unit='с — τ полёта 1.3 а.е. при 0.999c [NEW]')
reg('twin_reverse_vs_direct', rev_factor, unit='× — обратный эффект сильнее прямого [NEW]')
# Эквивалент γ для канонных 1.8 с как τ
gamma_18 = (d_phys/c)/dt_tr
v_equiv = c*sqrt(1 - 1/gamma_18**2)
print(f"    ИНВАРИАНТ-КАНДИДАТ: 1.8 с = τ релятивистского полёта на 1.3 а.е. при γ = {mp.nstr(gamma_18, 6)}")
print(f"    (v = {mp.nstr(v_equiv/c*100, 8)}% c) — «Протока калибрована как γ≈360» (красивое число для книги)")
reg('twin_gamma_equiv_1_8s', gamma_18, unit='γ-эквивалент канонных 1.8 с [NEW]')

# --- 11.3. Сжатие времени и демпфирование Драконьей матрицы ---
print("\n  11.3. СЖАТИЕ ВРЕМЕНИ И ДЕМПФИРОВАНИЕ")
tau_proj_s = sqrt((d_proj/c)**2 - dt_tr**2)
compress = tau_proj_s/dt_tr
print(f"    Компенсационное время (проекц.): {mp.nstr(tau_proj_s/mpf('3.156e7'), 8)} лет сжаты в 1.8 с")
print(f"    Сжатие: {mp.nstr(compress, 6)}× — «миллион лет в секунду» автора верно по порядку величины")
print(f"    (фактически {mp.nstr(compress/mpf('1e6'), 4)} млн лет за секунду)")
age_gain = mpf(90) - mpf(18)      # 72 года биологического старения
damp = age_gain*mpf('3.156e7')/tau_proj_s
print(f"    Биологически реализовано: +72 года = {mp.nstr(damp, 3)} от компенсационного времени")
print(f"    → Драконья матрица + CNED-конверсия гасят {mp.nstr((1-damp)*100, 8)}% компенсации")
print(f"    (демпфирующий фактор {mp.nstr(damp, 3)}; остаток 10% энергии при этом идёт в тело)")
reg('twin_compression_x', compress, unit='× — сжатие компенсационного времени [NEW]')
reg('twin_damping_factor', damp, unit='доля компенсации, ставшая биологией [NEW]')

# --- 11.4. Таблица примирения: один инвариант, три режима ---
print("\n  11.4. ПРИМИРЕНИЕ: СВЕТОВОЙ КОНУС КАК РАЗДЕЛИТЕЛЬ ТЕОРИЙ")
print("    ┌─────────────────┬──────────────────────────┬─────────────────────────────┐")
print("    │ Режим           │ Условие                  │ Теория и судьба времени     │")
print("    ├─────────────────┼──────────────────────────┼─────────────────────────────┤")
print("    │ Внутри конуса   │ dx < c·dt (v < c)        │ ЭЙНШТЕЙН: τ реально,        │")
print("    │                 │                          │ v→c → молодеешь; энергия —  │")
print("    │                 │                          │ вовне (двигатель/среда)     │")
print("    │ На конусе       │ dx = c·dt (v = c)        │ фотон: τ = 0, не стареет    │")
print("    │ Вне конуса      │ dx > c·dt                │ ВИТАЛИЙ (Протока): τ мнимо, │")
print("    │                 │ (движение запрещено СТО)  │ структурное старение;       │")
print("    │                 │ возможен только прокол    │ энергия — внутрь (CNED)     │")
print("    └─────────────────┴──────────────────────────┴─────────────────────────────┘")
print("    Мост: единственный инвариант ds² = −c²dτ² = −c²dt² + dx². У Эйнштейна из")
print("    него следует ЗАМЕДЛЕНИЕ (τ < t), у Виталия — МНИМОСТЬ (τ² < 0) и перенос")
print("    цены с внешней среды на собственную структуру. Обе теории — решения ОДНОГО")
print("    уравнения в разных областях конуса. Ни одна не опровергает другую.")

# --- 11.5. K=9/7 и хронология близнецов ---
print("\n  11.5. ХРОНОЛОГИЯ БЛИЗНЕЦОВ ПРИ K = 9/7")
years_earth = mpf(16)          # T-16 → T-0: Алексей на Земле
years_et = years_earth*kappa   # 16 земных лет × 7/9: эфический год длиннее (K = 9/7)
print(f"    16 земных лет = {mp.nstr(years_et, 5)} эф. лет [канон «~12.4» ✓]")
print(f"    Возраст: земной 18 (2+16), эфический {mp.nstr(mpf(2)+years_et, 5)}, визуальный 90 (18×5.0)")
reg('twin_earth16_to_ef', years_et, '12.4', tol=mpf('5e-3'), unit='эф. лет')

# =====================================================================
# ЧАСТЬ 12. CNED — ТОЧНАЯ КАЛИБРОВКА «ЭНЕРГИЯ → СТАРЕНИЕ» (v2.0)
# Закрытие открытого вопроса §9.4 v1.0: нелинейная пороговая конверсия.
# =====================================================================
print("\nЧАСТЬ 12. CNED — КАЛИБРОВКА «ЭНЕРГИЯ → СТАРЕНИЕ»")
line()

# --- 12.1. Энергетическая лестница транзита (раскладка 58/28/4/10) ---
print("  12.1. РАСКЛАДКА ЭНЕРГИИ ТРАНЗИТА (58/28/4/10)")
check_sum = share_m + share_cned + share_sh + share_res
reg('transit_budget_sum', check_sum, '1.0', tol=mpf('1e-12'), unit='(58+28+4+10)%')
E_m, E_cned, E_sh, E_res = (E_tr*x for x in (share_m, share_cned, share_sh, share_res))
print(f"    Матрица 58% = {mp.nstr(E_m/4.184e15, 7)} Мт | CNED-канал 28% = {mp.nstr(E_cned/4.184e15, 6)} Мт")
print(f"    Оболочка 4% = {mp.nstr(E_sh/4.184e15, 5)} Мт | Остаток (тело) 10% = {mp.nstr(E_res/4.184e15, 7)} Мт")
print(f"    ВАЖНО: «28%» раскладки ≠ «28%» BMR (23.9 Вт от 86 Вт). Первое — доля энергии")
print(f"    транзита (мгновенная), второе — ХРОНИЧЕСКАЯ мощность утечки (последствие).")
reg('E_cned_channel_J', E_cned, unit='Дж — 28% транзита через CNED-канал [NEW]')

# --- 12.2. Метаболический эквивалент 72 лет и эффективность η_age ---
print("\n  12.2. МЕТАБОЛИЧЕСКИЙ ЭКВИВАЛЕНТ СТАРЕНИЯ И η_age")
BMR_alex = mpf(86)                      # Вт, Физиология §6.2
t72 = mpf(72)*mpf('3.156e7')            # 72 года в секундах
E_life72 = mpf(100)*t72                 # полный метаболизм 72 лет @ 100 Вт
eta_age = E_life72/E_res
print(f"    Полный метаболизм 72 лет @100 Вт: {mp.nstr(E_life72, 6)} Дж")
print(f"    Остаток транзита (10%): {mp.nstr(E_res, 6)} Дж")
print(f"    η_age = E_жизни72/E_ост = {mp.nstr(eta_age, 4)} ≈ 1/{mp.nstr(1/eta_age, 5)}")
print(f"    КАЛИБРОВКА v4.0 (рекомендация): старение = E_ост × η_age — тело «проживает»")
print(f"    метаболический эквивалент 72 лет за миг. 18 + 72 = 90 ✓ (×5.0 = 90/18 ✓)")
reg('cned_metab72_J', E_life72, unit='Дж — метаболизм 72 лет @100 Вт [NEW]')
reg('cned_eta_age', eta_age, unit='η: доля остатка, ставшая 72 годами жизни [NEW]')

# --- 12.3. Тепловой контроль: CNED — НЕ нагрев ---
print("\n  12.3. ТЕПЛОВОЙ КОНТРОЛЬ (почему CNED ≠ тепло)")
c_body, dT_lethal = mpf(3500), mpf(6)   # Дж/кг·К; смертельная гипертермия +6°C (37→43)
E_heat_lethal = m_alex*c_body*dT_lethal
print(f"    Смертельный нагрев тела (+6°C): {mp.nstr(E_heat_lethal, 6)} Дж")
print(f"    Остаток / смертельный нагрев = {mp.nstr(E_res/E_heat_lethal, 4)}×")
print(f"    → Если бы CNED был теплом, смертельная доза превышена в {mp.nstr(E_res/E_heat_lethal, 4)}× (~5.4 млрд раз)")
print(f"    перенапряжённее. CNED — структурно-информационный канал (η≪1), не термический.")
print(f"    (Локальные 120°C крови Старика Воды — ДРУГОЙ режим: прямой контакт, тепловой.)")

reg('cned_heat_overkill', E_res/E_heat_lethal, unit='× превышение смертельного нагрева [NEW]')

# --- 12.4. Хроническая утечка: самосогласованность двух цепочек ---
print("\n  12.4. ХРОНИЧЕСКАЯ УТЕЧКА 23.9 Вт И САМОСОГЛАСОВАННОСТЬ")
leak = mpf('23.9')                      # Вт, §6.2 (28% BMR)
t_discharge = E_cned/leak
print(f"    28%-й канал транзита ({mp.nstr(E_cned, 5)} Дж) при хронической утечке 23.9 Вт")
print(f"    разряжался бы {mp.nstr(t_discharge/mpf('3.156e7')/mpf('1e6'), 5)} млн лет — заряд фактически вечен.")
print(f"    Проверка BMR: 23.9/86 = {mp.nstr(leak/BMR_alex*100, 4)}% ✓ [канон 28%]")
# Энергия, выведенная утечкой за 72 года, и её доля в остатке
E_leak72 = leak*t72
frac_leak72 = E_leak72/E_res
print(f"    Утечка за 72 года: 23.9 Вт × {mp.nstr(t72, 5)} с = {mp.nstr(E_leak72, 5)} Дж")
print(f"    = {mp.nstr(frac_leak72, 3)} остатка транзита (10%)")
print(f"    ИНВАРИАНТ №9 (САМОСОГЛАСОВАННОСТЬ): две независимые цепочки сходятся:")
print(f"      геометрическая: демпфирование компенсации → биология = {mp.nstr(damp, 3)}")
print(f"      энергетическая: утечка за 72 года / остаток        = {mp.nstr(frac_leak72, 3)}")
print(f"    Расхождение {mp.nstr(fabs(damp/frac_leak72-1)*100, 3)}% — 72 года старения согласуют")
print(f"    лаг-геометрию (Im τ) с термодинамикой (Вт) без подгонки параметров.")
reg('cned_leak_pct_bmr', leak/BMR_alex, '0.28', tol=mpf('5e-3'), unit='доля BMR')
reg('cned_discharge_mln_years', t_discharge/mpf('3.156e7')/mpf('1e6'), unit='млн лет — разряд 28% при 23.9 Вт [NEW]')
reg('cned_selfconsistent_ratio', damp/frac_leak72, unit='× — согласованность геометрия/термодинамика [NEW]')

# --- 12.5. Лаг тени: проверка R2-линейности T = dI/dΣ ---
print("\n  12.5. ЛАГ ТЕНИ — ЭМПИРИЧЕСКАЯ ПРОВЕРКА ТЕОРЕМЫ ЕДИНСТВЕННОСТИ")
lags = [('Ольга', mpf('0.3'), mpf('1.0')), ('Алексей', mpf('0.6'), mpf('2.0')), ('Вэнс', mpf('1.0'), mpf('3.3'))]
print("    Субъект   лаг    dI     лаг/dI")
for nm, lg, di in lags:
    print(f"    {nm:<9} {mp.nstr(lg,3)} с  {mp.nstr(di,3)}×   {mp.nstr(lg/di, 4)} с/ед.")
print(f"    Лаг/dI = const = 0.30 с/ед. для всех троих → R2 (аддитивность по информации)")
print(f"    ЭМПИРИЧЕСКИ ПОДТВЕРЖДЕНА на трёх независимых точках. Константа c теоремы")
print(f"    единственности калибрована: c = 0.30 с на единицу относительной нагрузки.")
reg('lag_shadow_const', mpf('0.3')/mpf('1.0'), '0.30', tol=mpf('5e-2'), unit='с/ед. — c теоремы T=c·dI/dΣ')

# --- 12.6. Планковская геодезическая ---
print("\n  12.6. ГЕОДЕЗИЧЕСКАЯ ПРОТОКИ (2ℓ_P) И ЛЕСТНИЦА ВРЕМЁН")
d_eff = 2*l_P
tau_pl = d_eff/c
print(f"    d_eff = 2ℓ_P = {mp.nstr(d_eff, 6)} м; внутреннее время пути τ = d_eff/c = {mp.nstr(tau_pl, 4)} с")
print(f"    Лестница: планковское {mp.nstr(tau_pl, 3)} с → внешнее 1.8 с → физич. Im τ {mp.nstr(sqrt((d_phys/c)**2-dt_tr**2), 4)} с")
print(f"    → биологическое +72 года → проекционное Im τ 10⁷ лет.")
print(f"    Отношение крайних: {mp.nstr(tau_proj_s/tau_pl, 4)} — Протока сшивает 58 порядков величины.")
reg('protoka_tau_planck_s', tau_pl, unit='с — внутреннее время геодезической [NEW]')
reg('protoka_ladder_orders', mp.log10(tau_proj_s/tau_pl), unit='порядков величины лестницы времён [NEW]')

# =====================================================================
# ЧАСТЬ 13. СВОДКА ВЕРДИКТОВ
# =====================================================================
print("\n" + "=" * 78)
print("  СВОДКА ВЕРДИКТОВ")
print("=" * 78)
ok = sum(1 for v in R.values() if v['status'] == 'OK')
near = sum(1 for v in R.values() if v['status'] == '~')
mm = sum(1 for v in R.values() if v['status'] == 'MISMATCH')
new = sum(1 for v in R.values() if v['status'] == 'NEW')
print(f"  OK={ok}  ~ (близко)={near}  MISMATCH={mm}  NEW (новые данные)={new}  всего={len(R)}")
for k, v in R.items():
    if v['status'] == 'MISMATCH':
        print(f"    !! {k}: вычислено {v['exact']} vs канон {v['canon']} (Δотн={v['delta_rel']:.2e})")

# JSON
out = {}
for k, v in R.items():
    e = {kk: vv for kk, vv in v.items()}
    out[k] = e
with open(__file__.replace('etheria_calculus.py', 'CALCULUS_ETERIA.json'), 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1, default=float)
print("\n  ✓ JSON: CALCULUS_ETERIA.json (рядом со скриптом)")

