"""Pivot daily tables into one wide daily TSV: date, all active/new, main active/new, helper active, events."""
import json, os, sys, datetime
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
def rows(name):
    r = json.load(open(os.path.join(OUT, name + ".json")))["response"]
    for row in r.get("rows", []):
        yield [d["value"] for d in row.get("dimensionValues", [])], [m["value"] for m in row["metricValues"]]
days = {}
for (d,), (au, nu, s) in rows("daily_all"):
    days.setdefault(d, {})["all_au"] = au; days[d]["all_new"] = nu
for (d, role), (au, nu, s) in rows("daily_role"):
    days.setdefault(d, {})[f"{role}_au"] = au
for (d, ev), (c, u) in rows("daily_events"):
    days.setdefault(d, {})[f"{ev}_n"] = c
    days[d][f"{ev}_u"] = u
cols = ["all_au", "all_new", "main_au", "helper_au", "(not set)_au", "first_open_n", "tile_created_n", "tile_created_u", "tile_added_to_dock_u", "app_launched_u", "app_update_n", "app_remove_n"]
print("date\tdow\t" + "\t".join(cols))
for d in sorted(days):
    if d < sys.argv[1]: continue
    dow = datetime.date(int(d[:4]), int(d[4:6]), int(d[6:])).strftime("%a")
    print(d + "\t" + dow + "\t" + "\t".join(days[d].get(c, "0") for c in cols))
