"""Main-app installs (firstSessionDate) by country and by first appVersion, per window."""
import json, os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
W = [("base Sep21-Oct21", "20260921", "20261021"), ("surge Oct22-Nov08", "20261022", "20261108"), ("after Nov09-Nov21", "20261109", "20261121")]
for name, dim in [("main_country_install", "country"), ("main_installs_version", "appVersion")]:
    r = json.load(open(os.path.join(OUT, name + ".json")))["response"]
    agg = {}
    for row in r.get("rows", []):
        d, k = [x["value"] for x in row["dimensionValues"]]
        v = int(row["metricValues"][0]["value"])
        for w, a, b in W:
            if a <= d <= b:
                agg.setdefault(k, {}).setdefault(w, 0); agg[k][w] += v
    print(f"\n{dim}\t" + "\t".join(w[0] for w in W))
    for k, v in sorted(agg.items(), key=lambda kv: -sum(kv[1].values()))[:15]:
        print(k + "\t" + "\t".join(str(v.get(w[0], 0)) for w in W))
