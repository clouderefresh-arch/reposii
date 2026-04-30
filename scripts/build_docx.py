"""Build the diploma .docx from Markdown sources following МФЮА formatting requirements.

Formatting (per methodical recommendations, section 8):
- Times New Roman, size 14, line spacing 1.5.
- Page margins: top 20 mm, bottom 20 mm, left 30 mm, right 10 mm.
- Paragraph alignment: justify; first-line indent 1.25 cm.
- Page numbering: arabic, continuous; centered at the bottom; not shown on the title page.
- Structural element headings (ОГЛАВЛЕНИЕ, ВВЕДЕНИЕ, chapter names, ЗАКЛЮЧЕНИЕ,
  СПИСОК ИСПОЛЬЗОВАННЫХ ИСТОЧНИКОВ, ПРИЛОЖЕНИЯ) — uppercase, centered, on new page.
- Subsection headings — sentence case, paragraph indent.
"""

from __future__ import annotations

import re
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.shared import Cm, Mm, Pt


THESIS_DIR = Path(__file__).resolve().parent.parent / "thesis"
BUILD_DIR = Path(__file__).resolve().parent.parent / "build"
OUTPUT_PATH = BUILD_DIR / "diplom_fast_engineering.docx"


STRUCTURAL_HEADINGS = {
    "ОГЛАВЛЕНИЕ",
    "ВВЕДЕНИЕ",
    "ЗАКЛЮЧЕНИЕ",
    "СПИСОК ИСПОЛЬЗОВАННЫХ ИСТОЧНИКОВ",
    "ПРИЛОЖЕНИЯ",
}


FILES_IN_ORDER = [
    "00_titulnyi_list.md",
    "01_zadanie.md",
    "02_kalendarnyi_plan.md",
    "03_oglavlenie.md",
    "04_vvedenie.md",
    "05_glava_1.md",
    "06_glava_2.md",
    "07_glava_3.md",
    "08_zaklyuchenie.md",
    "09_spisok_istochnikov.md",
    "10_prilozheniya.md",
]


def set_default_style(document: Document) -> None:
    style = document.styles["Normal"]
    font = style.font
    font.name = "Times New Roman"
    font.size = Pt(14)
    rpr = style.element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        rfonts.set(qn(attr), "Times New Roman")
    pf = style.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(0)
    pf.space_after = Pt(0)
    pf.first_line_indent = Cm(1.25)
    pf.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY


def set_page_layout(document: Document) -> None:
    section = document.sections[0]
    section.top_margin = Mm(20)
    section.bottom_margin = Mm(20)
    section.left_margin = Mm(30)
    section.right_margin = Mm(10)


def add_page_numbers(document: Document) -> None:
    for section in document.sections:
        footer = section.footer
        footer.is_linked_to_previous = False
        para = footer.paragraphs[0]
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        para.text = ""
        run = para.add_run()
        fld_begin = OxmlElement("w:fldChar")
        fld_begin.set(qn("w:fldCharType"), "begin")
        instr = OxmlElement("w:instrText")
        instr.set(qn("xml:space"), "preserve")
        instr.text = "PAGE   \\* MERGEFORMAT"
        fld_end = OxmlElement("w:fldChar")
        fld_end.set(qn("w:fldCharType"), "end")
        run._r.append(fld_begin)
        run._r.append(instr)
        run._r.append(fld_end)
        rpr = run._r.get_or_add_rPr()
        rfonts = OxmlElement("w:rFonts")
        for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
            rfonts.set(qn(attr), "Times New Roman")
        rpr.append(rfonts)
        sz = OxmlElement("w:sz")
        sz.set(qn("w:val"), "28")
        rpr.append(sz)


def hide_first_page_number(document: Document) -> None:
    """The title page is the first page; per methodology, the page number
    is included in the overall numbering but is NOT shown on the title page.
    We achieve this by enabling 'different first page' on the first section
    and leaving its first-page footer empty.
    """
    section = document.sections[0]
    sect_pr = section._sectPr
    title_pg = sect_pr.find(qn("w:titlePg"))
    if title_pg is None:
        title_pg = OxmlElement("w:titlePg")
        sect_pr.append(title_pg)
    first_footer = section.first_page_footer
    first_footer.is_linked_to_previous = False
    if not first_footer.paragraphs:
        first_footer.add_paragraph("")
    else:
        first_footer.paragraphs[0].text = ""


