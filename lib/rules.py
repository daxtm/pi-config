"""Drop the legacy kit check only for a main-only repository ruleset."""
import json, sys
r = json.load(sys.stdin)
if (r.get("conditions", {}).get("ref_name") != {"include":["refs/heads/main"],"exclude":[]} or
    r.get("name") != "main" or r.get("target") != "branch" or
    not {"pull_request","deletion","non_fast_forward"} <= {x["type"] for x in r["rules"]}):
    sys.exit()
for rule in list(r["rules"]):
    if rule["type"] != "required_status_checks":
        continue
    checks = rule["parameters"]["required_status_checks"]
    old = [c for c in checks if c["context"] == "check" and c.get("integration_id") in (None,-1)]
    if old:
        checks[:] = [c for c in checks if c not in old]
        if not checks:
            r["rules"].remove(rule)
        print(json.dumps({"rules":r["rules"]}))
        break
