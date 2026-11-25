import json, os, time, urllib.request, urllib.error

from pathlib import Path

GVS5H_ROOT = os.environ.get("GVS5H_ROOT", str(Path(__file__).resolve().parents[2]))
URL = "https://api.longcat.chat/openai/v1/chat/completions"
KEY = os.environ["LONGCAT_API_KEY"]
SYS = ("You are the PRIMARY orchestrator (manager) of a small team of workers, all expert at "
       "competitive programming. Given a problem, produce a short overarching plan to solve it, "
       "then a task list the workers can pick up. Respond with EXACTLY these sections:\n"
       "### PLAN\n<3-6 sentence strategy>\n### TASKS\n<3-6 bullet tasks, each a concrete unit of work>")
prob = open(f"{GVS5H_ROOT}/runs/smoke-longcat/ws/D_longcat_lead/ae972dbb133d/task.md").read()
body = {"model": "LongCat-2.5", "stream": False, "max_tokens": 128000, "temperature": 0.2,
        "messages": [{"role": "system", "content": SYS}, {"role": "user", "content": prob}]}
req = urllib.request.Request(URL, data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "Authorization": "Bearer " + KEY})
t0 = time.time()
try:
    with urllib.request.urlopen(req, timeout=3600) as r:
        out = json.loads(r.read())
    ch = (out.get("choices") or [{}])[0]
    print(f"PROBE-OK elapsed={time.time()-t0:.0f}s finish={ch.get('finish_reason')} usage={json.dumps(out.get('usage'))}", flush=True)
except urllib.error.HTTPError as e:
    print(f"PROBE-HTTPERROR code={e.code} elapsed={time.time()-t0:.0f}s body={e.read().decode()[:400]}", flush=True)
except Exception as e:
    print(f"PROBE-ERR {type(e).__name__} elapsed={time.time()-t0:.0f}s {str(e)[:300]}", flush=True)
