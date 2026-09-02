#!/usr/bin/env python3
"""Add one key to Localizable.xcstrings for en-GB (source), en-US and en-AU.
Usage: Scripts/add-string.py <key> "<en-GB value>" "<comment>" [--us "<en-US value>"]
"""
import json, sys
CATALOG = "DockTile/Resources/Localizable.xcstrings"
args = sys.argv[1:]
us = None
if "--us" in args:
    i = args.index("--us"); us = args[i + 1]; del args[i:i + 2]
key, value, comment = args
with open(CATALOG) as f:
    cat = json.load(f)
if key in cat["strings"]:
    sys.exit(f"{key} already exists")
def unit(v): return {"stringUnit": {"state": "translated", "value": v}}
cat["strings"][key] = {
    "comment": comment,
    "extractionState": "manual",
    "localizations": {"en-AU": unit(value), "en-GB": unit(value), "en-US": unit(us or value)},
}
with open(CATALOG, "w") as f:   # no re-sorting: keep the diff to the one new key
    json.dump(cat, f, indent=2, ensure_ascii=False); f.write("\n")
print("added", key)
