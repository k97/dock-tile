"""Tiny GA4 helper: ga.py get <url> | ga.py report <property> <json-body-file> [out]"""
import json, sys, urllib.request, urllib.error, os

HERE = os.path.dirname(os.path.abspath(__file__))
TOKEN = open(os.path.join(HERE, "token.txt")).read().strip()


def call(url, body=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"http_error": e.code, "body": e.read().decode()[:2000]}


def table(resp):
    if "rows" not in resp:
        return json.dumps(resp)[:1500]
    hdr = [h["name"] for h in resp["dimensionHeaders"]] + [h["name"] for h in resp["metricHeaders"]]
    lines = ["\t".join(hdr)]
    for row in resp["rows"]:
        lines.append("\t".join([d["value"] for d in row.get("dimensionValues", [])] + [m["value"] for m in row["metricValues"]]))
    return "\n".join(lines)


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "get":
        print(json.dumps(call(sys.argv[2]), indent=1)[:6000])
    elif mode == "report":
        prop, bodyfile = sys.argv[2], sys.argv[3]
        body = json.load(open(bodyfile))
        resp = call(f"https://analyticsdata.googleapis.com/v1beta/properties/{prop}:runReport", body)
        if len(sys.argv) > 4:
            json.dump({"request": body, "response": resp}, open(sys.argv[4], "w"), indent=1)
        print(table(resp))
