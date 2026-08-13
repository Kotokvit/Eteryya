#!/usr/bin/env python3
-- coding: utf-8 --
"""POLER[n] CLI v2.0 — Расширенная версия
Оригинал: poler.py v1.0.0 (POLER[n] Studio) Расширение: Super Z (для проекта Этерия)
НОВЫЕ ФУНКЦИИ v2.0:
--recursive     — автосканирование директории
--cross-resonance — кросс-файлный резонанс
EPUB поддержка  — чтение .epub без распаковки
Python API      — импорт как модуль (from poler_enhanced import PolerAnalyzer)
--theme         — автотемы со словарями ключевых слов
PNG метаданные  — чтение названий/описаний изображений
--diff          — сравнение двух версий документа """
import argparse import json import math import re import sys import os import zipfile from pathlib import Path from collections import Counter from dataclasses import dataclass, field from datetime import datetime from typing import List, Tuple, Dict, Optional, Any
version = "2.0.0" author = "POLER[n] Studio + Super Z"
═══════════════════════════════════════════════════════════════════════
℘ — ШАБЛОНЫ ВОСПРИЯТИЯ (из оригинала)
═══════════════════════════════════════════════════════════════════════
PII_PATTERNS: List[Tuple[str, str]] = [ (r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+.[A-Za-z]{2,}', '[EMAIL]'), (r'+?\d{1,3}[-.\s]?(?\d{2,3})?[-.\s]?\d{3,4}[-.\s]?\d{3,4}', '[PHONE]'), (r'\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}', '[CARD]'), (r'\b\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}\b', '[IP]'), (r'\b\d{1,2}[-./]\d{1,2}[-./]\d{2,4}\b', '[DATE]'), (r'(?<!\d)\d{10,12}(?!\d)', '[ID]'), (r'[А-ЯІЇЄҐA-Z][а-яіїєґa-z]+(?:\s+[А-ЯІЇЄҐA-Z][а-яіїєґa-z]+)+', '[NAME]'), ]
NOISE_WORDS = { 'chatgpt', 'gpt', 'claude', 'gemini', 'llama', 'mistral', 'copilot', 'bard', 'пользователь', 'user', 'chat', 'assistant', 'ассистент', 'сказал', 'написал', 'responded', 'answered', 'replied', 'http', 'https', 'www', 'com', 'org', 'net', 'ru', 'ua', }
STOPWORDS = set(""" і в на з до по для що як це цей ця ці ту він вона воно вони ми ви я та або але щоб коли якщо бо те тому й ой ну ось де під над між and the a an of to in on at for with by is are was were be been being he she it they we you i this that these those but or not no yes но из на к с по для что как это этот эта эти тот он она оно они мы вы я да нет или но чтобы если потому без при о а de la le les un une du des et en """.split())
EMOTIONAL_MARKERS = { 'важливо', 'критично', 'загроза', 'сенс', 'істота', 'важливий', 'значущий', 'проблема', 'сутність', 'глибокий', 'фундаментальний', 'криза', 'ризик', 'відповідальність', 'свідомість', 'реальність', 'істина', 'буття', 'важно', 'критично', 'угроза', 'смысл', 'сущность', 'важный', 'значимый', 'проблема', 'глубокий', 'фундаментальный', 'кризис', 'риск', 'ответственность', 'сознание', 'реальность', 'истина', 'бытие', 'important', 'critical', 'threat', 'meaning', 'crisis', 'risk', 'responsibility', 'consciousness', 'reality', 'truth', 'existence', 'essence', 'fundamental', 'deep', 'история', 'сила', 'власть', 'закон', 'порядок', 'хаос', 'магия', 'культура', 'религия', 'политика', 'экономика', 'война', 'мир', }
═══════════════════════════════════════════════════════════════════════
НОВОЕ v2.0: ТЕМЫ (--theme)
═══════════════════════════════════════════════════════════════════════
THEMES: Dict[str, List[str]] = { 'биология': [ 'резоносом', 'клетка', 'мембрана', 'митоз', 'ДНК', 'феррум', 'σ_e', 'BMR', 'гестац', 'беремен', 'плод', 'матка', 'плацент', 'эмбрион', 'Акме', 'проводим', 'меридиан', 'φ-поле', 'фредерит', 'резофаз', 'пьезо', 'органелл', 'кровь', 'метаболизм', 'АТФ', 'размнож', ], 'астрономия': [ 'P³', 'ΔΣ', 'φ-поле', 'фредерит', 'Этерия', 'Земля', 'транзит', 'M1', 'M2', 'параллакс', 'орбит', 'Кеплер', 'синодическ', 'конъюнкц', '33', 'окно', 'П³', 'W=0', 'проективн', ], 'география': [ 'Сектор', 'Северный тракт', 'Аурелия', 'Бездна', 'регион', 'Хрустальные', 'Платинов', 'Проклятые', 'Империя', 'Леса Востока', 'карта', 'координат', 'широта', 'долгота', 'маршрут', ], 'культивация': [ 'Сфера', 'сфер', 'Мнемар', 'Архимаг', 'Демоническ', 'Запредельн', 'Теневая', 'Архисфер', 'Дракон', 'Манас', 'Абсолют', 'Демпфер', 'Хаос', 'Порядок', 'Синтез', 'σ_e', 'культив', 'формообразов', ], 'навигация': [ 'P³', 'Протока', 'Киевские ворота', 'Одесса', 'транзит', 'Вениамин', 'Алексей', 'Ольга', 'Крона', 'Архитекторы', 'T-0', 'T-16', 'T-22', 'ладонь', 'Драконья матрица', ], }
═══════════════════════════════════════════════════════════════════════
O — ОБРАЗ (из оригинала)
═══════════════════════════════════════════════════════════════════════
@dataclass class TextWindow: index: int keyword: str position: int raw_text: str cleaned_text: str filtered_items: List[Tuple[str, str]] = field(default_factory=list) tokens: List[str] = field(default_factory=list) epsilon: float = 0.0 resonance: float = 0.0 source_file: str = ""  # НОВОЕ v2.0: из какого файла
═══════════════════════════════════════════════════════════════════════
L — ЛОГИКА (из оригинала)
═══════════════════════════════════════════════════════════════════════
def filter_pii(text: str) -> Tuple[str, List[Tuple[str, str]]]: filtered: List[Tuple[str, str]] = [] cleaned = text for pattern, replacement in PII_PATTERNS: for m in re.finditer(pattern, cleaned): filtered.append((m.group(0), replacement)) cleaned = re.sub(pattern, replacement, cleaned) return cleaned, filtered
def tokenize(text: str) -> List[str]: raw = re.findall(r'[\w]+', text.lower(), re.UNICODE) return [t for t in raw if t not in STOPWORDS and t not in NOISE_WORDS and len(t) > 2]
═══════════════════════════════════════════════════════════════════════
ε — ЭНЕРГИЯ (из оригинала)
═══════════════════════════════════════════════════════════════════════
def word_rarity(word: str, total_words: int, counts: Counter) -> float: p = counts.get(word, 1) / max(total_words, 1) return -math.log(max(p, 1e-10))
def compute_epsilon(window: TextWindow, keyword: str, counts: Counter, total_words: int, kappa: float = 1.0) -> float: kw_lower = keyword.lower() tokens = [t for t in window.tokens if t != kw_lower] if not tokens: return 0.0 unique = set(tokens) d_squared = sum(word_rarity(t, total_words, counts) ** 2 for t in unique) kw_count = window.cleaned_text.lower().count(kw_lower) kw_intensity = 1.0 + math.log1p(kw_count) emotion_bonus = sum(1.5 for t in tokens if t in EMOTIONAL_MARKERS) return kappa * kw_intensity * d_squared + emotion_bonus
═══════════════════════════════════════════════════════════════════════
R[n] — РЕЗОНАНС (из оригинала + кросс-файлный v2.0)
═══════════════════════════════════════════════════════════════════════
def compute_resonance_series(epsilons: List[float], phi_decay: float = 0.85) -> List[float]: n = len(epsilons) R = [0.0] * n for t in range(n): s = 0.0 for i in range(t + 1): s += epsilons[i] * (phi_decay ** (t - i)) R[t] = s return R
def compute_cross_resonance(all_windows: List[TextWindow], phi_decay: float = 0.85) -> List[float]: """НОВОЕ v2.0: Кросс-файлный резонанс. R_t учитывает фрагменты из ВСЕХ файлов, не только текущего.""" n = len(all_windows) R = [0.0] * n for t in range(n): s = 0.0 for i in range(t + 1): s += all_windows[i].epsilon * (phi_decay ** (t - i)) R[t] = s return R
═══════════════════════════════════════════════════════════════════════
НОВОЕ v2.0: ЧТЕНИЕ ФАЙЛОВ (TXT, MD, JSON, EPUB, PNG)
═══════════════════════════════════════════════════════════════════════
def read_file(path: str) -> str: """Читает текст из файла. Поддержка: .txt, .md, .json, .epub""" p = Path(path) if not p.exists(): return ""
def read_epub(path: str) -> str: """НОВОЕ v2.0: Читает текст из EPUB (ZIP с XHTML внутри).""" text_parts = [] try: with zipfile.ZipFile(path, 'r') as zf: for name in zf.namelist(): if name.endswith('.xhtml') or name.endswith('.html'): content = zf.read(name).decode('utf-8', errors='ignore') # Извлекаем текст из HTML (убираем теги) text = re.sub(r'<[^>]+>', ' ', content) text = re.sub(r'\s+', ' ', text).strip() if text: text_parts.append(text) except Exception as e: return f"[EPUB READ ERROR: {e}]" return '\n\n'.join(text_parts)
def json_to_text(data: Any, depth: int = 0) -> str: """Рекурсивно извлекает текст из JSON.""" if depth > 10: return "" parts = [] if isinstance(data, dict): for k, v in data.items(): parts.append(str(k)) parts.append(json_to_text(v, depth + 1)) elif isinstance(data, list): for item in data: parts.append(json_to_text(item, depth + 1)) elif isinstance(data, (str, int, float)): parts.append(str(data)) return ' '.join(parts)
def read_png_metadata(path: str) -> Dict: """НОВОЕ v2.0: Читает метаданные PNG (название файла как ключевое).""" p = Path(path) return { 'filename': p.name, 'size_bytes': p.stat().st_size, 'path': str(p), # Имя файла — единственный доступный "текст" без PIL 'text': p.stem.replace('_', ' '), }
def scan_directory(dir_path: str, extensions: List[str] = None) -> List[str]: """НОВОЕ v2.0: Рекурсивно обходит директорию, возвращает список файлов.""" if extensions is None: extensions = ['.md', '.txt', '.json', '.epub', '.html', '.png'] result = [] p = Path(dir_path) if p.is_file(): return [str(p)] for f in sorted(p.rglob('*')): if f.is_file() and f.suffix.lower() in extensions: result.append(str(f)) return result
═══════════════════════════════════════════════════════════════════════
ГЛАВНЫЙ ЦИКЛ POLER[n] (расширенный)
═══════════════════════════════════════════════════════════════════════
def run_poler_analyzer( text: str, keyword: str, window_size: int = 20000, phi_decay: float = 0.85, kappa: float = 1.0, top_n: int = 10, source_file: str = "", ) -> Dict: """Полный цикл POLER[n] для одного ключевого слова.""" pattern = re.compile(re.escape(keyword), re.IGNORECASE) positions = [m.start() for m in pattern.finditer(text)]
═══════════════════════════════════════════════════════════════════════
НОВОЕ v2.0: МУЛЬТИФАЙЛНЫЙ АНАЛИЗАТОР
═══════════════════════════════════════════════════════════════════════
def analyze_directory( dir_path: str, keyword: str, window_size: int = 5000, phi_decay: float = 0.85, kappa: float = 1.0, top_n: int = 5, cross_resonance: bool = False, extensions: List[str] = None, ) -> Dict: """НОВОЕ v2.0: Анализирует все файлы в директории по одному ключевому слову.""" files = scan_directory(dir_path, extensions) results_per_file = [] all_windows: List[TextWindow] = []
═══════════════════════════════════════════════════════════════════════
НОВОЕ v2.0: DIFF РЕЖИМ
═══════════════════════════════════════════════════════════════════════
def diff_files(file1: str, file2: str, keyword: str, window_size: int = 3000) -> Dict: """НОВОЕ v2.0: Сравнивает два файла по ключевому слову.""" text1 = read_file(file1) text2 = read_file(file2)
═══════════════════════════════════════════════════════════════════════
НОВОЕ v2.0: PYTHON API
═══════════════════════════════════════════════════════════════════════
class PolerAnalyzer: """НОВОЕ v2.0: Python API для использования в других скриптах."""
═══════════════════════════════════════════════════════════════════════
ФОРМАТЫ ВЫВОДА (из оригинала + расширения v2.0)
═══════════════════════════════════════════════════════════════════════
def _fmt(n: float, digits: int = 2) -> str: return f'{n:,.{digits}f}'
def _clean_for_display(text: str, max_chars: int = 3000) -> str: text = re.sub(r'\s+', ' ', text).strip() if len(text) > max_chars: cut = text.rfind(' ', 0, max_chars) text = text[:cut if cut != -1 else max_chars] + ' …' return text
def _highlight_md(text: str, keyword: str) -> str: if not keyword: return text return re.sub(f'({re.escape(keyword)})', r'\1', text, flags=re.IGNORECASE)
def format_directory_markdown(result: Dict) -> str: """НОВОЕ v2.0: MD-отчёт для мультфайлного анализа.""" lines = [] lines.append(f'# POLER[n] Анализ директории — «{result["keyword"]}»') lines.append('') lines.append(f'> Сканировано файлов: {result["files_scanned"]} · ' f'С совпадениями: {result["files_with_hits"]} · ' f'Всего окон: {result["total_windows"]} · ' f'Кросс-резонанс: {"ДА" if result["cross_resonance"] else "НЕТ"}') lines.append(f'> Директория: {result["directory"]}') lines.append('')
def format_diff_markdown(result: Dict) -> str: """НОВОЕ v2.0: MD-отчёт для diff-режима.""" lines = [] lines.append(f'# POLER[n] Diff — «{result["keyword"]}»') lines.append('') lines.append(f'| Параметр | Файл 1 | Файл 2 | Δ |') lines.append(f'|------|------|------|---|') lines.append(f'| Файл | {Path(result["file1"]).name} | {Path(result["file2"]).name} | |') lines.append(f'| Вхождений | {result["file1_windows"]} | {result["file2_windows"]} | {result["delta_windows"]:+d} |') lines.append(f'| Σ ε | {_fmt(result["file1_epsilon"], 0)} | {_fmt(result["file2_epsilon"], 0)} | {_fmt(result["delta_epsilon"], 0)} |') lines.append('') return '\n'.join(lines)
def format_markdown(result: Dict) -> str: """MD-вывод (из оригинала + source_file).""" cfg = result['config'] summary = result['summary'] pl = result['phase_log'] kw = result['keyword']
def format_json(result: Dict) -> str: return json.dumps(result, ensure_ascii=False, indent=2)
═══════════════════════════════════════════════════════════════════════
CLI v2.0
═══════════════════════════════════════════════════════════════════════
def main(): parser = argparse.ArgumentParser( prog='poler2', description=f'POLER[n] CLI v{version} — Расширенный анализатор', formatter_class=argparse.RawDescriptionHelpFormatter, ) parser.add_argument('input', nargs='?', help='Файл или директория') parser.add_argument('--stdin', action='store_true', help='Читать из stdin') parser.add_argument('-k', '--keyword', default='сфер', help='Ключевое слово') parser.add_argument('--multi', help='Несколько слов через запятую') parser.add_argument('--theme', choices=list(THEMES.keys()), help='Автотема') parser.add_argument('-w', '--window', type=int, default=20000, help='Размер окна') parser.add_argument('--phi', type=float, default=0.85, help='Затухание R[n]') parser.add_argument('--kappa', type=float, default=1.0, help='Интенсивность ε') parser.add_argument('--top', type=int, default=10, help='Топ-N окон') parser.add_argument('-f', '--format', choices=['ascii', 'md', 'json'], default='ascii') parser.add_argument('-o', '--output', help='Файл для сохранения')
def format_ascii_simple(result: Dict) -> str: """Упрощённый ASCII-вывод.""" lines = [f'POLER[n] v{version} — «{result["keyword"]}»', ''] if not result['windows']: lines.append('(не найдено)') return '\n'.join(lines) s = result['summary'] lines.append(f'Вхождений: {s["total_windows"]} | Σε: {_fmt(s["total_epsilon"], 0)} | ' f'Peak ε: {_fmt(s["peak_epsilon"], 0)} | PII: {s["total_pii"]}') lines.append('') for i, w in enumerate(result['top_by_epsilon'][:5], 1): lines.append(f'  {i}. ε={_fmt(w["epsilon"])} R={_fmt(w["resonance"])}') text = _clean_for_display(w['cleaned_text'], 200) lines.append(f'     {text}') lines.append('') return '\n'.join(lines)
def format_multi_markdown_enhanced(results: List[Dict], source_file: str = '') -> str: """MD с всеми ключевыми словами + source_file.""" lines = ['# 🗺️ Карта документа — POLER[n] v2.0', ''] lines.append(f'> {datetime.now().strftime("%Y-%m-%d %H:%M")} · Цикл: ℘ → O → L → ε → R[n]') if source_file: lines.append(f'> Файл: {source_file}') lines.append('')
if name == 'main': main()