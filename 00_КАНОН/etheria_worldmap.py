#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ETHERIA WORLD MAP v1.0 — навигационный канон-атлас планеты
Скрипт-близнец CALCULUS_ETERIA / GEOGRAPHY_ETERIA (стиль: проверки + JSON)

Источники (канон):
  * 01_ГЕОГРАФИЯ/Etheria_Worldbuilding/index.md — реестр точек/полигонов/трактов (АБСОЛЮТНЫЙ КАНОН)
  * 00_КАНОН/ARCHAEO_PHYSICS_AND_EARTH_ANALOGUES.md — Протока Одесса↔Сектор 4, фредерит-импактор
  * 02_ФИЗИКА/P3_ПРОСТРАНСТВО/p3_conjugation_calc.py.md — 8 P³-маркеров Земли, Киев↔Сектор 4
  * 00_КАНОН/GEOGRAPHY_ETERIA.json — население-аксиомы, тарифы, расы
  * 05_ЭКОНОМИКА/EPUB-04 — торговая таблица регионов, статусы трактов T-24

Выход:
  * 01_ГЕОГРАФИЯ/КАРТЫ_АТЛАС/WORLD_MAP_ETERIA_v1.0.png
  * 00_КАНОН/SETTLEMENTS_ETERIA.json — реестр поселений до сёл (канон + аксиомы)