def add_paragraph(document: Document, text: str, *, style: str = "body") -> None:
    """Add a paragraph with the requested style.

    Styles:
    - 'body'     - Justified, indent 1.25 cm.
    - 'h_struct' - Uppercase, centered, no indent, page break before.
    - 'h_chapter'- Uppercase chapter title, centered, no indent, page break before.
    - 'h_section'- Subsection (e.g. "1.1. ..."), bold, indent 1.25 cm, justified.
    - 'h_subsec' - Sub-subsection (e.g. "3.3.1."), italic, indent 1.25 cm, justified.
    - 'plain'    - Like body but no first-line indent (used for tables/captions).
    - 'caption'  - Centered, bold, no indent, used for table/figure captions.
    - 'list'     - Justified, hanging-style list item.
    """
    para = document.add_paragraph()
    run = para.add_run(text)
    run.font.name = "Times New Roman"
    run.font.size = Pt(14)
    rfonts = run._element.get_or_add_rPr().find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        run._element.get_or_add_rPr().append(rfonts)
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        rfonts.set(qn(attr), "Times New Roman")

    pf = para.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(0)
    pf.space_after = Pt(0)

    if style == "body":
        pf.first_line_indent = Cm(1.25)
        para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    elif style == "plain":
        pf.first_line_indent = Cm(0)
        para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    elif style == "h_struct":
        pf.first_line_indent = Cm(0)
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run.bold = True
        pf.page_break_before = True
    elif style == "h_chapter":
        pf.first_line_indent = Cm(0)
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run.bold = True
        pf.page_break_before = True
    elif style == "h_section":
        pf.first_line_indent = Cm(1.25)
        para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        run.bold = True
    elif style == "h_subsec":
        pf.first_line_indent = Cm(1.25)
        para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        run.italic = True
    elif style == "caption":
        pf.first_line_indent = Cm(0)
        para.alignment = WD_ALIGN_PARAGRAPH.LEFT
        run.bold = True
    elif style == "list":
        pf.first_line_indent = Cm(0)
        pf.left_indent = Cm(1.25)
        para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    else:
        pf.first_line_indent = Cm(1.25)
        para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY


def render_table(document: Document, header: list[str], rows: list[list[str]]) -> None:
    table = document.add_table(rows=1 + len(rows), cols=len(header))
    table.style = "Table Grid"
    hdr_cells = table.rows[0].cells
    for i, h in enumerate(header):
        hdr_cells[i].text = ""
        p = hdr_cells[i].paragraphs[0]
        run = p.add_run(h)
        run.bold = True
        run.font.name = "Times New Roman"
        run.font.size = Pt(12)
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for r, row in enumerate(rows, start=1):
        for c, val in enumerate(row):
            cell = table.rows[r].cells[c]
            cell.text = ""
            p = cell.paragraphs[0]
            run = p.add_run(val)
            run.font.name = "Times New Roman"
            run.font.size = Pt(12)
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT


# ---------------- Markdown parser (subset suitable for our files) ----------------


