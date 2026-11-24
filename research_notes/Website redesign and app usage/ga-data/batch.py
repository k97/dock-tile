"""Run every query in queries.json; save request+response JSON and a TSV per query into OUT dir."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ga import call, table

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)
queries = json.load(open(sys.argv[1]))
for name, body in queries.items():
    body.setdefault("limit", 10000)
    resp = call("https://analyticsdata.googleapis.com/v1beta/properties/542196919:runReport", body)
    json.dump({"request": body, "response": resp}, open(os.path.join(OUT, name + ".json"), "w"), indent=1)
    t = table(resp)
    open(os.path.join(OUT, name + ".tsv"), "w").write(t + "\n")
    print(f"== {name}: {t.count(chr(10))} rows")
