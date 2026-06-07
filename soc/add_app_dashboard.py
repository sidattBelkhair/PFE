#!/usr/bin/env python3
"""
Usage: python3 add_app_dashboard.py <app_name>
Creates a dedicated Grafana dashboard for a friend's app.
Example: python3 add_app_dashboard.py financeapp-moulay
"""
import json
import os
import sys
import re

TEMPLATE = "/root/PFE/soc/grafana/provisioning/dashboards/sedad_bank_soc.json"
OUT_DIR  = "/root/PFE/soc/grafana/provisioning/dashboards"

def make_uid(app_name):
    return "soc-" + re.sub(r'[^a-z0-9]', '-', app_name.lower())[:30]

def generate(app_name):
    with open(TEMPLATE) as f:
        d = json.load(f)

    uid   = make_uid(app_name)
    title = f"{app_name} — SOC Dashboard"

    d["uid"]   = uid
    d["title"] = title

    # Lock the app variable to this specific app (constant = can't be changed)
    tpl = d.get("templating", {}).get("list", [])
    for i, t in enumerate(tpl):
        if t["name"] == "app":
            tpl[i] = {
                "name":  "app",
                "label": "Application",
                "type":  "constant",
                "hide":  2,          # 2 = hidden — variable exists but not shown
                "query": app_name,
                "current": {"selected": True, "text": app_name, "value": app_name},
                "options": [{"selected": True, "text": app_name, "value": app_name}],
            }

    out_path = os.path.join(OUT_DIR, f"soc_{uid}.json")
    with open(out_path, "w") as f:
        json.dump(d, f, indent=2)

    print(f"✓ Dashboard créé : {out_path}")
    print(f"  Titre : {title}")
    print(f"  UID   : {uid}")
    print(f"  URL   : http://198.199.70.48:3000/d/{uid}")
    print()
    print("Recharger Grafana :")
    print("  docker compose -f /root/PFE/docker-compose.soc.yml restart grafana")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 add_app_dashboard.py <app_name>")
        print("Apps visibles dans Loki :")
        os.system(
            'curl -s -G "http://localhost:3100/loki/api/v1/label/app/values" '
            '| python3 -c "import json,sys; [print(\" -\",v) for v in json.load(sys.stdin).get(\'data\',[]))]"'
        )
        sys.exit(1)

    generate(sys.argv[1])
