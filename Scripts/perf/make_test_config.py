#!/usr/bin/env python3
"""Write a release-sized TEST config for the dev app from a READ-ONLY copy of the production config.

Bundle IDs are STORED in the config. A raw production copy loaded by the dev app would carry
production bundle IDs; self-heal would see them as "pinned in the Dock but bundle missing" and
re-seat the real Dock entries. Rewriting them to the dev prefix makes the tiles "never pinned",
which every reconciler leaves alone.

usage: make_test_config.py [output-path]
"""
import json
import os
import re
import sys

src = os.path.expanduser("~/Library/Preferences/com.docktile.configs.json")
dst = sys.argv[1] if len(sys.argv) > 1 else "/tmp/docktile-release-sized-test-config.json"
text = open(src).read()
pattern = re.compile(r'"com\.docktile\.([0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})"')
rewritten, count = pattern.subn(r'"com.docktile.dev.\1"', text)
configs = json.loads(rewritten)
ok = count == len(configs) and all(c["bundleIdentifier"].startswith("com.docktile.dev.") for c in configs)
if not ok:
    sys.exit("bundle id rewrite incomplete — do NOT load this file in the dev app")
open(dst, "w").write(rewritten)
print(f"wrote {dst}: {len(configs)} tiles, {len(rewritten)} bytes, {count} bundle ids rewritten")
