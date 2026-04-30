"""Build the production (pre-diploma) practice report .docx
following МФЮА formatting requirements.

Output: build/otchet_praktika_fast_engineering.docx
"""

from __future__ import annotations

from pathlib import Path

import build_docx as bd


PRACTICE_DIR = Path(__file__).resolve().parent.parent / "practice"
OUTPUT_PATH = bd.BUILD_DIR / "otchet_praktika_fast_engineering.docx"


def main() -> None:
    bd.BUILD_DIR.mkdir(parents=True, exist_ok=True)

    from docx import Document

    document = Document()
    bd.set_default_style(document)
    bd.set_page_layout(document)

    bd.render_markdown_file(document, PRACTICE_DIR / "otchet.md")

    bd.add_page_numbers(document)

    document.save(OUTPUT_PATH)
    size_kb = OUTPUT_PATH.stat().st_size / 1024
    print(f"Wrote {OUTPUT_PATH} ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
