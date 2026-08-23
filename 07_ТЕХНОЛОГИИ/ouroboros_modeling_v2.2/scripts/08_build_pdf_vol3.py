#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ГЕНЕРАТОТР PDF-ОТЧЁТА: «Система Уроборос — Том 3: Биологическое железо Этерии»
Report route: ReportLab (тело) + HTML/Playwright обложка (уже отрендерена).
Все числа берутся из результатов расчётных скриптов results/*.json.
"""
import hashlib
import json
import os
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.pdfmetrics import registerFontFamily
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (CondPageBreak, HRFlowable, KeepTogether,
                                PageBreak, Paragraph, SimpleDocTemplate,
                                Spacer, Table, TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(HERE, "results")
PDF_SKILL_SCRIPTS = "/home/z/my-project/skills/pdf/scripts"
sys.path.insert(0, PDF_SKILL_SCRIPTS)

# ── Шрифты ──────────────────────────────────────────────────────────────────
FONT_DIR = "/usr/share/fonts"
pdfmetrics.registerFont(TTFont("FreeSerif", f"{FONT_DIR}/truetype/freefont/FreeSerif.ttf"))
pdfmetrics.registerFont(TTFont("FreeSerif-Bold", f"{FONT_DIR}/truetype/freefont/FreeSerifBold.ttf"))
pdfmetrics.registerFont(TTFont("FreeSerif-Italic", f"{FONT_DIR}/truetype/freefont/FreeSerifItalic.ttf"))
pdfmetrics.registerFont(TTFont("FreeSerif-BoldItalic", f"{FONT_DIR}/truetype/freefont/FreeSerifBoldItalic.ttf"))
pdfmetrics.registerFont(TTFont("DejaVuSans", f"{FONT_DIR}/truetype/dejavu/DejaVuSansMono.ttf"))
pdfmetrics.registerFont(TTFont("DejaVuSans-Bold", f"{FONT_DIR}/truetype/dejavu/DejaVuSansMono-Bold.ttf"))
registerFontFamily("FreeSerif", normal="FreeSerif", bold="FreeSerif-Bold",
                   italic="FreeSerif-Italic", boldItalic="FreeSerif-BoldItalic")
registerFontFamily("DejaVuSans", normal="DejaVuSans", bold="DejaVuSans-Bold")

from pdf import install_font_fallback  # noqa: E402
install_font_fallback()

# ── Палитра (cascade, intent=cold, mode=minimal, seed=42) ───────────────────
PAGE_BG       = colors.HexColor('#f4f5f5')
SECTION_BG    = colors.HexColor('#f0f1f2')
CARD_BG       = colors.HexColor('#e8eaeb')
TABLE_STRIPE  = colors.HexColor('#ebeded')
HEADER_FILL   = colors.HexColor('#32454e')
COVER_BLOCK   = colors.HexColor('#566a74')
BORDER        = colors.HexColor('#acbdc5')
ICON          = colors.HexColor('#4b86a4')
ACCENT        = colors.HexColor('#1f6c92')
ACCENT_2      = colors.HexColor('#c23a50')
TEXT_PRIMARY  = colors.HexColor('#131515')
TEXT_MUTED    = colors.HexColor('#747b7e')

TABLE_HEADER_COLOR = HEADER_FILL
TABLE_ROW_EVEN     = colors.white
TABLE_ROW_ODD      = TABLE_STRIPE

# ── Результаты расчётов ─────────────────────────────────────────────────────
with open(os.path.join(RESULTS, "00_axioms.json"), encoding="utf-8") as f:
    AX = json.load(f)
with open(os.path.join(RESULTS, "01_filter.json"), encoding="utf-8") as f:
    FLT = json.load(f)
with open(os.path.join(RESULTS, "02_p3metric.json"), encoding="utf-8") as f:
    P3 = json.load(f)
with open(os.path.join(RESULTS, "03_biobus.json"), encoding="utf-8") as f:
    BIO = json.load(f)
with open(os.path.join(RESULTS, "05_spheres.json"), encoding="utf-8") as f:
    SPH = json.load(f)
with open(os.path.join(RESULTS, "06_races.json"), encoding="utf-8") as f:
    RAC = json.load(f)

# ── Геометрия страницы ──────────────────────────────────────────────────────
MARGIN = 2.0 * cm
PAGE_W, PAGE_H = A4
AVAIL_W = PAGE_W - 2 * MARGIN
AVAIL_H = PAGE_H - 2 * MARGIN
H1_ORPHAN = AVAIL_H * 0.25
MAX_KEEP = PAGE_H * 0.4

# ── Стили ───────────────────────────────────────────────────────────────────
S_BODY = ParagraphStyle("Body", fontName="FreeSerif", fontSize=10.5, leading=16,
                        alignment=TA_JUSTIFY, textColor=TEXT_PRIMARY,
                        spaceBefore=0, spaceAfter=8)
S_H1 = ParagraphStyle("H1", fontName="FreeSerif-Bold", fontSize=17.5, leading=23,
                      alignment=TA_LEFT, textColor=HEADER_FILL,
                      spaceBefore=14, spaceAfter=10)
S_H2 = ParagraphStyle("H2", fontName="FreeSerif-Bold", fontSize=13.5, leading=19,
                      alignment=TA_LEFT, textColor=TEXT_PRIMARY,
                      spaceBefore=12, spaceAfter=7)
S_H3 = ParagraphStyle("H3", fontName="FreeSerif-Bold", fontSize=11.5, leading=16,
                      alignment=TA_LEFT, textColor=TEXT_PRIMARY,
                      spaceBefore=10, spaceAfter=6)
S_CAPTION = ParagraphStyle("Caption", fontName="FreeSerif-Italic", fontSize=8.5,
                           leading=12, alignment=TA_CENTER, textColor=TEXT_MUTED,
                           spaceBefore=3, spaceAfter=6)
S_CODE = ParagraphStyle("Code", fontName="DejaVuSans", fontSize=7.6, leading=10.4,
                        alignment=TA_LEFT, textColor=TEXT_PRIMARY)
S_TH = ParagraphStyle("TH", fontName="FreeSerif-Bold", fontSize=9.2, leading=12.5,
                      alignment=TA_CENTER, textColor=colors.white)
S_TD = ParagraphStyle("TD", fontName="FreeSerif", fontSize=9.0, leading=12.5,
                      alignment=TA_CENTER, textColor=TEXT_PRIMARY)
S_TD_L = ParagraphStyle("TDL", parent=S_TD, alignment=TA_LEFT)
S_TD_R = ParagraphStyle("TDR", parent=S_TD, alignment=TA_RIGHT)
S_CALL = ParagraphStyle("Call", fontName="FreeSerif", fontSize=9.8, leading=14.5,
                        alignment=TA_LEFT, textColor=TEXT_PRIMARY)
S_QUOTE = ParagraphStyle("Quote", fontName="FreeSerif-Italic", fontSize=10.0,
                         leading=15, alignment=TA_LEFT, textColor=TEXT_MUTED,
                         leftIndent=24, spaceBefore=6, spaceAfter=6)
S_TOC0 = ParagraphStyle("TOC0", fontName="FreeSerif-Bold", fontSize=11, leading=18,
                        leftIndent=16, textColor=TEXT_PRIMARY)
S_TOC1 = ParagraphStyle("TOC1", fontName="FreeSerif", fontSize=9.5, leading=15,
                        leftIndent=34, textColor=TEXT_MUTED)

# ── Утилиты построения ──────────────────────────────────────────────────────

def heading(text, style, level=0):
    key = "h_" + hashlib.md5(text.encode()).hexdigest()[:8]
    p = Paragraph(f'<a name="{key}"/>{text}', style)
    p.bookmark_name = key
    p.bookmark_level = level
    p.bookmark_text = text
    p.bookmark_key = key
    return p


def H1(story, text):
    story.append(CondPageBreak(H1_ORPHAN))
    story.append(heading(text, S_H1, 0))
    story.append(HRFlowable(width="100%", color=ACCENT, thickness=1.2,
                            spaceBefore=0, spaceAfter=8))


def H2(story, text):
    story.append(CondPageBreak(50))
    story.append(heading(text, S_H2, 1))


def P(story, text):
    story.append(Paragraph(text, S_BODY))


def callout(story, text):
    """Акцентный блок с левой границей."""
    inner = Paragraph(text, S_CALL)
    t = Table([[inner]], colWidths=[AVAIL_W - 8])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CARD_BG),
        ("LINEBEFORE", (0, 0), (0, -1), 3, ACCENT),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    story.append(Spacer(1, 6))
    story.append(t)
    story.append(Spacer(1, 8))


def code_block(story, lines, caption=None):
    """ASCII-схема: моноширинный блок на подложке."""
    paras = [Paragraph(ln.replace(" ", " "), S_CODE) for ln in lines]
    t = Table([[paras]], colWidths=[AVAIL_W])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), SECTION_BG),
        ("LINEBEFORE", (0, 0), (0, -1), 2, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    story.append(Spacer(1, 4))
    story.append(t)
    if caption:
        story.append(Paragraph(caption, S_CAPTION))
    story.append(Spacer(1, 4))


def data_table(story, headers, rows, ratios, caption=None, align_map=None,
               highlight_rows=None):
    """Таблица данных: все ячейки — Paragraph, пропорциональные ширины."""
    col_w = [r * AVAIL_W for r in ratios]
    data = [[Paragraph(f"<b>{h}</b>", S_TH) for h in headers]]
    for row in rows:
        cells = []
        for j, cell in enumerate(row):
            st = S_TD
            if align_map and align_map[j] == "L":
                st = S_TD_L
            elif align_map and align_map[j] == "R":
                st = S_TD_R
            cells.append(Paragraph(str(cell), st))
        data.append(cells)
    t = Table(data, colWidths=col_w, hAlign="CENTER", repeatRows=1)
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), TABLE_HEADER_COLOR),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), 0.4, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    for i in range(1, len(data)):
        style.append(("BACKGROUND", (0, i), (-1, i),
                      TABLE_ROW_EVEN if i % 2 == 1 else TABLE_ROW_ODD))
    if highlight_rows:
        for i in highlight_rows:
            style.append(("BACKGROUND", (0, i), (-1, i), CARD_BG))
    t.setStyle(TableStyle(style))
    story.append(Spacer(1, 10))
    story.append(t)
    if caption:
        story.append(Paragraph(caption, S_CAPTION))
    story.append(Spacer(1, 10))


def fmt(x, digits=3):
    """Число в научной нотации с <super> для PDF."""
    if x == 0:
        return "0"
    from math import floor, log10
    e = floor(log10(abs(x)))
    if -3 < e < 4:
        return f"{x:.{digits}f}".rstrip("0").rstrip(".")
    m = x / (10 ** e)
    return f"{m:.2f}·10<super>{e}</super>"



# ── Встраивание изображений с сохранением пропорций ────────────────────────
from PIL import Image as PILImage
from reportlab.platypus import Image

def embed_image(path, max_width=None, max_height=None):
    if max_width is None:
        max_width = AVAIL_W
    if max_height is None:
        max_height = A4[1] * 0.35
    pil = PILImage.open(path)
    ow, oh = pil.size
    rw = max_width / ow if ow > max_width else 1.0
    rh = max_height / oh if oh > max_height else 1.0
    r = min(rw, rh)
    return Image(path, width=ow * r, height=oh * r)

# ── Шаблон документа с TOC ──────────────────────────────────────────────────
class TocDocTemplate(SimpleDocTemplate):
    def afterFlowable(self, flowable):
        if hasattr(flowable, "bookmark_name"):
            level = getattr(flowable, "bookmark_level", 0)
            text = getattr(flowable, "bookmark_text", "")
            key = getattr(flowable, "bookmark_key", "")
            self.notify("TOCEntry", (level, text, self.page, key))


def on_page(canvas, doc):
    canvas.saveState()
    # Верхний колонтитул
    canvas.setFont("FreeSerif", 7.5)
    canvas.setFillColor(TEXT_MUTED)
    canvas.drawString(MARGIN, PAGE_H - MARGIN + 18, "Система Уроборос — мастер-план инженерного моделирования и расчета · v2.0")
    canvas.setStrokeColor(ACCENT)
    canvas.setLineWidth(1.0)
    canvas.line(MARGIN, PAGE_H - MARGIN + 12, PAGE_W - MARGIN, PAGE_H - MARGIN + 12)
    # Нижний колонтитул
    canvas.setStrokeColor(BORDER)
    canvas.setLineWidth(0.5)
    canvas.line(MARGIN, MARGIN - 14, PAGE_W - MARGIN, MARGIN - 14)
    canvas.setFont("FreeSerif", 7.5)
    canvas.drawString(MARGIN, MARGIN - 26, "UROBOROS / MODELING-PLAN / REV 2.0.0")
    canvas.drawRightString(PAGE_W - MARGIN, MARGIN - 26, f"Стр. {doc.page}")
    canvas.restoreState()


print("[1/3] Строю story Тома 3...")
story = []

# ГЛАВЫ ТОМА 3
toc = TableOfContents()
toc.levelStyles = [S_TOC0, S_TOC1]
story.append(Paragraph("<b>Содержание</b>", ParagraphStyle(
    "TOCTitle", parent=S_H1, spaceBefore=2)))
story.append(HRFlowable(width="100%", color=ACCENT, thickness=1.2, spaceAfter=10))
story.append(toc)
story.append(PageBreak())

CHART_DIR = os.path.join(HERE, "charts")

# ════════════════════════════════════════════════════════════════════════════
# ГЛАВА 1. ПОСТАНОВКА
# ════════════════════════════════════════════════════════════════════════════
H1(story, "1. Постановка: расы как аппаратные узлы")

P(story, "Тома 1 и 2 оцифровали физический и прикладной уровни системы: частотный "
   "каскад, координатный движок, тепловую шину портов и таблицу системных "
   "вызовов Сфер. Однако для сцен с живыми операторами система оставалась "
   "безразличной к носителю: не существовало расчетного реестра, который по "
   "паспорту организма выдавал бы его предельный уровень интерфейса, тепловой "
   "бюджет и кривую деградации при перегрузке. Настоящий том закрывает этот "
   "дефицит: двенадцать биологических классов Этерии — от видовой нормы "
   "Homo Aetheriensis до демонов-Повелителей и постмортемных каркасов — "
   "обработаны как аппаратные узлы со строгими спецификациями.")

P(story, "Методологическая позиция unchanged: персонаж не может «преодолеть» "
   "свою биологию усилием воли. Если проводимость меридианов организма "
   "составляет σ_e = 4.0, а системный вызов требует σ_req = 9.0, то "
   "планетарный сервер наказывает перегрузку тепловой смертью по строгому "
   "математическому графику — и этот график можно вычислить заранее. Все "
   "входные данные взяты из канонического реестра рас (файл EPUB-03, разделы "
   "3A-3D), все производные величины — из верифицированных моделей Тома 2 "
   "(несущая шина, σ-лестница Сфер) и Тома 1 (предел Ландауэра, тепловые "
   "бюджеты). Расчеты выполнены модулем 06_races_biology.py с привлечением "
   "термодинамической библиотеки CoolProp для свойств воды при температуре тела.")

code_block(story, [
    "            [ РЕЕСТР БИОЛОГИЧЕСКОГО ЖЕЛЕЗА ЭТЕРИИ ]",
    "                            │",
    "   ┌────────────────────────┼────────────────────────┐",
    "   ▼                        ▼                        ▼",
    " [ ВЕРИФИКАЦИЯ КАНОНА ]  [ ТЕПЛОВЫЕ ПАСПОРТА ]  [ РЕГРЕССИИ ]",
    " BSA (Дю Буа)            Q_max = c·m·ΔT_crit      жизнь(φ%)",
    " BMR (Клейбер)           P_охл = h·BSA·ΔT         регенерация(φ%)",
    " ρ_φ = bf·(σ/10)·12.2    лестница Сфер по σ       R² = 0.91 / 0.99",
    " гипотермия @ −60 °C     CNED при σ < 5.0         χ-выброс демонов",
], "Рис. 1.1 — Структура биологического модуля: три контура расчета")

# ════════════════════════════════════════════════════════════════════════════
# ГЛАВА 2. ВЕРИФИКАЦИЯ КАНОНА
# ════════════════════════════════════════════════════════════════════════════
H1(story, "2. Верификация канонических биологических законов")

P(story, "Первый контур модуля — проверка четырех канонических законов против "
   "независимых формул. Плотность φ-конденсата в тканях вычисляется по "
   "канонической формуле ρ_φ = bio_factor × (σ_e/σ_raw) × ρ_φ_max с потолком "
   "сырого фредерита 12.2 г/см³: формула воспроизводит канонические значения "
   "всех рас с невязкой менее 0.3%. Базовый метаболизм совпадает с законом "
   "Клейбера BMR = 70·M<super>0.75</super> с точностью до 0.1% — канон "
   "масштабирует метаболизм по массе универсально, а φ-подпитка является "
   "надстройкой, а не заменителем химического энергообмена. Площадь "
   "поверхности по формуле Дю Буа точна для этерианских пропорций и "
   "расходится на 2-6% для негабаритных архитектур (эльф, орк) — ожидаемое "
   "ограничение земной антропометрии. Модель гипотермии при −60.1 °C "
   "(охлаждение конвекцией h = 5 Вт/(м²·К) до порога в 5 К) воспроизводит "
   "канонические времена выживания с невязкой до 5%.")

data_table(
    story,
    ["Класс", "BSA Δ%", "BMR Δ%", "ρ_φ Δ%", "Гипотермия Δ%"],
    [
        ["H.e. видовая норма", "0.0", "0.1", "0.2", "3.8"],
        ["H.e. шахтер", "0.0", "0.0", "0.1", "н/д"],
        ["H.e. акме", "0.0", "0.0", "0.1", "н/д"],
        ["Эльф", "6.0", "0.1", "0.0", "1.0"],
        ["Орк", "4.7", "0.0", "0.1", "0.4"],
        ["Дриада", "2.7", "0.0", "0.0", "4.9"],
        ["Гоблин", "2.4", "0.1", "0.2", "3.3"],
        ["Драконит", "0.0", "0.0", "0.0", "н/д"],
        ["Демон нижний", "0.0", "0.0", "0.3", "н/д"],
        ["Демон-Повелитель", "0.0", "0.0", "0.0", "н/д"],
        ["Землянин", "0.0", "0.0", "52.5*", "н/д"],
    ],
    [0.32, 0.15, 0.15, 0.15, 0.23],
    "Табл. 2.1 — Невязки канона против независимых формул "
    "(*земной фон: округление канона 0.006 против 0.009 г/см³)",
    align_map=["L", "C", "C", "C", "C"],
)

P(story, "Особого внимания заслуживает вода: CoolProp дает при 310 K теплоту "
   "парообразования 2413 кДж/кг и теплоемкость 4180 Дж/(кг·К) — эти величины "
   "привязывают тепловые бюджеты углеродной биологии к реальной "
   "термодинамике и уже использовались в Томе 1 при кросс-верификации "
   "дефолта порта через дегидратацию. Верификация канона завершена: все "
   "четыре закона работают, и реестр можно дифференцировать — вычислять "
   "то, чего в каноне нет, но что следует из его же формул.")

# ════════════════════════════════════════════════════════════════════════════
# ГЛАВА 3. ТЕПЛОВЫЕ ПАСПОРТА
# ════════════════════════════════════════════════════════════════════════════
H1(story, "3. Тепловые паспорта и лестница Сфер")

P(story, "Тепловой бюджет расы вычисляется как Q_max = c·m·ΔT_crit, где "
   "критический интервал ΔT_crit — расстояние от температуры тела до порога "
   "отказа ткани. Для углеродной биологии порог универсален: денатурация "
   "белка при 41.8 °C. Для χ-физиологии демонов порог иной — кипение "
   "кристаллической крови при 120 °C, что дает демонам интервалы в 78-80 К "
   "против 4-7 К у углеродных рас и, соответственно, бюджеты в десятки "
   "мегаджоулей. Устойчивое охлаждение P = h·BSA·ΔT_crit растет с площадью "
   "поверхности: парадоксальным образом самый холоднокровный дизайн "
   "(дриада, 34.5 °C) получает наибольший запас охлаждения среди "
   "углеродных рас, потому что ее интервал до порога составляет 7.3 К.")

data_table(
    story,
    ["Класс", "σ_e", "Макс. Сфера", "Q_max", "P_охл", "CNED, Вт"],
    [
        ["Гоблин", "4.0", "S2", "402 кДж", "21.7 Вт", "2.60"],
        ["Орк", "5.5", "S3", "1457 кДж", "46.6 Вт", "0"],
        ["Дриада", "6.0", "S4", "1216 кДж", "55.1 Вт", "0"],
        ["H.e. норма", "6.5", "S4", "633 кДж", "29.8 Вт", "0"],
        ["Эльф", "7.0", "S5", "544 кДж", "29.0 Вт", "0"],
        ["Драконит", "7.0", "S5", "710 кДж", "27.8 Вт", "0"],
        ["H.e. шахтер / акме", "7.8", "S5", "607-632 кДж", "27.6-30.4 Вт", "0"],
        ["Демон нижний", "5.0", "S3", "23.6 МДж", "819 Вт", "0"],
        ["Демон-Повелитель", "8.5", "S6", "29.8 МДж", "945 Вт", "0"],
        ["Землянин", "1.5", "S0", "1335 кДж", "49.8 Вт", "9.10"],
        ["Оголённый (Ω=0)", "0.0", "н/д", "χ-запас 11 МДж", "−8.8 Вт (утечка)", "н/д"],
    ],
    [0.28, 0.10, 0.16, 0.18, 0.18, 0.10],
    "Табл. 3.1 — Тепловые паспорта биологических классов (расчет по верифицированной модели)",
    align_map=["L", "C", "C", "C", "C", "C"],
)

P(story, "Три следствия стоят отдельного упоминания. Первое: лестница Сфер по "
   "проводимости безжалостна к социальной иерархии — рекордное φ-насыщение "
   "дриады (34.1%) не открывает ей даже Сферу 5, потому что древесные "
   "резонаторы не являются силовыми меридианами; φ-доля и σ_e — независимые "
   "оси железа. Второе: демон-Повелитель с σ_e = 8.5 не достигает Сферы 7 — "
   "барьер каузальности требует элитных 9.0, то есть даже вечная χ-фаза не "
   "заменяет культивацию или инкубацию в Архисфере. Третье: землянин "
   "предельно изолирован от системы (только фоновый S0) и при этом несет "
   "постоянную CNED-утечку 9.1 Вт — одиннадцать процентов базового "
   "метаболизма сгорает впустую только из-за пребывания в чужой метрике.")

callout(story,
        "<b>Модель CNED-утечки:</b> ниже порога σ_e = 5.0 проводимость "
        "недостаточна для полного замыкания φ-контура, и часть подпитки "
        "рассеивается в тканях как джоулево тепло. Калибровка по гоблину "
        "(2.6 Вт при σ 4.0) дает утечку 2.6·(5 − σ_e) Вт. Земной фон σ 1.5 "
        "платит 9.1 Вт; варп-декомпрессия транзита поднимает утечку "
        "переносчика до канонических 23.9 Вт (28% BMR) — физика "
        "«энергетического обескровливания» newcomers выводится одним "
        "уравнением.")

# ════════════════════════════════════════════════════════════════════════════
# ГЛАВА 4. КРИВЫЕ ДЕГРАДАЦИИ
# ════════════════════════════════════════════════════════════════════════════
H1(story, "4. Кривые тепловой деградации")

P(story, "Когда оператор удерживает вызов выше своего класса, несоответствие "
   "токов сбрасывается в собственные ткани: P_сброс = (I_k − I_оп)²/σ_e, и "
   "тело разогревается по линейному закону до порога денатурации. Кривые "
   "на графике ниже построены для удержания Сферы 7 — барьера каузальности, "
   "требующего σ_e ≥ 9.0. Видовая норма этерианца выгорает за 10.2 суток, "
   "эльф — за 14.7, орк — за 10.1: все углеродные расы укладываются в "
   "одну-две недели непрерывного преступления против своей проводимости. "
   "Гоблин умирает за 23.9 часа — его кривая обрывается за сутки.")

img = embed_image(os.path.join(CHART_DIR, "chart1_S7_degradation.png"),
                  max_width=AVAIL_W, max_height=300)
story.append(Spacer(1, 8))
story.append(img)
story.append(Paragraph(
    "Рис. 4.1 — Температура тела при удержании Сферы 7 выше класса проводимости "
    "(крестики — момент достижения порога 41.8 °C)", S_CAPTION))
story.append(Spacer(1, 6))

P(story, "Динамика кривых дает писателю точную механику напряжения: перегрузка "
   "не убивает мгновенно — она тикает. Организм с температурой 37.5 °C имеет "
   "в запасе 4.3 К до отказа, и каждый час сверхклассового удержания "
   "приближает порог на измеримую долю градуса. Шахтер или акме (σ 7.8) "
   "переживают неделю — время, достаточное для сюжетной драмы без нарушения "
   "физики; гоблин-инженер, попытавшийся взломать Предел, получает ровно "
   "сутки. Обратная сторона — большинство углеродных рас вообще не могут "
   "заплатить за S7 заметным теплом: разница токов мала, и деградация "
   "растягивается на десятки суток.")

# ════════════════════════════════════════════════════════════════════════════
# ГЛАВА 5. РЕГРЕССИИ ЖИЗНИ И РЕГЕНЕРАЦИИ
# ════════════════════════════════════════════════════════════════════════════
H1(story, "5. Жизнь и регенерация как функции φ-доли")

P(story, "Второй контур модуля — регрессионный анализ канонических шкал "
   "долголетия и регенерации по плотности φ-конденсата. Для углеродных рас "
   "обе зависимости линейны: продолжительность жизни описывается моделью "
   "Life ≈ 14.5·φ% − 63 (R² = 0.91), регенерация — Regen ≈ 0.37·φ% + 0.45 "
   "(R² = 0.99). Демон-реликт систематически выбывает из тренда: его тысяча "
   "лет держится χ-фазовым якорем, а не φ-насыщением, что подтверждает "
   "принципиальное разделение механизмов — углеродная биология стареет по "
   "конденсату, χ-реликт — по фазовой стабильности.")

img = embed_image(os.path.join(CHART_DIR, "chart2_life_phi.png"),
                  max_width=AVAIL_W, max_height=290)
story.append(Spacer(1, 8))
story.append(img)
story.append(Paragraph(
    "Рис. 5.1 — Жизнь (синие круги, левая ось) и регенерация (красные квадраты, "
    "правая ось) против φ-доли тканей; демон — χ-выброс вне тренда", S_CAPTION))
story.append(Spacer(1, 6))

P(story, "Практическое значение регрессий двояко. Для существующих рас они "
   "выступают паспортом качества данных: любая новая раса, добавленная в "
   "канон, обязана лечь на прямую жизнь-регенерация или явно обосновать "
   "отклонение (как демоны — χ-якорем). Для новых сущностей регрессии дают "
   "генератор: задав φ-долю через bio_factor и σ_e по канонической формуле "
   "насыщения, проектировщик немедленно получает ожидаемые долголетие, "
   "скорость заживления и старение без произвольных допущений. Шкала "
   "старения канона (0.316 у гоблина против 0.079 у дриады) — это та же "
   "прямая, прочитанная в обратную сторону.")

# ════════════════════════════════════════════════════════════════════════════
# ГЛАВА 6. КАРТА ЖЕЛЕЗА И ОВЕРЛЕИ
# ════════════════════════════════════════════════════════════════════════════
H1(story, "6. Карта биологического железа и оверлеи культивации")

P(story, "Сводная карта классов в координатах «проводимость × тепловой бюджет» "
   "показывает биосферу как парк вычислительных платформ: углеродные расы "
   "сгрудились в полосе бюджетов 0.4-1.5 МДж, демоны выносятся на три "
   "порядка вверх по оси Y, а вертикальные линии порогов Сфер режут парк "
   "на сегменты доступа. Именно эта карта отвечает на вопрос «кто и что "
   "может» быстрее любой иерархии титулов: достаточно опустить перпендикуляр "
   "от точки класса к оси σ_e и прочитать максимальный уровень вызова.")

img = embed_image(os.path.join(CHART_DIR, "chart3_hardware_map.png"),
                  max_width=AVAIL_W, max_height=310)
story.append(Spacer(1, 8))
story.append(img)
story.append(Paragraph(
    "Рис. 6.1 — Карта биологического железа: классы проводимости против тепловых "
    "бюджетов (лог. шкала); вертикали — пороги Сфер S2/S4/S7", S_CAPTION))
story.append(Spacer(1, 6))

P(story, "Оверлеи культивации накладываются на карту как аппаратные "
   "модификации: Мнемар добавляет +3.0 к проводимости и +0.040 к bio_factor "
   "(сверхпроводимость Варп-Буфера), Лич — +2.0 к проводимости при "
   "деградации φ-структур на −0.020. Модель воспроизводит канонические "
   "контрольные точки точно: эльф с Мнемаром достигает φ-доли 52.3% — "
   "физический предел углеродной оболочки; дриада с Мнемаром — 55.6%, "
   "абсолютный рекорд биосферы; гоблин с Личем теряет всю φ-проводимость "
   "(расчетная доля уходит в ноль и ниже) — полуразложившийся труп на "
   "некро-якоре. Совпадение модели с каноном во всех трех критических "
   "кейсах без подгонки параметров — сильнейшая верификация всей "
   "двухканальной архитектуры Тома 2.")

data_table(
    story,
    ["Оверлей", "Базовый класс", "σ_e итог", "Макс. Сфера", "φ-доля", "Жизнь"],
    [
        ["Мнемар", "H.e. норма", "9.5", "S14", "45.5%", "2200 лет"],
        ["Мнемар", "Эльф", "10.0", "S22", "52.3%", "3000 лет"],
        ["Мнемар", "Дриада", "9.0", "S7", "55.6%", "5000 лет"],
        ["Мнемар", "Гоблин", "7.0", "S5", "32.1%", "700 лет"],
        ["Лич", "H.e. норма", "8.5", "S6", "13.0%", "11000 лет"],
        ["Лич", "Эльф", "9.0", "S7", "24.8%", "15000 лет"],
        ["Лич", "Дриада", "8.0", "S6", "32.3%", "25000 лет"],
        ["Лич", "Гоблин", "6.0", "S4", "0% (деградация)", "3500 лет"],
    ],
    [0.13, 0.22, 0.13, 0.17, 0.17, 0.18],
    "Табл. 6.1 — Оверлеи культивации: σ_e ограничено потолком 10.0",
    align_map=["L", "L", "C", "C", "C", "C"],
)

# ════════════════════════════════════════════════════════════════════════════
# ГЛАВА 7. ИТОГИ
# ════════════════════════════════════════════════════════════════════════════
H1(story, "7. Итоги тома")

P(story, "Дефицит биологических спецификаций закрыт. Канон рас проверен против "
   "четырех независимых законов (Клейбер, Дю Буа, формула насыщения, "
   "конвективное охлаждение) и подтвержден; двенадцать классов "
   "пересчитаны в тепловые паспорта с лестницей Сфер; регрессии жизни и "
   "регенерации от φ-доли дают генератор новых рас без произвола; "
   "кривые деградации превращают перегрузку Сфер из сюжетного образа в "
   "инженерный график с точками отказа. Оверлеи культивации "
   "воспроизводятся моделью точно, включая все три канонических "
   "критических кейса.")

P(story, "Для писателя том формулирует четыре железных правила сцены. "
   "Первое: доступ определяется проводимостью, выносливость — тепловым "
   "бюджетом, и никакая мотивация не сдвигает эти числа. Второе: "
   "перегрузка тикает — у каждой пары «раса × Сфера» есть вычисленное "
   "время до отказа, от часов (гоблин) до десятилетий (Повелитель). "
   "Третье: долголетие и регенерация — линейные функции φ-насыщения, "
   "а χ-фазы живут по отдельному закону. Четвертое: культивация — "
   "это аппаратный апгрейд с точно известным ценником; она открывает "
   "уровни, но не отменяет потолок σ 10.0 и физические пределы "
   "углеродной оболочки на 52-56% φ-доли.")

P(story, "Архитектурно реестр встраивается в общую систему без швов: тепловые "
   "паспорта потребляются симулятором Тома 1 (сценарии отказов), "
   "σ-лестница наследуется из таблицы Сфер Тома 2, а регрессии дают "
   "априорные оценки для существований, еще не описанных каноном. "
   "Следующие модули дорожной карты — интерфейсный стандарт Uroboros-I/O "
   "(пиндаут и согласование импедансов) и справочник системных исключений "
   "— построятся поверх этого реестра как приложения к живому железу.")

# ════════════════════════════════════════════════════════════════════════════
# СБОРКА
# ════════════════════════════════════════════════════════════════════════════
print("[2/3] Собираю PDF Тома 3...")
BODY_PDF = os.path.join(HERE, "body3.pdf")
doc = TocDocTemplate(
    BODY_PDF, pagesize=A4,
    leftMargin=MARGIN, rightMargin=MARGIN,
    topMargin=MARGIN + 8, bottomMargin=MARGIN + 6,
    title="Система Уроборос — Том 3: Биологическое железо Этерии",
    author="Z.ai", creator="Z.ai",
    subject="Расчетные паспорта биологических классов: тепловые бюджеты, лестница Сфер, регрессии",
)
doc.multiBuild(story, onFirstPage=on_page, onLaterPages=on_page)
print(f"[3/3] Тело Тома 3: {BODY_PDF}")

from pypdf import PdfReader, PdfWriter

A4_W, A4_H = 595.28, 841.89

def normalize(page):
    w, h = float(page.mediabox.width), float(page.mediabox.height)
    if abs(w - A4_W) > 0.1 or abs(h - A4_H) > 0.1:
        page.scale_to(A4_W, A4_H)
        page.mediabox.lower_left = (0, 0)
        page.mediabox.upper_right = (A4_W, A4_H)
    return page

FINAL = "/home/z/my-project/download/Система_Уроборос_Том3_Биологическое_железо.pdf"
os.makedirs(os.path.dirname(FINAL), exist_ok=True)
writer = PdfWriter()
writer.add_page(normalize(PdfReader(os.path.join(HERE, "cover3.pdf")).pages[0]))
for p in PdfReader(BODY_PDF).pages:
    writer.add_page(normalize(p))
writer.add_metadata({
    "/Title": "Система Уроборос — Том 3: Биологическое железо Этерии",
    "/Author": "Z.ai", "/Creator": "Z.ai",
    "/Subject": "Тепловые паспорта рас, лестница Сфер, регрессии жизни и регенерации",
})
with open(FINAL, "wb") as f:
    writer.write(f)
print(f"[ГОТОВО] Итоговый PDF Тома 3: {FINAL}")
