"""Build the production (pre-diploma) practice report .docx
following МФЮА formatting requirements (the same as for the thesis).

Output: build/otchet_praktika_fast_engineering.docx
"""

from __future__ import annotations

from pathlib import Path

import build_docx as bd


PRACTICE_DIR = Path(__file__).resolve().parent.parent / "practice"
OUTPUT_PATH = bd.BUILD_DIR / "otchet_praktika_fast_engineering.docx"


PRACTICE_FILES_IN_ORDER = [
    "00_titulnyi_list.md",
    "01_zadanie.md",
    "02_dnevnik.md",
    "03_vvedenie.md",
    "04_osnovnaya_chast.md",
    "05_zaklyuchenie.md",
    "06_prilozheniya.md",
    "07_harakteristika.md",
]


def main() -> None:
    bd.BUILD_DIR.mkdir(parents=True, exist_ok=True)

    from docx import Document

    document = Document()
    bd.set_default_style(document)
    bd.set_page_layout(document)

    for fname in PRACTICE_FILES_IN_ORDER:
        path = PRACTICE_DIR / fname
        if not path.exists():
            continue
        bd.render_markdown_file(document, path)

    bd.add_page_numbers(document)
    bd.hide_first_page_number(document)

    document.save(OUTPUT_PATH)
    size_kb = OUTPUT_PATH.stat().st_size / 1024
    print(f"Wrote {OUTPUT_PATH} ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
