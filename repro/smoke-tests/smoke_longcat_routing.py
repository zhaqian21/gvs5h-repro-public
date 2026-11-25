import json, glob

import os
from pathlib import Path

GVS5H_ROOT = os.environ.get("GVS5H_ROOT", str(Path(__file__).resolve().parents[2]))
pairs = set()
for t in glob.glob(f"{GVS5H_ROOT}/runs/smoke-longcat/ws/D_longcat_lead/*/transcript.jsonl"):
    for line in open(t):
        try:
            r = json.loads(line)
        except Exception:
            continue
        if r.get("_meta"):
            continue
        if r.get("role"):
            pairs.add(f"{r['role']}={r.get('model')}")
print(",".join(sorted(pairs)) if pairs else "no-transcript-yet")