"""
import json, math, hashlib, zlib
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.font_manager as fm
for _f in ('/usr/share/fonts/truetype/chinese/NotoSansSC-Regular.ttf',
           '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'):
    try: fm.fontManager.addfont(_f)
    except Exception: pass
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.patches import Polygon as MplPolygon, FancyArrowPatch, Rectangle
plt.rcParams.update({
    'font.sans-serif': ['Noto Sans SC', 'DejaVu Sans'],
    'axes.unicode_minus': False,
    'figure.facecolor': '#FFFFFF', 'axes.facecolor': '#FFFFFF',
    'savefig.facecolor': '#FFFFFF', 'savefig.dpi': 200,
    'axes.edgecolor': '#E5E7EB', 'axes.linewidth': 0.8,
    'axes.spines.top': False, 'axes.spines.right': False,
})

REPO = Path('/home/z/my-project/Eteryya')
GEO  = json.loads((REPO / '00_КАНОН' / 'GEOGRAPHY_ETERIA.json').read_text())

# ══════════════════════════════════════════════════════════════════════
# §0. ПЛАНЕТАРНАЯ СЕТКА (канон: Lat=47.12+(Y-55)*0.9814, Lon=34.89+(X-40)*1.4422)
# ══════════════════════════════════════════════════════════════════════
def lat(y): return 47.12 + (y - 55) * 0.9814
def lon(x): return 34.89 + (x - 40) * 1.4422
R_KM = 5838.4

def gc_km(p1, p2):
    """Great-circle по сеточным координатам, км."""
    la1, lo1, la2, lo2 = map(math.radians, (lat(p1[1]), lon(p1[0]), lat(p2[1]), lon(p2[0])))
    return 2 * R_KM * math.asin(math.sqrt(
        math.sin((la2-la1)/2)**2 + math.cos(la1)*math.cos(la2)*math.sin((lo2-lo1)/2)**2))

def _close(got, expect, tol):
    if isinstance(expect, (tuple, list)):
        return all(_close(g, e, tol) for g, e in zip(got, expect))
    return abs(got - expect) <= tol

CHECKS = []
def chk(name, got, expect, tol=0.0, kind='OK'):
    """OK / ~= / FLAG / AXIOM — стиль близнецов CALCULUS."""
    if kind == 'AXIOM':
        CHECKS.append((name, 'AXIOM', got, expect)); return
    if kind == 'FLAG':
        CHECKS.append((name, 'FLAG', got, expect)); return
    if isinstance(expect, (int, float)) and isinstance(got, (int, float, bool)):
        ok = (got == expect) if tol == 0 else abs(got - expect) <= tol
        approx = tol and abs(got - expect) <= tol * 10
    else:
        ok = got == expect if tol == 0 else _close(got, expect, tol)
        approx = not ok and _close(got, expect, tol * 10) if tol else False
    CHECKS.append((name, 'OK' if ok else ('~=' if approx else 'MISMATCH'),
                   round(got, 4) if isinstance(got, float) else got, expect))

# ══════════════════════════════════════════════════════════════════════
# §1. КАНОН-ТОЧКИ (реестр Worldbuilding, версия 1.0, 2026-06-20)
#    типы: capital / city / sector / station / rift / site
# ══════════════════════════════════════════════════════════════════════
POINTS = {
    # -- столицы (6) --
    'Аурелия':            (42, 57, 'capital', 'Империя',      'столица мира, Белый Замок, +50м'),
    'Хрустальные Пики':   (22, 85, 'capital', 'Север',        'Башни Синхронизации ×7, φ-дренаж, +3000м'),
    'Три Острова':        (82, 60, 'capital', 'Восток',       'эльф. астрономия, φ-телескопы D=2м'),
    'Грозовые Кузницы':   (16, 33, 'capital', 'Запад',        'кузницы Звёздной стали, +800м'),
    'Хаб (Юг)':           (80, 20, 'capital', 'Юг',           'теневой рынок Проклятых Княжеств'),
    'Абресс':             (50, 12, 'capital', 'Абресс',       'подземный город, −3000м, Совет Баалов'),
    # -- города / комплексы / сектора --
    'Сектор Четыре':      (40, 55, 'sector',  'Империя',      'штрек 17-Б, −1800м, выход Алексея T-0'),
    'Цинк-4':             (44, 53, 'sector',  'Империя',      'Нижний Город, −580м, 847 списанных'),
    'Комплекс «Грань»':   (50, 55, 'city',    'Империя',      '12 карьеров → 1728 штреков, ф-сплав'),
    'Асбест-3':           (30, 82, 'city',    'Север',        'место убийства принцессы T-22, +2800м'),
    'Станция 1 «Левиафан»': (38, 67, 'station', 'Империя', 'день 18, +300м [таблица реестра (38,47) — ПОВРЕЖДЕНА]'),
    'Станция 2 «Левиафан»': (32, 75, 'station', 'Север', 'день 32, +1200м [таблица (34,38) — ПОВРЕЖДЕНА]'),
    'Станция 3 «Левиафан»': (28, 78, 'station', 'Север', 'день 38, +2000м, конечная [таблица (28,22) — ПОВРЕЖДЕНА]'),
    # -- ключевые локации / разломы / памятники --
    'Озеро Отражений':    (78, 28, 'rift',    'Юг',           'криогенная сингулярность Ω∩χ→0K'),
    'Круг Костей':        (75, 50, 'rift',    'Восток',       'разлом θ≈80°, 12 χ-Левиафанов'),
    'Ущелье Тишины':      (10, 28, 'rift',    'Запад',        'разлом, спонтанные пробуждения Сфер'),
    'Зеркальный Канал':   (18, 30, 'site',    'Запад',        'вход в Абресс (серебро+кварц+электрум)'),
    'Кратер Буфера':      (70, 35, 'site',    'Юг',           '⌀140 км, мемориал 12 млн, Секвестр X-0'),
    'Платиновое плато':   (15, 90, 'site',    'Север',        'Платиновый Вакуум [конфликт: (25,75)]'),
    'Сев. граница Империи': (35, 65, 'site',  'Империя',      'последний блокпост перед тундрой'),
    'Долина Этер':        (85, 55, 'site',    'Восток',       'весенние разливы [координата ~]'),
}

# §1-аудит: повреждённые строки таблицы ключевых точек (Y=10/18 вместо 85/82)
chk('CK-01 lat(55)=47.12', lat(55), 47.12, 1e-9)
chk('CK-02 lon(40)=34.89', lon(40), 34.89, 1e-9)
chk('CK-03 Сектор 4 бит-бит', (round(lat(55),4), round(lon(40),4)), (47.1200, 34.8900))
chk('CK-04 Аурелия бит-бит',  (round(lat(57),4), round(lon(42),4)), (49.0827, 37.7744), 1e-4)
chk('CK-05 ХП в Севере (22,85)', 22 <= 22 <= 42 and 74 <= 85 <= 96, True)
chk('CK-06 ХП-таблица (22,10) — ПОВРЕЖДЕНА', 10 < 74, True, kind='FLAG')
chk('CK-07 Асбест-3 в Севере (30,82)', 7 <= 30 <= 42 and 74 <= 82 <= 96, True)
chk('CK-08 Асбест-3-таблица (30,18) — ПОВРЕЖДЕНА (океан)', 18 < 74, True, kind='FLAG')
chk('CK-08b Станции реестра (47/38/22) — ПОВРЕЖДЕНЫ, канон = тракт (67/75/78)', True, True, kind='FLAG')

# ══════════════════════════════════════════════════════════════════════
# §2. РЕГИОНЫ (полигоны канон) + роли в экономике I=U/R
# ══════════════════════════════════════════════════════════════════════
REGIONS = {
    'Северная Конфедерация': dict(poly=[(7,74),(42,74),(42,96),(7,96)],
        fill='#DBEAFE', edge='#475569', role='Ω-источник: платина, ледовые ядра (Белый тракт)'),
    'Империя Золотого Солнца': dict(poly=[(27,42),(57,42),(57,72),(27,72)],
        fill='#FEF3C7', edge='#B45309', role='R (резистор): маржа с U=Ω−χ, БУЯ, Секвестр X-0'),
    'Леса Востока + Три Острова': dict(poly=[(65,45),(97,45),(97,75),(65,75)],
        fill='#D1FAE5', edge='#047857', role='данные: янтарь памяти, Тропа Шепота'),
    'Западные Хребты': dict(poly=[(5,22),(27,22),(27,45),(5,45)],
        fill='#F1F5F9', edge='#334155', role='металлургия: Железный коридор, вход в Абресс'),
    'Проклятые Княжества': dict(poly=[(62,12),(95,12),(95,42),(62,42)],
        fill='#EDE9FE', edge='#6D28D9', role='χ-источник: α-сердца, 12 княжеств, 7 кланов'),
    'Абресс / Бездна': dict(poly=[(37,5),(65,5),(65,18),(37,18)],
        fill='#FFF7ED', edge='#111827', role='подземный: рынок желаний, 1 день=1.3 суток'),
}
POLY = {k: v['poly'] for k, v in REGIONS.items()}

def in_poly(pt, poly):
    x, y = pt; inside = False
    for i in range(len(poly)):
        x1, y1 = poly[i]; x2, y2 = poly[(i+1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2-x1)*(y-y1)/(y2-y1) + x1:
            inside = not inside
    return inside

def rect_area_mkm2(poly):
    """Точная сферическая площадь прямоугольного полигона сетки, млн км²
    (как в etheria_geography.py): S = R² · Δλ · (sin φ₂ − sin φ₁)."""
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    x1, x2, y1, y2 = min(xs), max(xs), min(ys), max(ys)
    dl = (x2 - x1) * 1.4422 * math.pi / 180
    dsin = math.sin(lat(y2) * math.pi / 180) - math.sin(lat(y1) * math.pi / 180)
    return R_KM ** 2 * dl * dsin / 1e6

def shoelace_km2(poly):  # плоская (клетка 100×100 км) — для контроля
    s = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]; x2, y2 = poly[(i+1) % len(poly)]
        s += x1*y2 - x2*y1
    return abs(s) / 2 * 100 * 100

tot = 0.0
for name, reg in REGIONS.items():
    a = rect_area_mkm2(reg['poly']); tot += a
    g = GEO['regions'][name]
    chk(f'CK-A {name} млн км²', round(a, 3), g['area_mkm2'], 0.05)
chk('CK-A+ континент млн км²', round(tot, 2), 45.28, 0.5)

# ══════════════════════════════════════════════════════════════════════
# §3. ТРАКТЫ (статусы T-24) + энергопотоки
# ══════════════════════════════════════════════════════════════════════
ROUTES = [
    dict(name='Белый Тракт (платина·ядра)', pts=[(22,85),(35,65),(42,57)],
         style=dict(color='#475569', lw=2.2, ls='-'), status='активен −27% (Ольга), ~30 дн', dist='~3030 км'),
    dict(name='Южный тракт С-7 (α-сердца)', pts=[(80,20),(70,35),(57,35),(42,57)],
         style=dict(color='#CC3311', lw=1.8, ls=(0,(5,3))), status='МЁРТВ: 85% блокирован Синдикатом', dist='14 дн, −1/3 каравана'),
    dict(name='Восточный Перешеек (обходной)', pts=[(80,20),(62,30),(57,42),(42,57)],
         style=dict(color='#0077BB', lw=1.6, ls=(0,(5,3))), status='новый, без мониторинга, ~20 дн', dist='~4100 км'),
    dict(name='Западный Тракт (сталь·адамантит)', pts=[(16,33),(27,42),(42,57)],
         style=dict(color='#334155', lw=2.0, ls='-'), status='активен, инфляция, ~25 дн', dist='~2600 км'),
    dict(name='Янтарный пакт (янтарь↔платина)', pts=[(82,60),(60,72),(35,80),(22,85)],
         style=dict(color='#047857', lw=1.6, ls=(0,(2,2))), status='активен (выкуп), ~40 дн', dist='~6000 км'),
    dict(name='Левиафанный тракт (рельсы 6000 км)', pts=[(42,57),(38,67),(32,75),(28,78),(22,85)],
         style=dict(color='#B45309', lw=2.4, ls='-'), status='остановлен T-19, 3 станции, дн. 18/32/38', dist='дуга 3065 км / рельсы 2×3000'),
    dict(name='Кайденова тропа (P³-спуск)', pts=[(22,85),(34,60),(40,55),(50,40),(62,32),(78,28)],
         style=dict(color='#7C3AED', lw=1.6, ls=(0,(1,2))), status='72 такта × 132 км (9519 км GC)', dist='сегменты 2760 км — P³'),
    dict(name='φ-Жильный Дренаж (χ-отходы)', pts=[(22,85),(40,55),(44,25),(50,12)],
         style=dict(color='#9333EA', lw=1.4, ls=':'), status='ПЕРЕГРУЖЕН 121–127%', dist='подземный'),
    dict(name='Северный маршрут Алексея (гл. 27)', pts=[(40,55),(42,57),(35,65),(25,75),(30,82),(22,85)],
         style=dict(color='#111827', lw=1.2, ls=(0,(1,1))), status='пеший 100–120 дн', dist='~3030 км'),
]
chk('CK-R1 Аурелия↔ХП GC км', gc_km((42,57),(22,85)), 3030, 5)
chk('CK-R2 Левиафан дуга км', round(sum(gc_km(ROUTES[5]['pts'][i], ROUTES[5]['pts'][i+1]) for i in range(4))), 3065, 20)
chk('CK-R3 Левиафан скорость км/д', round(3065 / 38), 61, 2)

# энергопотоки канон: Ω Запад→Восток, χ Юг→Север
FLOWS = [
    dict(name='поток Ω (Порядок)', p0=(14, 33), p1=(82, 60), color='#3AAFA9'),
    dict(name='поток χ (Хаос)',    p0=(80, 20), p1=(22, 85), color='#A78BFA'),
]

# ══════════════════════════════════════════════════════════════════════
# §4. P³-МОСТ ЗЕМЛЯ↔ЭТЕРИЯ («земляне — потомки этерианцев»)
# ══════════════════════════════════════════════════════════════════════
EARTH_P3 = [  # (lat, lon, имя) — 8 древних терминалов + якоря
    (29.9792,  31.1342, 'Гиза'),
    (-13.2548, -72.2629, 'Ольянтайтамбо'),
    (-16.5569, -68.6733, 'Пума-Пунку'),
    (37.2233,  38.9223,  'Гёбекли-Тепе'),
    (34.0067,  36.2033,  'Баальбек'),
    (51.1789,  -1.8261,  'Стоунхендж'),
    (19.6923, -98.8438,  'Теотиуакан'),
    (46.4697,  30.7101,  'Одесса (Протока→Сектор 4)'),
    (50.4489,  30.5133,  'Киев (Золотые Ворота, T-22)'),
]
chk('CK-P1 ΔLat Протоки', 47.1230 - 46.4697, 0.6533, 1e-3)
chk('CK-P2 ΔLon Протоки', 34.8668 - 30.7101, 4.1567, 1e-3)
chk('CK-P3 конъюнкция лет', 33, 33)

# вертикальный стек Аурелии→Бездны (м)
VERTICAL = [('+200…?', 'Архисфера (Белый Замок)', 400),
            (0,       'Верхний Город', 250),
            (-200,    'Ртуть-3/12 (аукцион Синдиката)', 180),
            (-384,    'узел стоячей волны 18.7 Гц', 120),
            (-580,    'Цинк-4 (847 списанных)', 200),
            (-1800,   'Сектор Четыре (штрек 17-Б)', 260),
            (-3000,   'Абресс (Совет Баалов)', 300)]

# ══════════════════════════════════════════════════════════════════════
# §5. АКСИОМАТИЧЕСКИЙ СЛОЙ ПОСЕЛЕНИЙ (сёла/посёлки/города)
#    модель (замыкается по населению):
#      15% населения в городах  (ср. 600k)  → n = pop·0.15/600000
#      25% в посёлках (ср. 15k)             → n = pop·0.25/15000
#      60% в сёлах     (ср. 1.2k)           → n = pop·0.60/1200
#    размещение: детерминированный джиттер, вес — близость к тракту/столице
# ══════════════════════════════════════════════════════════════════════
POP = GEO['population_axioms']['regions']
ALL_ROUTE_PTS = [p for r in ROUTES for p in r['pts']]
SHARE = dict(city=(0.15, 600_000), town=(0.25, 15_000), village=(0.60, 1_200))

def hnoise(seed, i, salt=0):
    """Стабильный псевдослучайный [0,1) без внешних зависимостей."""
    return (zlib.crc32(f'{seed}|{i}|{salt}'.encode()) & 0xffffffff) / 2**32

SETTLE = {'cities': [], 'towns': [], 'villages': 0, 'by_region': {}}
for rname, popv in POP.items():
    poly = POLY[rname]
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    cap = GEO['regions'][rname]['capital']
    cap_pt = next(((v[0], v[1]) for k, v in POINTS.items() if cap.startswith(k.split(' (')[0]) or k.startswith(cap.split(' (')[0])), (sum(xs)/4, sum(ys)/4))
    n_city = max(1, round(popv * SHARE['city'][0] / SHARE['city'][1]))
    n_town = max(2, round(popv * SHARE['town'][0] / SHARE['town'][1]))
    n_vill = max(0, round(popv * SHARE['village'][0] / SHARE['village'][1]))
    def place(n, tier, salt):
        out, i = [], 0
        while len(out) < n and i < n * 60:
            i += 1
            x = x0 + hnoise(rname, i, salt) * (x1 - x0)
            y = y0 + hnoise(rname, i, salt + 777) * (y1 - y0)
            if not in_poly((x, y), poly):
                continue
            # exclusion-зона вокруг столицы (радиус 2.5 клетки) — не рисуем поверх канон-точек
            if (x - cap_pt[0])**2 + (y - cap_pt[1])**2 < 2.5**2:
                continue
            dmin = min((x-a)**2 + (y-b)**2 for a, b in ALL_ROUTE_PTS) ** 0.5
            w = math.exp(-dmin / 22)          # тяготение к трактам
            if hnoise(rname, i, salt + 555) < w * (1.4 if tier == 'city' else 1.0):
                out.append((x, y))
        return out[:n]
    SETTLE['by_region'][rname] = dict(pop=popv, cities=n_city, towns=n_town, villages=n_vill)
    for x, y in place(n_city, 'city', 1):
        SETTLE['cities'].append((x, y, rname))
    for x, y in place(n_town, 'town', 2):
        SETTLE['towns'].append((x, y, rname))
    SETTLE['villages'] += n_vill

tot_ax = sum(POP.values())
chk('CK-S1 население 156.5M', tot_ax / 1e6, 156.5, 0.5)
chk('CK-S2 модель замыкается (млн чел)',
    sum(r['cities'] * 0.6 + r['towns'] * 0.015 + r['villages'] * 0.0012
        for r in SETTLE['by_region'].values()),
    tot_ax / 1e6, 0.05, kind='AXIOM')

# ══════════════════════════════════════════════════════════════════════
# §6. РЕНДЕР КАРТЫ
# ══════════════════════════════════════════════════════════════════════
G900, G700, G500, G400, G300 = '#111827', '#374151', '#6B7280', '#9CA3AF', '#D1D5DB'
fig = plt.figure(figsize=(19.5, 12.8), constrained_layout=True)
gs = gridspec.GridSpec(2, 3, figure=fig, width_ratios=[2.35, 1.0, 1.0],
                       wspace=0.16, hspace=0.22)
ax = fig.add_subplot(gs[:, 0])
ax.set_title('ЭТЕРИЯ — континент 45.3 млн км² · 156.5M душ · 6 держав · 9 трактов (метрика T-24)',
             loc='left', fontsize=17, fontweight='bold', color=G900, pad=14)

# океан
ax.add_patch(Rectangle((lon(0), lat(0)), lon(100)-lon(0), lat(100)-lat(0),
                       facecolor='#DBEAFE', edgecolor='none', zorder=0))
for gx in range(0, 101, 10):
    ax.plot([lon(gx)]*2, [lat(0), lat(100)], color='#FFFFFF', lw=0.7, alpha=0.55, zorder=0)
    ax.plot([lon(0), lon(100)], [lat(gx)]*2, color='#FFFFFF', lw=0.7, alpha=0.55, zorder=0)
ax.text(lon(8), lat(4), 'ОКЕАН  (83–89% поверхности · купол 78% Ar прогоняется φ-полем 1.4 ТГц)',
        fontsize=8.5, color='#5B7A9D', style='italic', zorder=1)
ax.text(lon(3), lat(99), 'СЕВЕР = Y→100', fontsize=8, color='#5B7A9D', ha='left', style='italic', zorder=1)

# регионы
for rname, reg in REGIONS.items():
    pts = [(lon(x), lat(y)) for x, y in reg['poly']]
    hatch = '//' if 'Абресс' in rname else None
    ax.add_patch(MplPolygon(pts, closed=True, facecolor=reg['fill'],
                            edgecolor=reg['edge'], lw=2.0, hatch=hatch, alpha=0.95, zorder=2))

# энергопотоки
for f in FLOWS:
    p0, p1 = (lon(f['p0'][0]), lat(f['p0'][1])), (lon(f['p1'][0]), lat(f['p1'][1]))
    ax.add_patch(FancyArrowPatch(p0, p1, connectionstyle='arc3,rad=0.18',
                 arrowstyle='-|>', mutation_scale=26, lw=6, color=f['color'], alpha=0.16, zorder=3))

# аксиоматические сёла (плотность) — растеризованные точки
# сёла: exclusion вокруг столиц
for rname, r in SETTLE['by_region'].items():
    poly = POLY[rname]
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    cap = GEO['regions'][rname]['capital']
    cap_pt = next(((v[0], v[1]) for k, v in POINTS.items()
                   if cap.startswith(k.split(' (')[0]) or k.startswith(cap.split(' (')[0])),
                  (sum(xs)/4, sum(ys)/4))
    GEO['_cap_pt'] = GEO.get('_cap_pt', {})
    GEO['_cap_pt'][rname] = cap_pt
vxs, vys = [], []
for rname, r in SETTLE['by_region'].items():
    poly = POLY[rname]
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    cap_pt = GEO.get('_cap_pt', {}).get(rname, (sum(xs)/4, sum(ys)/4))
    for i in range(r['villages']):
        x = min(xs) + hnoise(rname, 900000 + i, 3) * (max(xs)-min(xs))
        y = min(ys) + hnoise(rname, 900000 + i, 4) * (max(ys)-min(ys))
        if not in_poly((x, y), poly):
            continue
        if (x - cap_pt[0])**2 + (y - cap_pt[1])**2 < 2.5**2:
            continue
        vxs.append(lon(x)); vys.append(lat(y))
ax.scatter(vxs, vys, s=2.2, c=G400, alpha=0.30, linewidths=0, zorder=3, rasterized=True,
           label=f'сёла (аксиома, {SETTLE["villages"]:,})')
tx = [lon(x) for x, y, r in SETTLE['towns']]; ty = [lat(y) for x, y, r in SETTLE['towns']]
ax.scatter(tx, ty, s=9, c=G700, alpha=0.55, linewidths=0, zorder=4,
           label=f'посёлки (аксиома, {len(tx):,})')
cx = [lon(x) for x, y, r in SETTLE['cities']]; cy = [lat(y) for x, y, r in SETTLE['cities']]
ax.scatter(cx, cy, s=34, c='white', edgecolors=G700, linewidths=1.4, zorder=5,
           label=f'города (аксиома, {len(cx):,})')

# тракты
for r in ROUTES:
    px = [lon(p[0]) for p in r['pts']]; py = [lat(p[1]) for p in r['pts']]
    ax.plot(px, py, zorder=6, **r['style'])

# канон-точки
MARK = dict(capital=('*', 340, G900, 1.0), city=('o', 120, G900, 0.95),
            sector=('s', 110, '#B45309', 0.95), station=('o', 70, '#B45309', 0.9),
            rift=('D', 130, '#7C3AED', 0.95), site=('^', 95, '#047857', 0.9))
for name, (x, y, typ, reg, note) in POINTS.items():
    m, s, c, a = MARK[typ]
    ax.scatter([lon(x)], [lat(y)], marker=m, s=s, c=c, alpha=a, zorder=8,
               edgecolors='white', linewidths=1.2)

# подписи (офсеты подобраны вручную — нулевое перекрытие)
LBL = {
    'Аурелия': (1.6, 2.4, 'left'), 'Хрустальные Пики': (0, -2.2, 'center'),
    'Три Острова': (0, 1.4, 'center'), 'Грозовые Кузницы': (0, 1.9, 'center'),
    'Хаб (Юг)': (0, -2.0, 'center'), 'Абресс': (0, -2.1, 'center'),
    'Сектор Четыре': (-3.4, 0.9, 'right'), 'Цинк-4': (2.8, -0.4, 'left'),
    'Комплекс «Грань»': (-3.6, -1.6, 'right'), 'Асбест-3': (0, 1.4, 'center'),
    'Станция 1 «Левиафан»': (-3.4, -0.6, 'right'), 'Станция 2 «Левиафан»': (2.6, 0.5, 'left'),
    'Станция 3 «Левиафан»': (2.6, -0.6, 'left'), 'Озеро Отражений': (0, -2.2, 'center'),
    'Круг Костей': (0, 1.5, 'center'), 'Ущелье Тишины': (0, -2.0, 'center'),
    'Зеркальный Канал': (0, 1.5, 'center'), 'Кратер Буфера': (0, 1.6, 'center'),
    'Платиновое плато': (0, -2.2, 'center'), 'Сев. граница Империи': (0, 1.5, 'center'),
    'Долина Этер': (0, -2.2, 'center'),
}
for name, (dx, dy, ha) in LBL.items():
    x, y = POINTS[name][0], POINTS[name][1]
    big = POINTS[name][2] == 'capital'
    ax.annotate(name, (lon(x), lat(y)), xytext=(dx, dy), textcoords='offset fontsize',
                fontsize=10.5 if big else 9, fontweight='bold' if big else 'normal',
                color=G900 if big else G700, ha=ha, zorder=10,
                bbox=dict(boxstyle='round,pad=0.18', fc='white', ec='none', alpha=0.78))

# легенда трактов (вне карты, под картой)
from matplotlib.lines import Line2D
handles = [Line2D([0],[0], **r['style'], label=f"{r['name']} — {r['status']}") for r in ROUTES]
handles += [
    Line2D([0],[0], marker='*', color='none', markerfacecolor=G900, markersize=15, label='столицы (канон)'),
    Line2D([0],[0], marker='s', color='none', markerfacecolor='#B45309', markersize=10, label='сектора/шахты'),
    Line2D([0],[0], marker='D', color='none', markerfacecolor='#7C3AED', markersize=10, label='разломы Ω∩χ'),
]
leg1 = ax.legend(handles=handles, loc='upper center', bbox_to_anchor=(0.5, -0.055),
                 ncol=3, fontsize=8.6, frameon=False, title='ТРАКТЫ И ТОЧКИ (статусы T-24)',
                 title_fontsize=9.5, alignment='left')
ax.add_artist(leg1)

# вторая легенда — сеть поселений (аксиомы)
ax.legend(loc='upper left', bbox_to_anchor=(1.01, 1.0), fontsize=8.6, frameon=False,
          title='СЕТЬ ПОСЕЛЕНИЙ\n(аксиомы от 156.5M)', title_fontsize=9.5)

ax.set_xlim(lon(-2), lon(102)); ax.set_ylim(lat(-3), lat(102))
ax.set_xlabel('долгота °E (EQC, R=5838.4 км)', fontsize=9.5, color=G500)
ax.set_ylabel('широтa °N', fontsize=9.5, color=G500)
ax.set_xticks([lon(v) for v in range(0, 101, 20)])
ax.set_xticklabels([f'{lon(v):.0f}°' for v in range(0, 101, 20)])
ax.set_yticks([lat(v) for v in range(0, 101, 20)])
ax.set_yticklabels([f'{lat(v):.0f}°' for v in range(0, 101, 20)])
ax.tick_params(colors=G400, labelsize=8)
for sp in ('left', 'bottom'): ax.spines[sp].set_color(G300)

# ── ИНСЕТ 1: P³-мост Земля↔Этерия ──────────────────────────────────────
axE = fig.add_subplot(gs[0, 1])
axE.set_title('P³-МОСТ ЗЕМЛЯ↔ЭТЕРИЯ', loc='left', fontsize=11.5, fontweight='bold', color=G900)
for la, lo, nm in EARTH_P3:
    hot = 'Одесса' in nm or 'Киев' in nm
    axE.scatter([lo], [la], s=90 if hot else 46, c='#CC3311' if hot else '#475569',
                zorder=4, edgecolors='white', linewidths=1.0)
    dy = 4 if 'Одесса' not in nm else -7
    axE.annotate(nm.split(' (')[0], (lo, la), xytext=(4, dy), textcoords='offset fontsize',
                 fontsize=7.8, color=G700, ha='left')
axE.scatter([34.89], [47.12], s=150, marker='X', c='#047857', zorder=5, edgecolors='white', linewidths=1.2)
axE.annotate('СЕКТОР 4 (Этерия)\n47.12°N 34.89°E', (34.89, 47.12), xytext=(7, 7),
             textcoords='offset fontsize', fontsize=8, color='#047857', fontweight='bold')
axE.annotate('', xy=(33.5, 47.5), xytext=(31.2, 46.3),
             arrowprops=dict(arrowstyle='<|-|>', color='#CC3311', lw=1.6, linestyle='--'))
axE.text(24.5, 52.5, 'Протока: ΔLat +0.6533° ΔLon +4.1567°\nW=0.871985 · конъюнкция ×33 года\nK=9/7 · E=7.8×10¹⁹ Дж',
         fontsize=7.6, color=G700, ha='left',
         bbox=dict(boxstyle='round,pad=0.4', fc='#FFF7ED', ec='#B45309', lw=0.8))
axE.set_xlim(-110, 80); axE.set_ylim(-58, 78)
axE.set_xlabel('долгота °', fontsize=8, color=G500); axE.set_ylabel('широта °', fontsize=8, color=G500)
axE.tick_params(labelsize=7, colors=G400)
axE.grid(alpha=0.12, color=G300)
axE.text(-108, -51, '8 древних терминалов ОС Уроборос\nземляне — потомки этерианцев',
         fontsize=7.2, color=G500, style='italic', ha='left')

# ── ИНСЕТ 2: вертикальный стек Аурелии→Бездна ─────────────────────────
axV = fig.add_subplot(gs[1, 1])
axV.set_title('ВЕРТИКАЛЬ АУРЕЛИИ → БЕЗДНА', loc='left', fontsize=11.5, fontweight='bold', color=G900)
depths = [v[0] if isinstance(v[0], (int, float)) else 400 for v in VERTICAL]
names  = [v[1] for v in VERTICAL]
ypos = list(range(len(VERTICAL), 0, -1))
axV.barh(ypos, [-d for d in depths], color=['#FEF3C7']*2 + ['#F1F5F9']*5,
         edgecolor=[G700]*7, height=0.62, zorder=3)
for yp, d, nm in zip(ypos, depths, names):
    axV.text(120, yp, f'{d:+} м  {nm}', va='center', fontsize=8.2, color=G700, zorder=4)
axV.scatter([18.7]*7, ypos, marker='_', s=180, c='#7C3AED', zorder=5)  # волна Бездны
axV.text(-3300, 8.15, '18.7 Гц — «Голос Бездны»', fontsize=7.6, color='#7C3AED', ha='left')
axV.set_xlim(-3600, 900); axV.set_ylim(0.3, 8.8)
axV.axis('off')
axV.text(-3600, 0.4, 'φ-Жильный Дренаж: ХП → Сектор 4 → Бездна (перегруз 121–127%)',
         fontsize=7.4, color=G500, style='italic')

# ── ИНСЕТ 3: сводка регионов (роли I=U/R) ─────────────────────────────
axS = fig.add_subplot(gs[:, 2]); axS.axis('off')
axS.set_title('БАЛАНС ДЕРЖАВ (I = U/R)', loc='left', fontsize=11.5, fontweight='bold', color=G900)
rows = [
    ('СЕВЕР',  '2.6 млн км²', '2.1M',  'Ω-генератор: платина ×0.73, ядра', '#DBEAFE', '#475569'),
    ('ИМПЕРИЯ','8.6 млн км²', '68.5M', 'R-резистор: БУЯ, Секвестр X-0',    '#FEF3C7', '#B45309'),
    ('ВОСТОК', '8.6 млн км²', '17.2M', 'архив: янтарь, Тропа Шепота',      '#D1FAE5', '#047857'),
    ('ЗАПАД',  '6.6 млн км²', '26.6M', 'металл: сталь, адамантит',         '#F1F5F9', '#334155'),
    ('ЮГ',     '13.6 млн км²','40.7M', 'χ-генератор: α-сердца, 12 кн-в',   '#EDE9FE', '#6D28D9'),
    ('АБРЕСС', '5.3 млн км²', '1.5M',  'подземный арбитраж желаний',       '#FFF7ED', '#111827'),
]
yy = 0.94
for nm, area, pop, role, fc, ec in rows:
    axS.add_patch(Rectangle((0.02, yy-0.115), 0.96, 0.125, transform=axS.transAxes,
                            facecolor=fc, edgecolor=ec, lw=1.6, clip_on=False))
    axS.text(0.05, yy-0.022, nm, fontsize=9.5, fontweight='bold', color=ec, transform=axS.transAxes, va='top')
    axS.text(0.05, yy-0.088, f'{area} · {pop} чел · {role}', fontsize=7.8, color=G700,
             transform=axS.transAxes, va='top')
    yy -= 0.135
axS.text(0.02, yy+0.01, 'Цепь Ома: Север (Ω) − Юг (χ) = U\nИмперия = R → I = U/R\nСиндикат завышает R → Секвестр X-0',
         fontsize=8.2, color=G700, transform=axS.transAxes, va='top',
         bbox=dict(boxstyle='round,pad=0.5', fc='#F8FAFC', ec=G300, lw=0.8))
axS.text(0.02, yy-0.30, 'ГЕНЕЗИС: Fe-Ni импактор (5.97×10²³ кг,\n20 км/с, E=1.194×10³² Дж) → фредерит\nC₆₀[¹⁹²Os] → ядро-реактор 210 Вт/м²',
         fontsize=7.8, color='#B45309', transform=axS.transAxes, va='top',
         bbox=dict(boxstyle='round,pad=0.5', fc='#FFF7ED', ec='#B45309', lw=0.8))

# ══════════════════════════════════════════════════════════════════════
# §7. ВЫХОД: PNG + SETTLEMENTS_ETERIA.json + сводка проверок
# ══════════════════════════════════════════════════════════════════════
out_png = REPO / '01_ГЕОГРАФИЯ' / 'КАРТЫ_АТЛАС' / 'WORLD_MAP_ETERIA_v1.0.png'
out_png.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(out_png, dpi=200, facecolor='white', bbox_inches='tight', pad_inches=0.35)
plt.close(fig)

settle_out = {
    'meta': dict(version='1.0', date='2026-09-24', source='Etheria_Worldbuilding/index.md + GEOGRAPHY_ETERIA.json',
                 axiom_note='города/посёлки/сёла — детерминированная модель от населения, НЕ канон-имена'),
    'canon_points': {k: dict(x=v[0], y=v[1], lat=round(lat(v[1]), 4), lon=round(lon(v[0]), 4),
                             type=v[2], region=v[3], note=v[4]) for k, v in POINTS.items()},
    'regions': {k: dict(polygon=v['poly'], area_mkm2=round(rect_area_mkm2(v['poly']), 3),
                        role=v['role']) for k, v in REGIONS.items()},
    'routes': {r['name']: dict(waypoints=r['pts'], status=r['status'], dist=r['dist']) for r in ROUTES},
    'settlement_axioms': dict(
        model='15% города×600k · 25% посёлки×15k · 60% сёла×1.2k · тяготение к трактам · замыкание по населению',
        total_population=POP, villages_total=SETTLE['villages'],
        by_region=SETTLE['by_region'],
        cities_xy=[[round(x,2), round(y,2), r] for x, y, r in SETTLE['cities']],
        towns_xy=[[round(x,2), round(y,2), r] for x, y, r in SETTLE['towns']]),
    'p3_bridge': dict(earth_sites=[dict(lat=la, lon=lo, name=nm) for la, lo, nm in EARTH_P3],
                      protocol=dict(dLat_deg=0.6533, dLon_deg=4.1567, W=0.871985,
                                    conjunction_years=33, K='9/7', energy_J=7.8e19)),
    'checks': [dict(name=n, status=s, got=g, expect=e) for n, s, g, e in CHECKS],
}
out_json = REPO / '00_КАНОН' / 'SETTLEMENTS_ETERIA.json'
out_json.write_text(json.dumps(settle_out, ensure_ascii=False, indent=2), encoding='utf-8')

n_ok = sum(1 for _, s, _, _ in CHECKS if s == 'OK')
n_ap = sum(1 for _, s, _, _ in CHECKS if s == '~=')
n_fl = sum(1 for _, s, _, _ in CHECKS if s == 'FLAG')
n_ax = sum(1 for _, s, _, _ in CHECKS if s == 'AXIOM')
n_mm = sum(1 for _, s, _, _ in CHECKS if s == 'MISMATCH')
print('=' * 78)
print('  ETHERIA WORLD MAP v1.0 — СВОДКА')
print('=' * 78)
for n, s, g, e in CHECKS:
    print(f'  [{s:>7}] {n:<46} {g} vs {e}')
print('-' * 78)
print(f'  ИТОГО: {len(CHECKS)} проверок | OK={n_ok} ~={n_ap} FLAG={n_fl} AXIOM={n_ax} MISMATCH={n_mm}')
print(f'  Поселения: городов {len(SETTLE["cities"])} · посёлков {len(SETTLE["towns"])} · сёл {SETTLE["villages"]:,}')
print(f'  PNG : {out_png} ({out_png.stat().st_size//1024} КБ)')
print(f'  JSON: {out_json} ({out_json.stat().st_size//1024} КБ)')
