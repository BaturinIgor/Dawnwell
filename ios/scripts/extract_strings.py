#!/usr/bin/env python3
"""Lists the English keys the app looks up, as they appear in Localizable.strings.

Usage: ios/scripts/extract_strings.py            prints the keys, one JSON string per line
       ios/scripts/extract_strings.py --check    fails if a key is missing from en.lproj

Keys come from string literals in places Swift looks them up:
String(localized:), and SwiftUI initialisers and modifiers that take a LocalizedStringKey.
Interpolations become format specifiers; INT_EXPRS lists the ones that are numbers.
"""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DIRS = ["Dawnwell", "DawnwellWidgets", "Shared"]

# Calls whose first string literal is a LocalizedStringKey (or String(localized:)).
FIRST = r'(?:String\(localized:\s*|Text\(|Button\(|Label\(|\.accessibilityLabel\(|\.accessibilityHint\(|\.navigationTitle\(|Picker\(|DatePicker\(|TextField\(|Link\(|Section\(|prompt:\s*|\.value\(|toggle\(|labelled\(|title\(|fieldLabel\(|less:\s*|more:\s*)'
# Helpers whose second argument is a LocalizedStringKey.
SECOND = r'(?:toggle\(|labelled\(|title\(|legend\(|stat\()'

# Interpolated expressions that are integers (become %lld). Everything else is %@.
INT_EXPRS = {
    "left", "streak", "protein", "target", "target - protein", "f.protein", "profile.waitMinutes",
    "i.waitMinutes", "i.proteinToday", "i.proteinTarget", "p.tabletsLeft ?? 0", "Catalog.refillAt",
    "saving", "found", "s.proteinHitDays", "s.proteinTarget", "s.takenCount", "VisitSummary.span",
    "s.days", "s.worst", "count", "total", "day", "a.minutes", "d", "w", "daysTaken", "span",
    "daysSkipped", "p", "proteinTarget", "hits", "of", "otherHits", "otherOf", "with", "without", "need",
    "logged", "summary.span",
}
# Literals the patterns catch that are not shown to anyone (SF Symbol names).
NOT_TEXT = {"minus", "plus"}

# Stored English values shown through Loc.text: food names and portions, and triggers.
DYNAMIC_FILE = "Dawnwell/Model/Catalog.swift"


def literals(src):
    """Yields (start, text) for each plain "..." literal, skipping multi-line ones."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            i = src.find("\n", i)
            if i < 0:
                return
            continue
        if c == '"':
            if src.startswith('"""', i):
                i = src.find('"""', i + 3) + 3
                continue
            j, depth, out = i + 1, 0, []
            while j < n:
                ch = src[j]
                if ch == "\\" and src[j + 1] == "(":
                    # interpolation: copy up to the matching paren, strings inside included
                    k, d = j + 2, 1
                    while d:
                        if src[k] == "(":
                            d += 1
                        elif src[k] == ")":
                            d -= 1
                        elif src[k] == '"':
                            k = src.find('"', k + 1)
                        k += 1
                    out.append(src[j:k])
                    j = k
                    continue
                if ch == "\\":
                    out.append(src[j:j + 2])
                    j += 2
                    continue
                if ch == '"':
                    break
                out.append(ch)
                j += 1
            yield i, "".join(out)
            i = j + 1
            continue
        i += 1


def to_key(text, path):
    if "\\(" in text:
        text = text.replace("%", "%%")
    # replace interpolations, matching nested parens
    out, i = [], 0
    while i < len(text):
        if text.startswith("\\(", i):
            k, d = i + 2, 1
            while d:
                if text[k] == "(":
                    d += 1
                elif text[k] == ")":
                    d -= 1
                k += 1
            expr = text[i + 2:k - 1].strip()
            out.append("%lld" if expr in INT_EXPRS else "%@")
            i = k
            continue
        out.append(text[i])
        i += 1
    key = "".join(out)
    return key.replace('\\"', '"').replace("\\n", "\n")


def keys():
    found = {}
    for d in DIRS:
        for base, _, files in os.walk(os.path.join(ROOT, d)):
            for f in sorted(files):
                if not f.endswith(".swift"):
                    continue
                path = os.path.join(base, f)
                rel = os.path.relpath(path, ROOT)
                src = open(path, encoding="utf-8").read()
                lits = list(literals(src))
                for idx, (pos, text) in enumerate(lits):
                    before = src[max(0, pos - 60):pos]
                    ok = re.search(FIRST + r'$', before) or re.search(r'Text\(\s*$', before)
                    if not ok and re.search(r'(?:\?|:)\s*$', before):
                        # a branch of a ternary inside a LocalizedStringKey helper call
                        ok = re.search(r'labelled\("[^"]*",[^)]*$', src[max(0, pos - 200):pos], re.S)
                    if not ok and re.search(r',\s*$', before):
                        ok = re.search(SECOND + r'[^()"]*"[^"]*"\s*,\s*$', src[max(0, pos - 200):pos]) or \
                             re.search(r'(?:legend|stat)\([^,]+,\s*$', before)
                    if not ok or "verbatim:" in before[-12:]:
                        continue
                    if not re.search(r"[A-Za-z]", re.sub(r"\\\(.*?\)", "", text)):
                        continue
                    if text not in NOT_TEXT:
                        found.setdefault(to_key(text, rel), rel)
    catalog = open(os.path.join(ROOT, DYNAMIC_FILE), encoding="utf-8").read()
    for m in re.finditer(r'(?:name|portion|short): "([^"]+)"', catalog):
        found.setdefault(m.group(1), DYNAMIC_FILE)
    triggers = re.search(r"static let triggers = \[(.*?)\]", catalog).group(1)
    for t in re.findall(r'"([^"]+)"', triggers):
        found.setdefault(t, DYNAMIC_FILE)
    return found


if __name__ == "__main__":
    k = keys()
    if "--check" in sys.argv:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from localize import read_strings_keys
        have = read_strings_keys("en")
        missing = sorted(set(k) - have)
        for m in missing:
            print("missing:", json.dumps(m), "from", k[m])
        sys.exit(1 if missing else 0)
    for key, where in sorted(k.items(), key=lambda kv: kv[1]):
        print(where.ljust(52), json.dumps(key, ensure_ascii=False))
