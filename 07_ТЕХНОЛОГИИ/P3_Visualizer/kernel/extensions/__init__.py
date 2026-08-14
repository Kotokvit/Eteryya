"""
DYNAMIS Extensions v2.1
=======================
Расширения ядра P³:

  - spacetime: P³×R пространство-время, каузальная структура, мировые линии
  - dem_import: DEM → P³ конвертация рельефа, SRTM/GeoTIFF/CSV загрузка
"""

from .spacetime import (
    SpacetimePoint, CausalRelation, CausalInterval, CausalStructure,
    Worldline, WorldlineSegment, WorldEvolution,
    export_spacetime_json
)

from .dem_import import (
    DEMGrid, DEMLoader, DEMToP3, P3TerrainPoint
)

__all__ = [
    'SpacetimePoint', 'CausalRelation', 'CausalInterval', 'CausalStructure',
    'Worldline', 'WorldlineSegment', 'WorldEvolution', 'export_spacetime_json',
    'DEMGrid', 'DEMLoader', 'DEMToP3', 'P3TerrainPoint'
]
