"""Wait for arc196_c worker:3, stop the D-arm bench, and build a gradeable result blob.

User decision: do not let the manager keep looping on empty lead decisions.
a/b come from the checkpoint; c comes from its workspace solution.py.
"""
import glob
import json
import os
import signal
import subprocess
import time

from pathlib import Path

GVS5H_ROOT = os.environ.get("GVS5H_ROOT", str(Path(__file__).resolve().parents[2]))

ROOT = GVS5H_ROOT
RES = ROOT + "/runs/smoke-longcat/results"
WS = ROOT + "/runs/smoke-longcat/ws/D_longcat_lead"
IDS = ROOT + "/codebase/v2-current/escalation/smoke_ids.json"
NATURAL = RES + "/D_longcat_lead.json"
BLOB = RES + "/D_longcat_lead.stopped.json"
CKPT = RES + "/D_longcat_lead.ckpt.jsonl"
PGID = 4092881


def log(m):
    print(f"[{time.strftime('%F_%T')}] {m}", flush=True)


def chat_records(d):
    rs = [json.loads(l) for l in open(os.path.join(d, "transcript.jsonl"))]
    return [r for r in rs if not r.get("_meta")]


def stop_group():
    log(f"stopping bench process group {PGID}")
    subprocess.run(["ps", "-o", "pid,cmd", "-g", str(PGID)])
    try:
        os.killpg(PGID, signal.SIGTERM)
    except ProcessLookupError:
        log("group already gone")
        return
    for _ in range(30):
        time.sleep(1)
        try:
            os.killpg(PGID, 0)
        except ProcessLookupError:
            log("group exited on SIGTERM")
            return
    log("still alive after 30s -> SIGKILL")
    try:
        os.killpg(PGID, signal.SIGKILL)
    except ProcessLookupError:
        pass
    time.sleep(3)


def wait():
    deadline = time.time() + 3 * 3600
    cdir = glob.glob(WS + "/e964cc*")[0]
    while time.time() < deadline:
        if os.path.exists(NATURAL):
            log("NATURAL-DONE: result json appeared on its own")
            return "natural"
        rs = chat_records(cdir)
        if any((r.get("role") or "").startswith("worker:3") for r in rs):
            log(f"worker:3 landed (c now {len(rs)} calls); 30s grace for samples/flush")
            time.sleep(30)
            if os.path.exists(NATURAL):
                log("NATURAL-DONE during grace period")
                return "natural"
            stop_group()
            return "stopped"
        time.sleep(30)
    log("WATCH-TIMEOUT after 3h; leaving the run alone")
    raise SystemExit(1)


def build():
    ckpt = {}
    for l in open(CKPT):
        r = json.loads(l)
        ckpt[r["question_id"]] = r
    ids = json.load(open(IDS))
    sols = {}
    for d in sorted(glob.glob(WS + "/*")):
        p = os.path.join(d, "solution.py")
        if os.path.isdir(d) and os.path.exists(p):
            sols[d] = open(p).read()

    mapping, used = {}, set()
    for qid in ids:
        code = (ckpt.get(qid, {}).get("code") or "").strip()
        if not code:
            continue
        for d, s in sols.items():
            if d not in used and s.strip() == code:
                mapping[qid] = d
                used.add(d)
                break
    missing = [q for q in ids if q not in ckpt]
    leftover = [d for d in sols if d not in used]
    if len(missing) == 1 and len(leftover) == 1:
        mapping[missing[0]] = leftover[0]
    log("id -> ws: " + json.dumps({k: os.path.basename(v) for k, v in mapping.items()}))
    if len(mapping) != len(ids):
        raise SystemExit(f"ambiguous mapping: {len(mapping)} of {len(ids)} ids")

    records = []
    for qid in ids:
        d = mapping[qid]
        rs = chat_records(d)
        code = sols[d]
        st = ckpt.get(qid, {}).get("status") or {}
        rec = {
            "question_id": qid,
            "code": code,
            "status": "ok" if code.strip() else "infra",
            "finish_reason": rs[-1].get("finish_reason") if rs else None,
            "completion_tokens": sum(r.get("completion_tokens") or 0 for r in rs),
            "truncated_calls": sum(1 for r in rs if r.get("finish_reason") == "length"),
            "n_calls": len(rs),
            "ws": d,
            "passed": None,
        }
        if qid not in ckpt:
            rec["stopped_early"] = True
            rec["stop_reason"] = ("lead thinking budget exhausted -> empty content -> "
                                  "template placeholder parsed as next task; stopped after worker:3")
            rec["lead_degraded_calls"] = sum(
                1 for r in rs
                if str(r.get("model", "")).startswith("longcat:")
                and (r.get("completion_tokens") or 0) >= 65536
                and len(r.get("response") or "") == len(r.get("reasoning") or ""))
        records.append(rec)
        log(f"  {qid}: {rec['n_calls']} calls, code {len(code)} chars, "
            f"trunc={rec['truncated_calls']}, status={rec['status']}")

    blob = {"engine": "multiagent", "model": "groq:q38",
            "lead_model": "longcat:LongCat-2.5", "helper_model": "groq:q38",
            "stopped_early": True,
            "lcb": {"benchmark": "livecodebench", "pass@1": None,
                    "records": records, "n_graded": len(records), "n_infra": 0}}
    json.dump(blob, open(BLOB, "w"), indent=2)
    log(f"BUILD-OK {BLOB}")


mode = wait()
if mode == "natural":
    b = json.load(open(NATURAL))
    log(f"natural pass@1 = {b['lcb']['pass@1']}")
    for r in b["lcb"]["records"]:
        log(f"  {r['question_id']}: {'PASS' if r.get('passed') else 'FAIL'}")
else:
    build()
log("WATCH-END")