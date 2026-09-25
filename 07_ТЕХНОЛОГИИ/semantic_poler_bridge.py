#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SEMANTIC-POLER BRIDGE (v1.0)
Объединяет:
1. Семантический разбор ассоциативного запроса на концептуальные векторы/кластеры.
2. Прогон через POLER Engine по резонансной плотности ε и R.
3. K-Hop сборка смыслового графа без потерь.
"""

import subprocess
import json
import re
from pathlib import Path

QUERY_ASSOCIATIONS = [
    # Разрушение тела / физиология
    ("зубы крошатся", ["кальций", "зуб", "эмаль", "метаболическ", "крош"]),
    ("разрушение плоти", ["CNED", "старение", "микротрещин", "плоть", "шунт"]),
    # Замуровывание / бетон / чиновники
    ("закатывают в бетон", ["Секвестр", "X-0", "бетон", "шлюз", "золот", "Цинк", "Свинец", "50"]),
    # Неврология / задержка
    ("задержка мир тормозит", ["лаг", "0.6", "аксональн", "баротравм", "диффузн", "сетчатк"]),
    # Контрабанда / черные алмазы / богатство
    ("черные алмазы богачи", ["Тёмное Сердце", "алмаз", "300 карат", "Вэнс", "бухгалтер"]),
    # Защитный металл / Сейф-Био
    ("свинец висмут сейф", ["Сейф-Био", "висмут", "свинец", "ARCH-HSM", "фильтр"]),
]

def run_query(keyword, top=3):
    cmd = [
        "poler-engine",
        "/home/vitalij/Стільниця/Eteryya",
        "-q", keyword,
        "--top", str(top),
        "--format", "ai-json"
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception as e:
        pass
    return None

def main():
    print("🧠 ЗАПУСК СЕМАНТИЧЕСКОГО МОСТА POLER ДЛЯ РАЗМЫТОГО ЗАПРОСА...")
    print("=" * 70)
    
    findings = []
    
    for cluster_name, keywords in QUERY_ASSOCIATIONS:
        print(f"\n🔍 Анализ смыслового кластера: «{cluster_name}»")
        cluster_hits = []
        for kw in keywords:
            data = run_query(kw, top=1)
            if data and data.get("anchors"):
                anchor = data["anchors"][0]
                cluster_hits.append({
                    "keyword": kw,
                    "file": Path(anchor["file"]).name,
                    "epsilon": anchor["epsilon"],
                    "resonance": anchor["resonance"],
                    "metric": anchor["scene"].get("temporal_metric"),
                    "location": anchor["scene"].get("location"),
                    "scope_snippet": anchor["scene"]["enclosing_scope"][:250] + "..."
                })
        
        # Сортируем по максимальному резонансу
        cluster_hits.sort(key=lambda x: x["resonance"], reverse=True)
        if cluster_hits:
            best = cluster_hits[0]
            print(f"  ✅ НАЙДЕНО СОВПАДЕНИЕ [R={best['resonance']:.1f}, ε={best['epsilon']:.1f}]:")
            print(f"     Файл: {best['file']} | Метрика: {best['metric']} | Локация: {best['location']}")
            print(f"     Контекст: {best['scope_snippet'].replace(chr(10), ' ')}")
            findings.append((cluster_name, best))
        else:
            print("  ❌ Не найдено")

if __name__ == "__main__":
    main()