def parse_markdown_inline(text: str) -> str:
    """Strip inline markdown that we cannot represent perfectly in plain runs.

    We keep the text and remove formatting markers so the resulting docx
    is readable. Bold/italic styling is not preserved at the inline level
    (only at heading level), to keep the parser simple and the visual
    result clean and consistent.
    """
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"\*\*([^\*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^\*]+)\*", r"\1", text)
    text = re.sub(r"_([^_]+)_", r"\1", text)
    text = re.sub(r"~~([^~]+)~~", r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", text)
    text = text.replace("\\,", ",").replace("\\%", "%")
    text = re.sub(r"\$\$([^$]+)\$\$", lambda m: _math_to_text(m.group(1)), text)
    text = re.sub(r"\$([^$]+)\$", lambda m: _math_to_text(m.group(1)), text)
    return text


def _math_to_text(expr: str) -> str:
    expr = expr.strip()
    expr = re.sub(r"\\frac\{([^{}]+)\}\{([^{}]+)\}", r"(\1) / (\2)", expr)
    expr = re.sub(r"\\text\{([^{}]+)\}", r"\1", expr)
    expr = re.sub(r"\\cdot", "·", expr)
    expr = re.sub(r"\\,", " ", expr)
    expr = re.sub(r"\\%", "%", expr)
    expr = re.sub(r"\\Pi", "П", expr)
    expr = re.sub(r"\\Delta", "Δ", expr)
    expr = re.sub(r"\\approx", "≈", expr)
    expr = re.sub(r"_\{([^{}]+)\}", r"_\1", expr)
    expr = re.sub(r"\\_", "_", expr)
    expr = expr.replace("\\\\", " ")
    return expr.strip()


def is_table_separator(line: str) -> bool:
    s = line.strip()
    if not s.startswith("|") or not s.endswith("|"):
        return False
    return all(re.match(r"^\s*:?-+:?\s*$", c) for c in s.strip("|").split("|"))


def parse_table_line(line: str) -> list[str]:
    cells = line.strip().strip("|").split("|")
    return [c.strip() for c in cells]


def render_markdown_file(document: Document, md_path: Path) -> None:
    raw = md_path.read_text(encoding="utf-8")
    lines = raw.splitlines()

    in_code = False
    in_blockquote = False
    in_table = False
    table_header: list[str] = []
    table_rows: list[list[str]] = []
    code_buffer: list[str] = []

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("```"):
            if not in_code:
                in_code = True
                code_buffer = []
            else:
                in_code = False
                add_paragraph(document, "\n".join(code_buffer), style="plain")
            i += 1
            continue
        if in_code:
            code_buffer.append(line)
            i += 1
            continue

        if stripped.startswith("|") and stripped.endswith("|"):
            if not in_table:
                if i + 1 < len(lines) and is_table_separator(lines[i + 1]):
                    in_table = True
                    table_header = parse_table_line(stripped)
                    table_rows = []
                    i += 2
                    continue
            else:
                if not is_table_separator(stripped):
                    table_rows.append([parse_markdown_inline(c) for c in parse_table_line(stripped)])
                    i += 1
                    continue
        if in_table and (not stripped.startswith("|") or not stripped.endswith("|")):
            render_table(document, table_header, table_rows)
            in_table = False
            table_header, table_rows = [], []

        if not stripped:
            i += 1
            continue

        if stripped.startswith("> "):
            text = parse_markdown_inline(stripped[2:].strip())
            add_paragraph(document, text, style="plain")
            i += 1
            continue

        if stripped.startswith("---"):
            i += 1
            continue

        if stripped.startswith("# "):
            heading = stripped[2:].strip()
            heading_upper = heading.upper()
            if heading_upper in STRUCTURAL_HEADINGS or heading_upper.startswith("ГЛАВА "):
                add_paragraph(document, heading_upper, style="h_chapter")
            elif heading.lower().startswith("титульный"):
                add_paragraph(document, heading_upper, style="h_struct")
            elif heading.lower().startswith("задание"):
                add_paragraph(document, heading_upper, style="h_struct")
            elif heading.lower().startswith("календарный"):
                add_paragraph(document, heading_upper, style="h_struct")
            else:
                add_paragraph(document, heading_upper, style="h_struct")
            i += 1
            continue

        if stripped.startswith("## "):
            heading = parse_markdown_inline(stripped[3:].strip())
            add_paragraph(document, heading, style="h_section")
            i += 1
            continue

        if stripped.startswith("### "):
            heading = parse_markdown_inline(stripped[4:].strip())
            add_paragraph(document, heading, style="h_subsec")
            i += 1
            continue

        if stripped.startswith(("- ", "* ")):
            text = parse_markdown_inline(stripped[2:].strip())
            add_paragraph(document, "• " + text, style="list")
            i += 1
            continue

        m = re.match(r"^(\d+)\)\s+(.*)", stripped)
        if m:
            text = parse_markdown_inline(stripped)
            add_paragraph(document, text, style="list")
            i += 1
            continue

        text = parse_markdown_inline(stripped)
        if text.startswith("Таблица") or text.startswith("Рисунок"):
            add_paragraph(document, text, style="caption")
        elif text.startswith("Источник:") or text.startswith("*Источник"):
            add_paragraph(document, text.lstrip("*").rstrip("*"), style="plain")
        else:
            add_paragraph(document, text, style="body")
        i += 1

    if in_table:
        render_table(document, table_header, table_rows)


def main() -> None:
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    document = Document()
    set_default_style(document)
    set_page_layout(document)

    for fname in FILES_IN_ORDER:
        path = THESIS_DIR / fname
        if not path.exists():
            continue
        render_markdown_file(document, path)

    add_page_numbers(document)
    hide_first_page_number(document)

    document.save(OUTPUT_PATH)
    size_kb = OUTPUT_PATH.stat().st_size / 1024
    print(f"Wrote {OUTPUT_PATH} ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
