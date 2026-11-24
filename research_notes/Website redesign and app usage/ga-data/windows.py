"""Window means (per day) with a Poisson 95% band for each series, around each website deploy."""
import json, os, math, datetime
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")

def load(name):
    r = json.load(open(os.path.join(OUT, name + ".json")))["response"]
    return [([d["value"] for d in row.get("dimensionValues", [])], [float(m["value"]) for m in row["metricValues"]]) for row in r.get("rows", [])]

S = {}
def put(series, day, v):
    S.setdefault(series, {})[day] = S.get(series, {}).get(day, 0) + v
for (d,), m in load("install_date_main"): put("main installs (firstSessionDate, role=main)", d, m[0])
for (d,), m in load("install_date_helper"): put("new helpers (firstSessionDate, role=helper)", d, m[0])
for (d,), m in load("main_active_daily_dau"): put("main DAU", d, m[0])
for (d,), m in load("all_active_7_28"): put("all DAU (main+helper)", d, m[0])
for (d, nvr), m in load("main_new_daily"):
    put(f"main active {nvr}", d, m[0])
for (d, ev), m in load("daily_events"):
    if ev == "first_open": put("first_open events (all instances)", d, m[0])
    if ev == "tile_created": put("tile_created users", d, m[1])
    if ev == "tile_added_to_dock": put("tile_added_to_dock users", d, m[1])
    if ev == "app_launched": put("app_launched users", d, m[1])

W = [("Sep21-Oct21 baseline", "20260921", "20261021"),
     ("Oct22-Oct30 pre-deploy-1", "20261022", "20261030"),
     ("Oct31-Nov08 after Oct31", "20261031", "20261108"),
     ("Nov09-Nov17 after Nov09", "20261109", "20261117"),
     ("Nov18-Nov20 after Allo", "20261118", "20261120")]

def days(a, b):
    x = datetime.date(int(a[:4]), int(a[4:6]), int(a[6:])); y = datetime.date(int(b[:4]), int(b[4:6]), int(b[6:]))
    while x <= y:
        yield x.strftime("%Y%m%d"); x += datetime.timedelta(days=1)

print("series\t" + "\t".join(w[0] for w in W))
for name, s in S.items():
    cells = []
    for _, a, b in W:
        ds = list(days(a, b)); tot = sum(s.get(d, 0) for d in ds); n = len(ds); m = tot / n
        cells.append(f"{m:.1f}/d ±{1.96*math.sqrt(tot)/n:.1f} (n={int(tot)})")
    print(name + "\t" + "\t".join(cells))

# day-of-week profile over the baseline+spike, to check the weekend effect
print("\nday-of-week mean, Sep21-Nov20")
for name in ["main installs (firstSessionDate, role=main)", "first_open events (all instances)", "main DAU"]:
    acc = {}
    for d in days("20260921", "20261120"):
        k = datetime.date(int(d[:4]), int(d[4:6]), int(d[6:])).strftime("%a"); acc.setdefault(k, []).append(S[name].get(d, 0))
    print(name + "\t" + "  ".join(f"{k} {sum(v)/len(v):.1f}" for k, v in acc.items()))

print("\ndaily main installs Oct15-Nov21")
print("  ".join(f"{d[4:]}:{int(S['main installs (firstSessionDate, role=main)'].get(d,0))}" for d in days("20261015", "20261121")))
print("daily new helpers Oct15-Nov21")
print("  ".join(f"{d[4:]}:{int(S['new helpers (firstSessionDate, role=helper)'].get(d,0))}" for d in days("20261015", "20261121")))
