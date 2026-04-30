"""Локальный анализ оригинальности и AI-маркеров.

Работает только с текстами в репозитории (без выхода во внешние сервисы):

1) Перекрёстный n-gram анализ между ВКР (`thesis/`) и отчётом
   по преддипломной практике (`practice/otchet.md`):
   ищем shingles длиной N=8 слов и считаем долю совпадений
   относительно общего числа shingles в каждом из документов.

2) Частотный анализ типичных AI-/«канцелярских»-клише, по которым
   преподаватели и рецензенты обычно опознают тексты, написанные
   языковыми моделями. Считаем долю предложений с подобными оборотами.

Этот анализ НЕ заменяет проверку в «Антиплагиат.ВУЗ»: он позволяет
до сдачи увидеть, какие фрагменты будут совпадать у самого студента
между двумя его работами и где сосредоточены AI-маркеры.
"""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parent.parent
THESIS_FILES = sorted((REPO_ROOT / "thesis").glob("*.md"))
PRACTICE_FILE = REPO_ROOT / "practice" / "otchet.md"

SHINGLE_LEN = 8


AI_MARKERS = [
    r"\bтаким образом\b",
    r"\bследует отметить\b",
    r"\bв то же время\b",
    r"\bв целом\b",
    r"\bв частности\b",
    r"\bкак правило\b",
    r"\bв конечном (?:итоге|счёте)\b",
    r"\bстоит подчеркнуть\b",
    r"\bнеобходимо подчеркнуть\b",
    r"\bкак отмечалось ранее\b",
    r"\bв рамках настоящ\w+\b",
    r"\bпринципиально важн\w+\b",
    r"\bдостаточно очевидн\w+\b",
    r"\bочевидн\w*, что\b",
    r"\bв соответствии с\b",
    r"\bна основании\b",
    r"\bпредставляется целесообразным\b",
    r"\bцелесообразн\w+\b",
    r"\bобуславлива\w+\b",
    r"\bсовокупность\b",
    r"\bкомплексн\w+ подход\w*\b",
    r"\bустойчив\w+ положени\w+\b",
    r"\bустойчивого формирования\b",
    r"\bв обобщённом виде\b",
    r"\bв ходе настоящ\w+ работ\w+\b",
    r"\bвместе с тем\b",
    r"\bпри этом\b",
    r"\bтем самым\b",
    r"\bпрактическ\w+ реализаци\w+\b",
    r"\bв условиях цифровизации\b",
    r"\bкоммуникативн\w+ воронк\w+\b",
    r"\bв рамках настоящ\w+ дипломн\w+ работ\w+\b",
]


