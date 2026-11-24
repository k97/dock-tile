"""ISO-week sums of main installs and new helpers (firstSessionDate series)."""
import json, os, datetime
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
res = {}
for name in ["install_date_main", "install_date_helper"]:
    for row in json.load(open(os.path.join(OUT, name + ".json")))["response"].get("rows", []):
        d = row["dimensionValues"][0]["value"]
        if d < "20260831": continue
        y, w, _ = datetime.date(int(d[:4]), int(d[4:6]), int(d[6:])).isocalendar()
        res.setdefault(w, {}).setdefault(name, 0)
        res[w][name] += int(row["metricValues"][0]["value"])
print("isoWeek\tweek starts\tmain installs\tnew helpers")
for w in sorted(res):
    start = datetime.date.fromisocalendar(2026, w, 1)
    print(f"{w}\t{start}\t{res[w].get('install_date_main', 0)}\t{res[w].get('install_date_helper', 0)}")
