import json, os, time, urllib.request, urllib.error

from pathlib import Path

GVS5H_ROOT = os.environ.get("GVS5H_ROOT", str(Path(__file__).resolve().parents[2]))
URL = "https://api.longcat.chat/openai/v1/chat/completions"
KEY = os.environ["LONGCAT_API_KEY"]
SYS = ("You are the PRIMARY orchestrator (manager) of a small team of workers, all expert at "
       "competitive programming. Given a problem, produce a short overarching plan to solve it, "
       "then a task list the workers can pick up. Respond with EXACTLY these sections:\n"
       "### PLAN\n<3-6 sentence strategy>\n### TASKS\n<3-6 bullet tasks, each a concrete unit of work>")
prob = open(f"{GVS5H_ROOT}/runs/smoke-longcat/ws/D_longcat_lead/e964cc4e890d/task.md").read()
body = {"model": "LongCat-2.5", "stream": True, "max_tokens": 128000, "temperature": 0.2,
        "messages": [{"role": "system", "content": SYS}, {"role": "user", "content": prob}]}
req = urllib.request.Request(URL, data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "Authorization": "Bearer " + KEY})
t0 = time.time(); last = t0; nr = nc = 0; finish = None; usage = None; chunks = 0
print(f"PROBE2-START {time.strftime('%F_%T')} prompt_chars={len(prob)}", flush=True)
try:
    with urllib.request.urlopen(req, timeout=7200) as r:
        for raw in r:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"): continue
            p = line[5:].strip()
            if p == "[DONE]": break
            try: d = json.loads(p)
            except ValueError: continue
            chunks += 1
            if d.get("usage"): usage = d["usage"]
            for ch in d.get("choices") or []:
                dl = ch.get("delta") or {}
                nr += len(dl.get("reasoning_content") or "")
                nc += len(dl.get("content") or "")
                if ch.get("finish_reason"): finish = ch["finish_reason"]
            now = time.time()
            if now - last >= 120:
                print(f"PROBE2-TICK elapsed={now-t0:.0f}s chunks={chunks} reasoning_ch={nr} content_ch={nc}", flush=True)
                last = now
    print(f"PROBE2-END elapsed={time.time()-t0:.0f}s finish={finish} chunks={chunks} "
          f"reasoning_ch={nr} content_ch={nc} usage={json.dumps(usage)}", flush=True)
except urllib.error.HTTPError as e:
    print(f"PROBE2-HTTPERROR code={e.code} elapsed={time.time()-t0:.0f}s chunks={chunks} "
          f"reasoning_ch={nr} body={e.read().decode()[:200]}", flush=True)
except Exception as e:
    print(f"PROBE2-TRUNCATED {type(e).__name__} elapsed={time.time()-t0:.0f}s chunks={chunks} "
          f"reasoning_ch={nr} content_ch={nc} finish={finish} {str(e)[:200]}", flush=True)
