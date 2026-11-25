import json, glob, os, time

from pathlib import Path

GVS5H_ROOT = os.environ.get("GVS5H_ROOT", str(Path(__file__).resolve().parents[2]))
GVS5H_LOG_DIR = os.environ.get("GVS5H_LOG_DIR", f"{GVS5H_ROOT}/logs")
LOG = f"{GVS5H_LOG_DIR}/smoke_longcat_lead.log"
R = f"{GVS5H_ROOT}/runs/smoke-longcat/results"
WS = f"{GVS5H_ROOT}/runs/smoke-longcat/ws/D_longcat_lead"
el = 0
try:
    with open(LOG) as f:
        first = f.readline()
    ts = first.split("]")[0].lstrip("[")
    el = int((time.time() - time.mktime(time.strptime(ts, "%Y-%m-%d_%H:%M:%S"))) / 60)
except Exception:
    pass
n = 0
try:
    n = sum(1 for _ in open(R + "/D_longcat_lead.ckpt.jsonl"))
except Exception:
    pass
lo = li = ho = hi = nl = nh = lt = ht = retry = 0
last = {}
for t in sorted(glob.glob(WS + "/*/transcript.jsonl")):
    h = t.split("/")[-2][:6]
    for line in open(t):
        try:
            r = json.loads(line)
        except Exception:
            continue
        if r.get("_meta"):
            continue
        m = r.get("model") or ""
        ct = r.get("completion_tokens") or 0
        pt = r.get("prompt_tokens") or 0
        if m.startswith("longcat:"):
            lo += ct; li += pt; nl += 1
            if r.get("finish_reason") == "length":
                lt += 1
        else:
            ho += ct; hi += pt; nh += 1
            if r.get("finish_reason") == "length":
                ht += 1
        if r.get("discarded"):
            retry += len(r["discarded"])
        if r.get("role"):
            last[h] = r["role"]
cost = (lo * 8 + li * 2) / 1e6
cur = " ".join(f"{h}:{v}" for h, v in sorted(last.items()))
print(f"elapsed={el}m ckpt={n}/3 lead={nl}call out={lo/1000:.1f}k in={li/1000:.1f}k CNY={cost:.2f} "
      f"trunc=lead{lt}/helper{ht} retry={retry} helper={nh}call out={ho/1000:.1f}k | {cur}")