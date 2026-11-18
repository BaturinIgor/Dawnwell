#!/usr/bin/env python3
"""Turns a numbered translation list into ios/Localization/<lang>.json.

The list has one line per English key, in the order of en.json: "<index>\t<text>".
Plural keys: "<index>\tP one=...||other=..." (optionally "format=...||" first).
The Info.plist string uses "<index>\tINFO <text>". Lines starting with # are skipped.
Usage: ios/scripts/numbered_to_json.py <lang> <list.txt>
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "Localization")

lang, path = sys.argv[1], sys.argv[2]
en = json.load(open(os.path.join(SRC, "en.json"), encoding="utf-8"))
keys = list(en)
out = {}
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    idx, text = line.split("\t", 1)
    key = keys[int(idx)]
    if text.startswith("INFO "):
        out[key] = {"NSHealthShareUsageDescription": text[5:]}
    elif text.startswith("P "):
        forms = {}
        for part in text[2:].split("||"):
            name, value = part.split("=", 1)
            forms[name.strip()] = value.strip()
        out[key] = forms
    else:
        out[key] = text.replace("\\n", "\n")
missing = [k for k in keys if k not in out]
if missing:
    sys.exit(f"{lang}: {len(missing)} lines missing, first: {missing[0]!r}")
json.dump({k: out[k] for k in keys}, open(os.path.join(SRC, f"{lang}.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print(f"{lang}: {len(out)} keys")
