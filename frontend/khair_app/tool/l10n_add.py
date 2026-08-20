#!/usr/bin/env python3
"""Add localization keys to all ARB files at once.

Usage: python tool/l10n_add.py <payload.json>

Payload format:
{
  "meta": { "keyWithPlaceholder": { "placeholders": { "query": { "type": "String" } } } },
  "en": { "key": "value", ... },
  "ar": { "key": "value", ... },
  "tr": { "key": "value", ... }
}
"meta" entries become "@key" metadata in the en template ARB only.
Fails if a key already exists (pass --force to overwrite).
"""
import json
import sys
from pathlib import Path

ARB_DIR = Path(__file__).resolve().parent.parent / "lib" / "l10n"
LOCALES = ["en", "ar", "tr"]


def main() -> None:
    force = "--force" in sys.argv
    payload_path = Path(sys.argv[1] if len(sys.argv) < 2 or sys.argv[1] == "--force" else sys.argv[1])
    payload = json.loads(payload_path.read_text(encoding="utf-8"))
    meta = payload.pop("meta", {})

    problems = []
    for locale in LOCALES:
        entries = payload.get(locale)
        if entries is None:
            problems.append(f"{locale}: missing section")
            continue
        path = ARB_DIR / f"app_{locale}.arb"
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, value in entries.items():
            if key in data and not force:
                problems.append(f"{locale}.{key}: already exists")
        if problems:
            continue
        data.update(entries)
        if locale == "en":
            for key, m in meta.items():
                data[f"@{key}"] = m
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{locale}: +{len(entries)} keys -> {len([k for k in data if not k.startswith('@') and k != '@@locale'])} total")

    if problems:
        print("ABORTED (fix collisions first):")
        for p in problems:
            print(" ", p)
        sys.exit(1)


if __name__ == "__main__":
    main()