def normalize(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[«»\"'`„“”]", "", text)
    text = re.sub(r"[\-–—]", " ", text)
    text = re.sub(r"[^a-zа-яё0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def words(text: str) -> list[str]:
    return [w for w in normalize(text).split() if len(w) > 1]


def shingles(words_list: list[str], n: int = SHINGLE_LEN) -> set[tuple[str, ...]]:
    return {tuple(words_list[i : i + n]) for i in range(len(words_list) - n + 1)}


def read_concat(paths: Iterable[Path]) -> str:
    return "\n".join(p.read_text(encoding="utf-8") for p in paths if p.exists())


def split_sentences(text: str) -> list[str]:
    text = re.sub(r"\s+", " ", text)
    parts = re.split(r"(?<=[.!?])\s+", text)
    return [p.strip() for p in parts if p.strip()]


def analyze_overlap(thesis_text: str, practice_text: str) -> dict[str, float | int]:
    thesis_words = words(thesis_text)
    practice_words = words(practice_text)

    thesis_sh = shingles(thesis_words)
    practice_sh = shingles(practice_words)

    common = thesis_sh & practice_sh

    return {
        "thesis_words": len(thesis_words),
        "practice_words": len(practice_words),
        "thesis_shingles": len(thesis_sh),
        "practice_shingles": len(practice_sh),
        "common_shingles": len(common),
        "thesis_overlap_pct": (len(common) / len(thesis_sh) * 100) if thesis_sh else 0.0,
        "practice_overlap_pct": (len(common) / len(practice_sh) * 100) if practice_sh else 0.0,
    }


def find_overlapping_passages(
    thesis_text: str, practice_text: str, min_run_words: int = 12
) -> list[str]:
    """Найти длинные дословные совпадения (>= min_run_words слов подряд)."""
    a_words = words(thesis_text)
    b_words = words(practice_text)
    a_set_index: dict[tuple[str, ...], list[int]] = {}
    n = SHINGLE_LEN
    for i in range(len(a_words) - n + 1):
        key = tuple(a_words[i : i + n])
        a_set_index.setdefault(key, []).append(i)

    found_runs: list[tuple[int, int, int]] = []
    seen_a_starts: set[int] = set()
    i = 0
    while i < len(b_words) - n + 1:
        key = tuple(b_words[i : i + n])
        if key in a_set_index:
            for a_start in a_set_index[key]:
                if a_start in seen_a_starts:
                    continue
                run = n
                while (
                    a_start + run < len(a_words)
                    and i + run < len(b_words)
                    and a_words[a_start + run] == b_words[i + run]
                ):
                    run += 1
                if run >= min_run_words:
                    found_runs.append((a_start, i, run))
                    seen_a_starts.add(a_start)
                    i += run - 1
                    break
        i += 1

    snippets = []
    for a_start, b_start, run in sorted(found_runs, key=lambda x: -x[2])[:25]:
        snippet = " ".join(b_words[b_start : b_start + run])
        snippets.append(f"[{run} слов] {snippet[:240]}{'…' if len(snippet) > 240 else ''}")
    return snippets


def analyze_ai_markers(text: str, name: str) -> dict[str, object]:
    sentences = split_sentences(text)
    total_sentences = len(sentences)
    total_words = len(words(text))
    counts: Counter = Counter()
    flagged_sentences: set[int] = set()

    for pat in AI_MARKERS:
        rgx = re.compile(pat, re.IGNORECASE)
        for idx, sent in enumerate(sentences):
            if rgx.search(sent):
                counts[pat] += 1
                flagged_sentences.add(idx)

    return {
        "name": name,
        "total_words": total_words,
        "total_sentences": total_sentences,
        "flagged_sentences": len(flagged_sentences),
        "flagged_pct": (
            len(flagged_sentences) / total_sentences * 100 if total_sentences else 0.0
        ),
        "top": counts.most_common(15),
    }


def main() -> None:
    thesis_text = read_concat(THESIS_FILES)
    practice_text = PRACTICE_FILE.read_text(encoding="utf-8") if PRACTICE_FILE.exists() else ""

    print("=" * 78)
    print("ВКР vs ОТЧЁТ ПО ПРАКТИКЕ — ДУБЛИРОВАНИЕ ТЕКСТА (shingles, n=8 слов)")
    print("=" * 78)
    o = analyze_overlap(thesis_text, practice_text)
    print(f"  ВКР:      {o['thesis_words']:>7} слов / {o['thesis_shingles']:>7} shingles")
    print(f"  Отчёт:    {o['practice_words']:>7} слов / {o['practice_shingles']:>7} shingles")
    print(f"  Общих shingles: {o['common_shingles']}")
    print(
        f"  Доля совпадений в ВКР:    {o['thesis_overlap_pct']:.2f}%  "
        f"(сколько ВКР повторяется в отчёте)"
    )
    print(
        f"  Доля совпадений в отчёте: {o['practice_overlap_pct']:.2f}%  "
        f"(сколько отчёта повторяется в ВКР)"
    )
    print()

    print("Самые длинные дословные совпадения (топ-25 по длине):")
    for s in find_overlapping_passages(thesis_text, practice_text, min_run_words=15):
        print(f"  • {s}")
    print()

    print("=" * 78)
    print("AI-/КАНЦЕЛЯРСКИЕ МАРКЕРЫ")
    print("=" * 78)
    for label, txt in [("ВКР", thesis_text), ("Отчёт", practice_text)]:
        a = analyze_ai_markers(txt, label)
        print(
            f"  {a['name']}: предложений {a['total_sentences']}, "
            f"с маркерами {a['flagged_sentences']} "
            f"({a['flagged_pct']:.1f}%)"
        )
        for pat, cnt in a["top"]:
            human = pat.replace(r"\b", "").replace(r"\w+", "…")
            print(f"      • {human}: {cnt}")
        print()


if __name__ == "__main__":
    main()
