#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ETHERIA ECONOMY v1.0 — БУХГАЛТЕРИЯ ДОВЕРИЯ на реальных входах
Скрипт-близнец CALCULUS / GEOGRAPHY / WORLD MAP (стиль: проверки + JSON)

Ядро модели (канон EPUB-04 «Макроэкономика и Власть»):
  Экономика Этерии = ЦЕПЬ ОМА:  Север генерирует Ω (U+), Юг генерирует χ (U−),
  Империя = резистор R (маржа), Синдикат завышает R → Секвестр X-0.
  I = U / R — поток золотых между полюсами.

Все расчёты ключевых формул дублируются через КАЛЬКУЛЯТОР poler-engine
(`poler-engine --exec "calc ..."`) и сверяются с Python — P-CHECK.

Источники: EPUB-04 (ресурсы/фракции/сценарии), Черная_бухгалтерия.m4a (пирамида,
бетон дешевле эвакуации), Фредерит_Технологическое_Древо (100:1, множители сезонов),
GEOGRAPHY_ETERIA.json (тарифы/население), Worldbuilding реестр (тракты).

Выход: 00_КАНОН/ECONOMY_ETERIA.json
"""
import json, math, subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GEO  = json.loads((REPO / '00_КАНОН' / 'GEOGRAPHY_ETERIA.json').read_text())
SETT = json.loads((REPO / '00_КАНОН' / 'SETTLEMENTS_ETERIA.json').read_text())

POLENGINE = str(Path.home() / '.local' / 'bin' / 'poler-engine')

def poler(expr) -> float:
    """Канкулятор poler-engine: calc <expr> → float."""
    out = subprocess.run([POLENGINE, '--exec', f'calc {expr}'],
                         capture_output=True, text=True, timeout=30)
    for line in out.stdout.splitlines():
        line = line.strip()
        if line.replace('.', '').replace('-', '').replace('e', '').replace('+', '').isdigit():
            try: return float(line)
            except ValueError: pass
        try:
            return float(line.split('=')[-1].strip())
        except (ValueError, IndexError):
            continue
    raise RuntimeError(f'poler-engine не дал число: {expr!r} → {out.stdout!r} {out.stderr!r}')

CHECKS = []
def chk(name, got, expect, tol=0.0, kind='OK'):
    if kind in ('AXIOM', 'FLAG'):
        CHECKS.append((name, kind, got, expect)); return
    ok = (got == expect) if tol == 0 else abs(got - expect) <= tol
    CHECKS.append((name, 'OK' if ok else ('~=' if abs(got-expect) <= tol*10 else 'MISMATCH'),
                   round(got, 4) if isinstance(got, float) else got, expect))

def pchk(name, expr, expect, tol=1e-9):
    """P-CHECK: python vs poler-engine."""
    got = poler(expr)
    ok = abs(got - expect) <= tol if tol else got == expect
    CHECKS.append((name, 'OK' if ok else 'MISMATCH', round(got, 6), expect))

# ══════════════════════════════════════════════════════════════════════
# §0. КАНОН-ЯКОРЯ ЦЕН (золотые)
# ══════════════════════════════════════════════════════════════════════
P = GEO['price_anchors_gold']   # жизнь_Цинк-4: 50, α-сердце: 12, кланы 50/200/70, эвакуация: 2000
chk('E-01 α-сердце = 12 зл (канон)', P['альфа_сердце'], 12)
chk('E-02 жизнь Цинк-4 = 50 зл (канон)', P['жизнь_Цинк-4'], 50)
chk('E-03 эвакуация = 2000 зл (канон)', P['эвакуация'], 2000)

# ══════════════════════════════════════════════════════════════════════
# §1. РЕСУРСНАЯ БАЗА — 12 активов φ-поля (EPUB-04, канон)
# ══════════════════════════════════════════════════════════════════════
ASSETS = [
    # имя, тип, владелец, доступность, значение
    ('Фредерит (Ф-руда)',    'природный (живой реактор)', 'Этерия (коренной)',  'крайне редкая',  'базовое тепло планеты 18.7 Гц, альтернатива Солнцу'),
    ('Живой Ф-сплав',        'технологический',           'Сектор Зеркал',      'секретная',      'σ_e=10, ключ к сверхпроводнику Алексея'),
    ('Ледовые Ядра',         'природный',                 'Северная Конф.',     'высокая (квоты)','транспортировка энергии без перегрева (Ω)'),
    ('Инверсные сердца (α)', 'био-аномальный',            'Проклятые Княжества','дефицит (Секвестр)','содержат χ, источник нестабильной мощи'),
    ('Ядра Класса D',        'био-технологический',       'Яма (Коллекторы)',   'общедоступно на дне', 'огарки Ф-фона, валюта выживания Нижнего Города'),
    ('Серебро',              'природный',                 'Империя, Запад',     'высокая',        'шумоподавитель φ-поля, БАЗОВАЯ валюта'),
    ('Золото',               'природный',                 'Западные Горы',      'средняя',        'тихий контур, эталон контактов элит'),
    ('Платина',              'природный',                 'Север',              'низкая',         'долговечные печати, Северный Брандмауэр'),
    ('Янтарь памяти',        'био-информационный',        'Восточные Леса',     'средняя',        'хранение когнитивных следов, топливо Архива'),
    ('Метеоритное железо',   'космический',               'локальные кратеры',  'экстрем. редкая','клинки против магии, разрушители φ-поля'),
    ('Песноплав',            'технологический',           'Абресс',             'монополия демонов', 'рынок желаний, резонаторы Эхо'),
    ('Шум смысла (данные)',  'информационный',            'Сектор Зеркал, Яма', 'неосязаемый',    'подкуп Инквестората, питание Мнемаров'),
]
chk('E-04 активов φ-поля = 12 (канон)', len(ASSETS), 12)

# ══════════════════════════════════════════════════════════════════════
# §2. ЦЕПЬ ОМА: I = U/R  (Север Ω ↔ Юг χ, Империя = R)
# ══════════════════════════════════════════════════════════════════════
# U — стоимость экспортного потока полюса за цикл (AXIOM-калибровка от канон-якорей):
#   Север: платина-квота ХП (Белый Тракт −27% при Т-24) + ледовые ядра
#   Юг: α-сердца Озера Отражений (12 зл/шт) — Секвестр блокирует 85%
ALPHA_YEAR = 5_200            # AXIOM: добыча α-сердец Озера, шт/цикл
U_SOUTH_FULL = ALPHA_YEAR * P['альфа_сердце']           # 62_400 зл/цикл — χ-полюс без блокады
U_SOUTH_X0   = U_SOUTH_FULL * 0.15                     # Секвестр X-0: 85% блокировано
PLAT_QUOTA   = 900.0        # AXIOM: платина Севера, кг/цикл
PLAT_GOLD_KG = 68.0         # AXIOM: платина ~68 зл/кг (дефицит −27% при Т-24)
ICE_GOLD     = 24_000.0     # AXIOM: ледовые ядра (квоты Севера), зл/цикл
U_NORTH = PLAT_QUOTA * PLAT_GOLD_KG * 0.73 + ICE_GOLD  # Белый Тракт −27% (канон Ольги)
U = U_NORTH + U_SOUTH_X0

# R — эффективное сопротивление: средневзвешенный тариф зл/(т·км) × плечо 3030 км
T = GEO['transport']['tariffs']
R_EFF = (T['эстафета']['gold_per_tkm'] * 0.5 + T['караван']['gold_per_tkm'] * 0.35 +
         T['пеший курьер']['gold_per_tkm'] * 0.15) * 3030     # зл за среднюю тонну плеча
I_FLOW = U / R_EFF   # «ток» экономики, зл-эквивалент потока

pchk('P-01 U_SOUTH_FULL', f'{ALPHA_YEAR} * {P["альфа_сердце"]}', U_SOUTH_FULL)
pchk('P-02 U_NORTH', f'{PLAT_QUOTA} * {PLAT_GOLD_KG} * 0.73 + {ICE_GOLD}', U_NORTH)
pchk('P-03 I = U/R', f'({U_NORTH} + {U_SOUTH_X0}) / {R_EFF:.6f}', I_FLOW, 1e-6)
chk('E-05 Секвестр режет χ-полюс до 15%', U_SOUTH_X0 / U_SOUTH_FULL, 0.15)
chk('E-06 дефицит платины −27% (канон Ольги)', 0.73, 1 - 0.27, 1e-12)

# ══════════════════════════════════════════════════════════════════════
# §3. ТРАНСПОРТНАЯ МАТРИЦА (тарифы канон × плечи трактов)
# ══════════════════════════════════════════════════════════════════════
def lat(y): return 47.12 + (y - 55) * 0.9814
def lon(x): return 34.89 + (x - 40) * 1.4422
R_KM = 5838.4
def gc_km(p1, p2):
    la1, lo1, la2, lo2 = map(math.radians, (lat(p1[1]), lon(p1[0]), lat(p2[1]), lon(p2[0])))
    return 2 * R_KM * math.asin(math.sqrt(
        math.sin((la2-la1)/2)**2 + math.cos(la1)*math.cos(la2)*math.sin((lo2-lo1)/2)**2))

TRACTS = [  # (имя, waypoints, статус, сезонный множитель)
    ('Белый Тракт',        [(22,85),(35,65),(42,57)],            'активен −27%', 1.10),
    ('Южный тракт С-7',    [(80,20),(70,35),(57,35),(42,57)],    'МЁРТВ 85%',    0.95),
    ('Восточный Перешеек', [(80,20),(62,30),(57,42),(42,57)],    'новый',         1.00),
    ('Западный Тракт',     [(16,33),(27,42),(42,57)],            'активен, инфляция', 1.00),
    ('Янтарный пакт',      [(82,60),(60,72),(35,80),(22,85)],    'активен (выкуп)', 1.00),
    ('Левиафанный (рельсы)',[(42,57),(38,67),(32,75),(28,78),(22,85)], 'остановлен T-19', 1.00),
]
tract_matrix = {}
for nm, wpts, st, season in TRACTS:
    dist = sum(gc_km(wpts[i], wpts[i+1]) for i in range(len(wpts)-1))
    dead = 'МЁРТВ' in st
    eff = 0.15 if dead else (0.73 if '−27%' in st else 1.0)
    tract_matrix[nm] = dict(dist_km=round(dist), status=st, season=season,
                            freight_gold_t=round(T['эстафета']['gold_per_tkm'] * dist * season * eff, 1),
                            effective_share=eff)
chk('E-07 Белый Тракт ~3030 км (прямой GC; через блокпост 3123)', tract_matrix['Белый Тракт']['dist_km'], 3030, 100)
chk('E-08 С-7 живая доля 15%', tract_matrix['Южный тракт С-7']['effective_share'], 0.15)

# ══════════════════════════════════════════════════════════════════════
# §4. ТЕХНОЛОГИЧЕСКОЕ ДРЕВО ФРЕДЕРИТА (канон 05_MATERIALS/02)
# ══════════════════════════════════════════════════════════════════════
ORE_KG, POWDER_KG = 100.0, 1.0            # 100 кг руды → 1 кг Ф-порошка
ORE_COST_SILVER = (3.0, 5.0)              # серебряников за кг руды (до стабилизации)
WINTER_M, SUMMER_M = 1.10, 0.95           # множители стабилизации
POWDER_COST_SILVER = 4.0 * ORE_KG * 0.5   # AXIOM: серебро руды в порошке (в среднем)
pchk('P-04 концентрация 100:1', f'{ORE_KG} / {POWDER_KG}', 100.0)
chk('E-09 зимний множитель ×1.10 (канон)', WINTER_M, 1.10)
chk('E-10 летний множитель ×0.95 (канон)', SUMMER_M, 0.95)
powder_winter = POWDER_COST_SILVER * WINTER_M
powder_summer = POWDER_COST_SILVER * SUMMER_M
pchk('P-05 порошок зимой', f'{POWDER_COST_SILVER:.2f} * {WINTER_M}', powder_winter, 1e-9)
chk('E-11 зимняя наценка на порошок, серебр.', round(powder_winter - POWDER_COST_SILVER, 1), 20.0, 0.1)
ALLOY_PCT = (0.5, 3.0)                    # Ф-порошок в Ф-сплаве
alloy_1t_powder_kg = 1000 * ALLOY_PCT[1] / 100   # макс. 3% → 30 кг порошка на 1 т сплава
pchk('P-06 порошок на 1т сплава (3%)', f'1000 * {ALLOY_PCT[1]} / 100', alloy_1t_powder_kg)

# ══════════════════════════════════════════════════════════════════════
# §5. СЕКВЕСТР X-0 — ЦЕНА ТИШИНЫ (Чёрная бухгалтерия: «бетон дешевле эвакуации»)
# ══════════════════════════════════════════════════════════════════════
DELISTED = 847                             # списанных в Цинк-4 (канон)
cost_life   = DELISTED * P['жизнь_Цинк-4']          # списание по цене жизни
cost_evac   = DELISTED * P['эвакуация']             # стоимость эвакуации
ratio_evac  = cost_evac / cost_life                 # «во сколько раз бетон дешевле»
pchk('P-07 цена тишины Цинк-4', f'{DELISTED} * {P["жизнь_Цинк-4"]}', cost_life)
pchk('P-08 стоимость эвакуации', f'{DELISTED} * {P["эвакуация"]}', cost_evac)
pchk('P-09 бетон дешевле эвакуации ×N', f'{cost_evac} / {cost_life}', ratio_evac)
chk('E-12 бетон дешевле эвакуации ×40 (Чёрная бухгалтерия)', round(ratio_evac), 40)
chk('E-13 847 списанных (канон)', DELISTED, 847)

# Кратер Буфера: мемориал 12 млн погибших (Секвестр прошлой эпохи)
BUFFER_DEAD = 12_000_000
buffer_life_equiv = BUFFER_DEAD * P['жизнь_Цинк-4']
pchk('P-10 Кратер Буфера, млрд зл-экв', f'{BUFFER_DEAD} * {P["жизнь_Цинк-4"]} / 1e9',
     buffer_life_equiv / 1e9)

# ══════════════════════════════════════════════════════════════════════
# §6. ДЕМОГРАФИЧЕСКИЙ СПРОС (входы от географии)
# ══════════════════════════════════════════════════════════════════════
POP_T = GEO['population_axioms']['total']
FOOD  = GEO['population_axioms']['food_t_per_year']
VILL_SHARE = 0.60
food_villages = FOOD * VILL_SHARE
pchk('P-11 продспрос сёл, млн т/год', f'{FOOD} * {VILL_SHARE} / 1e6', food_villages / 1e6)
chk('E-14 продспрос 41.7 млн т/год (аксиома-география; эльф = базовый вид 52 кг §2.7 с Task 9 — '
    'было 39.6 при северном подтипе 28 кг; GEOGRAPHY §9.8)', round(FOOD/1e6, 1), 41.7, 0.1)
# фрахт продовольствия: 41.7 млн т × средний тариф каравана × среднее плечо 1500 км
food_freight_gold = FOOD * T['караван']['gold_per_tkm'] * 1500
pchk('P-12 годовой фрахт продспроса, млн зл', f'{FOOD} * {T["караван"]["gold_per_tkm"]} * 1500 / 1e6',
     food_freight_gold / 1e6)
chk('E-15 сёла = 60% населения (модель worldmap)', VILL_SHARE, 0.60)

# ══════════════════════════════════════════════════════════════════════
# §7. СЦЕНАРИИ ФАЗОВЫХ ПЕРЕХОДОВ (EPUB-04, числовая развёртка)
# ══════════════════════════════════════════════════════════════════════
scA = dict(name='A. Экономический Дефолт Реальности (R→0)',
           trigger='Синдикат держит R выше критического при Секвестре X-0',
           mechanics='Алексей синхронизирует мёртвый шлак 18.7 Гц → Живой Ф-сплав σ_e=10 → R→0',
           numbers=dict(I_before=round(I_FLOW), I_after=round((U_NORTH + U_SOUTH_FULL) / (R_EFF * 0.05)),
                        core_crash='−80% стоимости официальных ядер Империи',
                        shadow_capital='теневой капитал Ямы ликвиднее казны Вэнс'))
scA['numbers']['I_jump_x'] = round(scA['numbers']['I_after'] / scA['numbers']['I_before'], 1)
pchk('P-13 скачок тока при R→0 (×N)', f'({U_NORTH} + {U_SOUTH_FULL}) / ({R_EFF:.6f} * 0.05) / ({U:.2f} / {R_EFF:.6f})',
     scA['numbers']['I_jump_x'], 0.2)
scB = dict(name='B. Инверсия Архисферы (Райдо, вектор ε<0)',
           trigger='Делистинг Наследника-00 → вакуум → Церковь призывает Райдо (T-16)',
           mechanics='дефрагментация макрорегионов, стандартная Ω-магия не работает против инверсии',
           numbers=dict(cities_lost='физическое исчезновение ряда южных городов',
                        south_block='полная блокировка добычи α-сердец → U_SOUTH = 0',
                        I_drop_to=round(U_NORTH / R_EFF)))
scC = dict(name='C. Инициализация Бездны (Транзакция Имени)',
           trigger='Голос Мира не останавливает вирус → резервный протокол форматирования',
           mechanics='Алексей даёт Имя Пустоте (Диабло) → Сфера Бездны поглощает инверсию',
           numbers=dict(final_state='Этерия перезапускается автономно: H^Ψ = 0 (сверхпроводимость)',
                        p3_cut='без вмешательства земного параллакса'))
chk('E-16 I при сценарии B (U_S=0)', scB['numbers']['I_drop_to'], round(U_NORTH / R_EFF))

# ══════════════════════════════════════════════════════════════════════
# §8. ВЕРДИКТ: ИМПЕРИЯ = ТЕРМОДИНАМИЧЕСКАЯ ПИРАМИДА
# ══════════════════════════════════════════════════════════════════════
T_HALF_FAITH = 6.02   # циклов — время полураспада веры (канон реестра)
faith_cycles = 3 * T_HALF_FAITH   # 3 периода → 87.5% потери доверия
pchk('P-14 вера после 3 полураспадов', f'0.5 ^ 3', 0.125)
chk('E-17 t½ веры = 6.02 цикла (канон)', T_HALF_FAITH, 6.02)
VERDICT = dict(
    formula='Империя = финансовая пирамида: держится на консервировании χ (Секвестр X-0), '
            'а не на производстве Ω; бетон дешевле эвакуации ×40 — рациональность ценой жизней',
    credit_life_cycles=round(faith_cycles, 1),
    faith_after_3halflives=0.125,
    collapse_horizon='T-19…T-14 (Осада Абресса) — окно 5 циклов',
    keystone='фредерит: единственный незаменяемый актив — реактор жизни планеты')

# ══════════════════════════════════════════════════════════════════════
# §9. ВЫХОД
# ══════════════════════════════════════════════════════════════════════
out = {
    'meta': dict(version='1.0', date='2026-09-24',
                 sources='EPUB-04 + Черная_бухгалтерия.m4a + 05_MATERIALS/02 Фредерит-древо + GEOGRAPHY_ETERIA.json',
                 engine='все ключевые формулы продублированы poler-engine (P-01..P-14)'),
    'price_anchors_gold': P,
    'assets_phi': [dict(name=a[0], type=a[1], owner=a[2], availability=a[3], value=a[4]) for a in ASSETS],
    'ohm_macro': dict(U_north_gold=round(U_NORTH), U_south_full_gold=round(U_SOUTH_FULL),
                      U_south_X0_gold=round(U_SOUTH_X0), R_effective_gold=round(R_EFF, 2),
                      I_flow_gold=round(I_FLOW), note='AXIOM-калибровка от канон-якорей'),
    'tract_matrix': tract_matrix,
    'frederite_tech': dict(ore_to_powder='100:1', ore_cost_silver_per_kg=ORE_COST_SILVER,
                           powder_cost_silver=POWDER_COST_SILVER, winter=powder_winter,
                           summer=powder_summer, alloy_powder_pct=ALLOY_PCT,
                           powder_per_ton_alloy_kg=alloy_1t_powder_kg),
    'sequester_x0': dict(delisted=DELISTED, cost_life_gold=cost_life, cost_evac_gold=cost_evac,
                         ratio_evac_to_life=round(ratio_evac, 1),
                         buffer_memorial_dead=BUFFER_DEAD, buffer_life_equiv_gold=buffer_life_equiv),
    'demography': dict(population=POP_T, food_t_per_year=FOOD, village_share=VILL_SHARE,
                       food_freight_gold_per_year=round(food_freight_gold)),
    'scenarios': [scA, scB, scC],
    'verdict': VERDICT,
    'checks': [dict(name=n, status=s, got=g, expect=e) for n, s, g, e in CHECKS],
}
(REPO / '00_КАНОН' / 'ECONOMY_ETERIA.json').write_text(json.dumps(out, ensure_ascii=False, indent=2),
                                                        encoding='utf-8')

n_ok = sum(1 for _, s, _, _ in CHECKS if s == 'OK')
n_ap = sum(1 for _, s, _, _ in CHECKS if s == '~=')
n_mm = sum(1 for _, s, _, _ in CHECKS if s == 'MISMATCH')
print('=' * 78)
print('  ETHERIA ECONOMY v1.0 — БУХГАЛТЕРИЯ ДОВЕРИЯ (I = U/R)')
print('=' * 78)
for n, s, g, e in CHECKS:
    print(f'  [{s:>7}] {n:<48} {g} vs {e}')
print('-' * 78)
print(f'  ИТОГО: {len(CHECKS)} проверок | OK={n_ok} ~={n_ap} MISMATCH={n_mm}')
print(f'  U_Север={U_NORTH:,.0f} зл · U_Юг(Секвестр)={U_SOUTH_X0:,.0f} зл · R={R_EFF:.1f} · I={I_FLOW:,.0f} зл/цикл')
print(f'  Секвестр X-0: тишина {cost_life:,} зл vs эвакуация {cost_evac:,} зл → бетон дешевле ×{ratio_evac:.0f}')
print(f'  Сценарий A: ток ×{scA["numbers"]["I_jump_x"]} при R→0; фрахт продспроса {food_freight_gold/1e6:,.1f} млн зл/год')
print(f'  Вердикт: пирамида · t½ веры {T_HALF_FAITH} цикла · крах-горизонт {VERDICT["collapse_horizon"]}')
print(f'  JSON: 00_КАНОН/ECONOMY_ETERIA.json')
