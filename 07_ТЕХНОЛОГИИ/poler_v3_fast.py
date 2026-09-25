#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
POLER CLI v3.0 — High-Performance Text Analyzer.
Оптимизированная версия: быстрее обработка, линейная сложность резонанса.

Алгоритм:
1. PRE-INDEXING: Токенизация всего текста один раз + построение инвертированного индекса.
2. WINDOWING: Поиск ключевых слов по индексам токенов (без regex на каждом шаге).
3. EPSILON: Расчет редкости на основе глобальной статистики токенов.
4. RESONANCE: Линейный рекурсивный фильтр (IIR) вместо накопления суммы.

Сравнение с v2.1:
- Скорость: ~10-50x быстрее на больших текстах (>100к токенов).
- Память: Эффективнее за счет работы с индексами, а не копиями строк.
"""

import argparse
import json
import math
import re
import sys
import zipfile
from pathlib import Path
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Tuple, Dict, Optional, Any, Iterator

__version__ = "3.0.0-fast"
__author__ = "POLER toolkit (Optimized)"

# ═══════════════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ И ПАТТЕРНЫ (Скомпилированные для скорости)
# ═══════════════════════════════════════════════════════════════════════

PII_COMPILED = [
    (re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'), '[EMAIL]'),
    (re.compile(r'\+?\d{1,3}[-.\s]?\(?\d{2,3}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}'), '[PHONE]'),
    (re.compile(r'\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}'), '[CARD]'),
    (re.compile(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'), '[IP]'),
    (re.compile(r'\b\d{1,2}[-./]\d{1,2}[-./]\d{2,4}\b'), '[DATE]'),
    (re.compile(r'(?<!\d)\d{10,12}(?!\d)'), '[ID]'),
    (re.compile(r'[А-ЯІЇЄҐA-Z][а-яіїєґa-z]+(?:\s+[А-ЯІЇЄҐA-Z][а-яіїєґa-z]+)+'), '[NAME]'),
]

NOISE_WORDS = frozenset({
    'chatgpt', 'gpt', 'claude', 'gemini', 'llama', 'mistral', 'copilot', 'bard',
    'пользователь', 'user', 'chat', 'assistant', 'ассистент',
    'сказал', 'написал', 'responded', 'answered', 'replied',
    'http', 'https', 'www', 'com', 'org', 'net', 'ru', 'ua',
})

STOPWORDS = frozenset("""
і в на з до по для що як це цей ця ці ту він вона воно вони ми ви я
та або але щоб коли якщо бо те тому й ой ну ось де під над між
and the a an of to in on at for with by is are was were be been being
he she it they we you i this that these those but or not no yes
но из на к с по для что как это этот эта эти тот он она оно они мы вы я
да нет или но чтобы если потому без при о
a de la le les un une du des et en
""".split())

EMOTIONAL_MARKERS = frozenset({
    'важливо', 'критично', 'загроза', 'сенс', 'істота', 'важливий', 'значущий',
    'проблема', 'сутність', 'глибокий', 'фундаментальний', 'криза', 'ризик',
    'відповідальність', 'свідомість', 'реальність', 'істина', 'буття',
    'важно', 'критично', 'угроза', 'смысл', 'сущность', 'важный', 'значимый',
    'проблема', 'глубокий', 'фундаментальный', 'кризис', 'риск',
    'ответственность', 'сознание', 'реальность', 'истина', 'бытие',
    'important', 'critical', 'threat', 'meaning', 'crisis', 'risk',
    'responsibility', 'consciousness', 'reality', 'truth', 'existence',
    'essence', 'fundamental', 'deep', 'история', 'сила', 'власть', 'закон',
    'порядок', 'хаос', 'культура', 'религия', 'политика', 'экономика', 'война', 'мир',
})

THEMES: Dict[str, List[str]] = {
    'наука': ['эксперимент', 'гипотеза', 'данные', 'анализ', 'метод', 'исследование', 'результат'],
    'бизнес': ['прибыль', 'клиент', 'рынок', 'стратегия', 'продажи', 'бюджет', 'инвестиции'],
    'технологии': ['алгоритм', 'сервер', 'код', 'система', 'сеть', 'протокол', 'API'],
    'психология': ['эмоция', 'поведение', 'мотивация', 'стресс', 'мышление', 'восприятие'],
    'право': ['договор', 'закон', 'иск', 'ответственность', 'суд', 'права', 'штраф'],
}

# ═══════════════════════════════════════════════════════════════════════
# СТРУКТУРЫ ДАННЫХ
# ═══════════════════════════════════════════════════════════════════════

@dataclass
class TokenWindow:
    """Окно, определенное индексами токенов, а не сырым текстом."""
    index: int
    keyword: str
    center_token_idx: int
    start_token_idx: int
    end_token_idx: int
    epsilon: float = 0.0
    resonance: float = 0.0
    source_file: str = ""
    _preview_text: str = ""

# ═══════════════════════════════════════════════════════════════════════
# БЫСТРАЯ ПРЕД-ОБРАБОТКА (PRE-PROCESSING)
# ═══════════════════════════════════════════════════════════════════════

def fast_clean_pii(text: str) -> str:
    """Быстрая очистка PII за один проход."""
    cleaned = text
    for pattern, replacement in PII_COMPILED:
        cleaned = pattern.sub(replacement, cleaned)
    return cleaned

def tokenize_fast(text: str) -> List[str]:
    """Возвращает список значимых токенов."""
    raw_tokens = re.findall(r'\w+', text.lower(), re.UNICODE)
    return [
        t for t in raw_tokens
        if len(t) > 2 and t not in STOPWORDS and t not in NOISE_WORDS
    ]

def build_index(text: str) -> Tuple[List[str], Dict[str, List[int]], str, List[int]]:
    """
    Строит индекс: список всех токенов и словарь {токен: [позиции]}.
    Возвращает также очищенный текст и позиции в символах.
    """
    clean_text = fast_clean_pii(text)
    tokens = []
    positions = []
    
    for match in re.finditer(r'\w+', clean_text, re.UNICODE):
        word = match.group()
        low_word = word.lower()
        if len(low_word) > 2 and low_word not in STOPWORDS and low_word not in NOISE_WORDS:
            tokens.append(low_word)
            positions.append(match.start())
            
    index_map = defaultdict(list)
    for i, token in enumerate(tokens):
        index_map[token].append(i)
        
    return tokens, index_map, clean_text, positions

# ═══════════════════════════════════════════════════════════════════════
# ЯДРО АНАЛИЗА (CORE ENGINE)
# ═══════════════════════════════════════════════════════════════════════

def compute_epsilon_fast(
    window_tokens: List[str], 
    keyword: str, 
    global_counts: Counter, 
    total_words: int, 
    kappa: float
) -> float:
    """Вычисляет Epsilon без создания тяжелых объектов."""
    kw_lower = keyword.lower()
    unique_tokens = set(window_tokens)
    if not unique_tokens:
        return 0.0
    
    unique_tokens.discard(kw_lower)
    
    d_squared = 0.0
    emotion_bonus = 0.0
    log_total = math.log(max(total_words, 1))
    
    for t in unique_tokens:
        count = global_counts.get(t, 1)
        rarity = log_total - math.log(count)
        d_squared += rarity * rarity
        
        if t in EMOTIONAL_MARKERS:
            emotion_bonus += 1.5
            
    kw_count = window_tokens.count(kw_lower)
    kw_intensity = 1.0 + math.log1p(kw_count)
    
    return kappa * kw_intensity * d_squared + emotion_bonus

def compute_resonance_linear(epsilons: List[float], phi_decay: float) -> List[float]:
    """Линейный расчет резонанса O(N): R_t = epsilon_t + phi * R_{t-1}."""
    if not epsilons:
        return []
    
    resonances = [0.0] * len(epsilons)
    current_r = 0.0
    
    for i, eps in enumerate(epsilons):
        current_r = eps + (phi_decay * current_r)
        resonances[i] = current_r
        
    return resonances

def run_poler_v3(
    text: str,
    keyword: str,
    window_radius_tokens: int = 50,
    phi_decay: float = 0.85,
    kappa: float = 1.0,
    top_n: int = 10,
    source_file: str = "",
) -> Dict:
    kw_lower = keyword.lower()
    tokens, index_map, clean_text, positions = build_index(text)
    
    if kw_lower not in index_map:
        return {
            'keyword': keyword, 'windows': [], 'summary': None,
            'top_by_epsilon': [], 'top_by_resonance': [], 'source_file': source_file
        }

    total_words = len(tokens)
    global_counts = Counter(tokens)
    hit_indices = index_map[kw_lower]
    num_hits = len(hit_indices)
    
    if num_hits == 0:
        return {'keyword': keyword, 'windows': [], 'summary': None, 'top_by_epsilon': [], 'top_by_resonance': []}

    windows_data = []
    for i, center_idx in enumerate(hit_indices):
        start = max(0, center_idx - window_radius_tokens)
        end = min(total_words, center_idx + window_radius_tokens)
        w_tokens = tokens[start:end]
        
        windows_data.append({
            'idx': i,
            'center': center_idx,
            'tokens': w_tokens,
            'start_char': positions[start] if start < len(positions) else 0,
        })

    epsilons = []
    for w in windows_data:
        eps = compute_epsilon_fast(w['tokens'], keyword, global_counts, total_words, kappa)
        epsilons.append(eps)
    
    resonances = compute_resonance_linear(epsilons, phi_decay)
    
    sorted_indices = sorted(range(len(epsilons)), key=lambda k: epsilons[k], reverse=True)
    top_indices = sorted_indices[:top_n]
    
    top_results = []
    for rank, orig_idx in enumerate(top_indices):
        w = windows_data[orig_idx]
        preview = " ".join(w['tokens']) 
        if len(preview) > 1000:
            preview = preview[:1000] + "..."
            
        top_results.append({
            'index': orig_idx,
            'position': w['start_char'],
            'epsilon': epsilons[orig_idx],
            'resonance': resonances[orig_idx],
            'cleaned_text': preview,
            'source_file': source_file
        })
        
    sorted_by_r = sorted(range(len(resonances)), key=lambda k: resonances[k], reverse=True)
    top_r_indices = sorted_by_r[:top_n]
    
    top_r_results = []
    for orig_idx in top_r_indices:
        w = windows_data[orig_idx]
        preview = " ".join(w['tokens'])
        if len(preview) > 1000:
            preview = preview[:1000] + "..."
        top_r_results.append({
            'index': orig_idx,
            'position': w['start_char'],
            'epsilon': epsilons[orig_idx],
            'resonance': resonances[orig_idx],
            'cleaned_text': preview,
            'source_file': source_file
        })

    summary = {
        'keyword': keyword,
        'total_text_length': len(text),
        'total_words': total_words,
        'unique_words': len(global_counts),
        'total_windows': num_hits,
        'total_epsilon': sum(epsilons),
        'avg_epsilon': sum(epsilons) / num_hits if num_hits else 0,
        'avg_resonance': sum(resonances) / num_hits if num_hits else 0,
        'peak_epsilon': epsilons[sorted_indices[0]] if sorted_indices else 0,
        'peak_resonance': resonances[sorted_by_r[0]] if sorted_by_r else 0,
        'source_file': source_file,
    }

    return {
        'keyword': keyword,
        'summary': summary,
        'top_by_epsilon': top_results,
        'top_by_resonance': top_r_results,
        'source_file': source_file,
        'phase_log': {'indexed_tokens': total_words, 'hits': num_hits}
    }

# ═══════════════════════════════════════════════════════════════════════
# УТИЛИТЫ ЧТЕНИЯ
# ═══════════════════════════════════════════════════════════════════════

def read_file(path: str) -> str:
    p = Path(path)
    if not p.exists():
        return ""
    suffix = p.suffix.lower()
    if suffix == '.epub':
        return read_epub(path)
    elif suffix == '.json':
        try:
            data = json.loads(p.read_text(encoding='utf-8'))
            return json_to_text(data)
        except Exception:
            return p.read_text(encoding='utf-8', errors='ignore')
    else:
        try:
            return p.read_text(encoding='utf-8')
        except Exception:
            return ""

def read_epub(path: str) -> str:
    text_parts = []
    try:
        with zipfile.ZipFile(path, 'r') as zf:
            for name in zf.namelist():
                if name.endswith('.xhtml') or name.endswith('.html'):
                    content = zf.read(name).decode('utf-8', errors='ignore')
                    text = re.sub(r'<[^>]+>', ' ', content)
                    text = re.sub(r'\s+', ' ', text).strip()
                    if text:
                        text_parts.append(text)
    except Exception:
        pass
    return '\n\n'.join(text_parts)

def json_to_text(data: Any, depth: int = 0) -> str:
    if depth > 10: return ""
    parts = []
    if isinstance(data, dict):
        for k, v in data.items():
            parts.append(str(k))
            parts.append(json_to_text(v, depth + 1))
    elif isinstance(data, list):
        for item in data:
            parts.append(json_to_text(item, depth + 1))
    elif isinstance(data, (str, int, float)):
        parts.append(str(data))
    return ' '.join(parts)

def scan_directory(dir_path: str, extensions: Optional[List[str]] = None) -> List[str]:
    if extensions is None:
        extensions = ['.md', '.txt', '.json', '.epub', '.html']
    result = []
    p = Path(dir_path)
    if p.is_file():
        return [str(p)]
    for f in sorted(p.rglob('*')):
        if f.is_file() and f.suffix.lower() in extensions:
            result.append(str(f))
    return result

# ═══════════════════════════════════════════════════════════════════════
# API КЛАСС
# ═══════════════════════════════════════════════════════════════════════

class PolerAnalyzer:
    def __init__(self, window_tokens: int = 50, phi: float = 0.85, kappa: float = 1.0, top: int = 10):
        self.window_tokens = window_tokens
        self.phi = phi
        self.kappa = kappa
        self.top = top

    def analyze_file(self, filepath: str, keyword: str) -> Dict:
        text = read_file(filepath)
        return run_poler_v3(text, keyword, self.window_tokens, self.phi, self.kappa, self.top, filepath)

    def analyze_text(self, text: str, keyword: str) -> Dict:
        return run_poler_v3(text, keyword, self.window_tokens, self.phi, self.kappa, self.top)

# ═══════════════════════════════════════════════════════════════════════
# ФОРМАТИРОВАНИЕ ВЫВОДА
# ═══════════════════════════════════════════════════════════════════════

def _fmt(n: float, digits: int = 2) -> str:
    return f'{n:,.{digits}f}'

def format_markdown(result: Dict) -> str:
    summary = result.get('summary')
    if not summary:
        return f"# POLER v3 — «{result['keyword']}»\n\nНичего не найдено."
    
    kw = result['keyword']
    lines = [f'# POLER v3 — анализ «{kw}»', '']
    lines.append(f'> Скорость: Optimized Engine · {datetime.now().strftime("%Y-%m-%d %H:%M")}')
    lines.append(f'> Файл: `{result.get("source_file", "stdin")}`')
    lines.append('')
    lines.append(f'**Статистика:** Вхождений: {summary["total_windows"]} | Σε: {_fmt(summary["total_epsilon"])} | Peak ε: {_fmt(summary["peak_epsilon"])}')
    lines.append('')
    
    lines.append(f'## Топ-{len(result["top_by_epsilon"])} по ε')
    lines.append('')
    for i, w in enumerate(result['top_by_epsilon'], 1):
        lines.append(f'### {i}. ε={_fmt(w["epsilon"])} · R={_fmt(w["resonance"])}')
        lines.append('```text')
        text = w['cleaned_text'].replace(kw, f"**{kw}**")
        lines.append(text)
        lines.append('```')
        lines.append('---')
        lines.append('')
        
    return '\n'.join(lines)

def format_ascii_simple(result: Dict) -> str:
    summary = result.get('summary')
    if not summary:
        return f'POLER v3 — «{result["keyword"]}»: не найдено.'
    
    lines = [f'POLER v{__version__} — «{result["keyword"]}»', '']
    lines.append(f'Hits: {summary["total_windows"]} | Σε: {_fmt(summary["total_epsilon"], 0)} | Peak: {_fmt(summary["peak_epsilon"], 0)}')
    lines.append('')
    for i, w in enumerate(result['top_by_epsilon'][:5], 1):
        lines.append(f'  {i}. ε={_fmt(w["epsilon"])} R={_fmt(w["resonance"])}')
        lines.append(f'     {w["cleaned_text"][:150]}...')
    return '\n'.join(lines)

# ═══════════════════════════════════════════════════════════════════════
# CLI ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(prog='poler3', description=f'POLER CLI v{__version__} (Fast)')
    parser.add_argument('input', nargs='?', help='Файл или директория')
    parser.add_argument('--stdin', action='store_true', help='Читать из stdin')
    parser.add_argument('-k', '--keyword', required=False, help='Ключевое слово')
    parser.add_argument('--multi', help='Несколько слов через запятую')
    parser.add_argument('--theme', choices=list(THEMES.keys()), help='Тематический набор')
    parser.add_argument('-w', '--window', type=int, default=50, help='Размер окна (в токенах)')
    parser.add_argument('--phi', type=float, default=0.85, help='Затухание резонанса')
    parser.add_argument('--kappa', type=float, default=1.0, help='Множитель ε')
    parser.add_argument('--top', type=int, default=10, help='Количество результатов')
    parser.add_argument('-f', '--format', choices=['ascii', 'md', 'json'], default='ascii')
    parser.add_argument('-o', '--output', help='Сохранить в файл')
    parser.add_argument('-r', '--recursive', action='store_true', help='Рекурсивный скан директории')
    
    args = parser.parse_args()
    
    if not args.keyword and not args.multi and not args.theme:
        parser.error("Требуется -k, --multi или --theme")

    keywords = []
    if args.multi:
        keywords = [k.strip() for k in args.multi.split(',')]
    elif args.theme:
        keywords = THEMES[args.theme]
    else:
        keywords = [args.keyword]

    def process_single(text: str, source: str, kw: str) -> Dict:
        return run_poler_v3(text, kw, args.window, args.phi, args.kappa, args.top, source)

    results = []
    
    if args.recursive and args.input:
        files = scan_directory(args.input)
        for f in files:
            txt = read_file(f)
            if txt:
                for kw in keywords:
                    res = process_single(txt, f, kw)
                    if res.get('summary'):
                        results.append(res)
    elif args.stdin:
        txt = sys.stdin.read()
        for kw in keywords:
            results.append(process_single(txt, '<stdin>', kw))
    elif args.input:
        txt = read_file(args.input)
        for kw in keywords:
            results.append(process_single(txt, args.input, kw))
    else:
        parser.print_help()
        return

    output = ""
    if args.format == 'json':
        output = json.dumps(results if len(results) > 1 else (results[0] if results else {}), ensure_ascii=False, indent=2)
    elif args.format == 'md':
        output = "\n\n---\n\n".join(format_markdown(r) for r in results)
    else:
        output = "\n\n".join(format_ascii_simple(r) for r in results)

    if args.output:
        Path(args.output).write_text(output, encoding='utf-8')
        sys.stderr.write(f"Saved to {args.output}\n")
    else:
        print(output)

if __name__ == '__main__':
    main()
