# DYNAMIS v3.0 — P³ Лаборатория

> **Революция в проективной географии:**
> проектирование целых миров на проективном многообразии P³ = RP³ = S³/{±1}

## Быстрый старт

### В браузере
Откройте `index.html` — 10 режимов визуализации:
0. Скрещивающиеся прямые
1. Переключение карт
2. Z/2Z Движок
3. Ω/χ + d_FS Метрика
4. M1/M2 Линзирование
5. L_∅ Симуляция
6. Конъюгация SO(3)
7. Π_Λ + J кручение
8. P³×R Пространство-время **(NEW)**
9. DEM → P³ Рельеф **(NEW)**

### Docker
```bash
docker build -t dynamis .
docker run -p 8080:80 dynamis
# → http://localhost:8080
```

### Python
```python
from kernel.p3_kernel import HomVec4, fs_distance
from kernel.extensions.spacetime import WorldEvolution, SpacetimePoint
from kernel.extensions.dem_import import DEMLoader, DEMToP3

# P³ ядро
p1 = HomVec4(0.5, 0.3, 0.2, 0.8).normalize()
p2 = HomVec4(0.4, 0.35, 0.25, 0.82).normalize()
print(f"d_FS = {fs_distance(p1, p2):.6f}")

# P³×R пространство-время
evolution = WorldEvolution()
# ... (см. spacetime.py demo)

# DEM → P³
dem = DEMLoader.generate_synthetic(style='earth_like')
converter = DEMToP3()
points = converter.convert(dem, downsample=4)
```

## Структура

```
P3_Visualizer/
├── index.html              # DYNAMIS v3.0 — браузерный визуализатор
├── extensions.js           # Pyodide + SymPy + Spacetime + DEM (JS)
├── Dockerfile              # Docker-пакет
├── docker-compose.yml      # docker-compose up -d
├── kernel/
│   ├── p3_kernel.py        # P³ Ядро v2.0 — HomVec4, PGL(4), W-калибровка
│   ├── ouroboros_system.py # ОС Уробороса v3.0 — процессы, IPC, FS
│   └── extensions/
│       ├── __init__.py
│       ├── spacetime.py    # P³×R пространство-время
│       └── dem_import.py   # DEM → P³ рельеф
```

## Ключевые формулы

| Формула | Описание |
|---------|----------|
| P³ = (R⁴\{0})/~ | Проективное пространство |
| d_FS = arccos(\|⟨v₁,v₂⟩\|) | Фубини-Штуди метрика |
| W = cos(s/2R) | W-калибровка |
| g = diag(-1,-1,-1,+1), g²=I | Z/2Z голономия |
| K = 9/7 | Темпоральная константа анизотропии |
| d_causal = d_FS - \|Δt\|/c_eff | Каузальный интервал P³×R |

## Лицензия

BSD-3-Clause — свободное использование и модификация.
