#!/usr/bin/env python3
"""Validate Google Play store listing texts.

Google Play counts *characters* (Unicode code points), not bytes, so this
script uses len() on decoded UTF-8 text. Limits:
    title.txt               <= 30
    short_description.txt   <= 80
    full_description.txt    <= 4000

Also rejects U+FE0F (emoji variation selector), emoji-range code points,
HTML tags and "best / #1 / free"-style claims in titles.

Usage:
    python3 store/listing/check_lengths.py            # table + checks
    python3 store/listing/check_lengths.py --markdown # Markdown table for README
Exit code 1 if any check fails.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIMITS = {"title.txt": 30, "short_description.txt": 80, "full_description.txt": 4000}
EXPECTED = ["en-US", "en-GB", "cs-CZ", "zh-CN", "hi-IN", "es-ES", "es-419", "fr-FR",
            "ar", "bn-BD", "pt-BR", "pt-PT", "ru-RU", "ur", "id"]
BANNED_TITLE = re.compile(r"\b(best|#1|no\.?\s*1|free|top|new)\b", re.IGNORECASE)
EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2600-\u27BF\uFE0F]")


def main() -> int:
    markdown = "--markdown" in sys.argv
    errors = []
    rows = []
    for loc in EXPECTED:
        d = os.path.join(HERE, loc)
        counts = {}
        for name, limit in LIMITS.items():
            path = os.path.join(d, name)
            if not os.path.isfile(path):
                errors.append(f"{loc}/{name}: missing")
                counts[name] = None
                continue
            with open(path, encoding="utf-8") as f:
                text = f.read()
            n = len(text)
            counts[name] = n
            if n == 0:
                errors.append(f"{loc}/{name}: empty")
            if n > limit:
                errors.append(f"{loc}/{name}: {n} > {limit}")
            if EMOJI.search(text):
                errors.append(f"{loc}/{name}: contains emoji / U+FE0F")
            if re.search(r"<[a-zA-Z/][^>]*>", text):
                errors.append(f"{loc}/{name}: contains HTML-like tag")
            if name != "full_description.txt" and "\n" in text:
                errors.append(f"{loc}/{name}: must be a single line")
            if name == "title.txt":
                if BANNED_TITLE.search(text):
                    errors.append(f"{loc}/{name}: promotional word in title")
                words = re.findall(r"[A-Za-z]{4,}", text)
                if any(w.isupper() for w in words):
                    errors.append(f"{loc}/{name}: ALL CAPS word in title")
        rows.append((loc, counts))

    extra = sorted(set(os.listdir(HERE)) - set(EXPECTED) - {"README.md", os.path.basename(__file__)})
    extra = [e for e in extra if os.path.isdir(os.path.join(HERE, e))]
    if extra:
        errors.append(f"unexpected locale dirs: {extra}")

    def fmt(v, lim):
        return "MISSING" if v is None else f"{v}/{lim}"

    if markdown:
        print("| Locale | Title | Short description | Full description |")
        print("|---|---:|---:|---:|")
        for loc, c in rows:
            print(f"| `{loc}` | " + " | ".join(fmt(c[k], LIMITS[k]) for k in LIMITS) + " |")
    else:
        print(f"{'locale':8} {'title':>8} {'short':>8} {'full':>10}")
        for loc, c in rows:
            print(f"{loc:8} " + " ".join(f"{fmt(c[k], LIMITS[k]):>{w}}"
                                         for k, w in zip(LIMITS, (8, 8, 10))))
    if errors:
        print("\nFAILED:", *errors, sep="\n  ")
        return 1
    print("\nOK: all listings within Google Play limits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
