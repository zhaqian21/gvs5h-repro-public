#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export GVS5H_ROOT="${GVS5H_ROOT:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
# ARM D: LongCat-2.5 lead + local Qwen3.8-27B-FP8 helper. 3-problem manager smoke,
# same pinned ids / caps / iteration limits as arms A-C in runs/smoke-hetero.
set -u
export PATH=$HOME/.local/bin:$PATH
cd "$GVS5H_ROOT/codebase/v2-current" || exit 1
if [[ -n "${LONGCAT_ENV_FILE:-}" ]]; then
  set -a
  . "$LONGCAT_ENV_FILE"
  set +a
fi
export LCB_RELEASE=release_v6
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
export MULTIAGENT_MAX_ITERS=10 MULTIAGENT_MAX_TASKS=12
export ESCALATION_CLOUD_TIMEOUT=14400
export ESCALATION_CLOUD_MAX_TOKENS=128000
export ESCALATION_GROQ_REASONING=""
export ESCALATION_OPENAI_BASE=http://127.0.0.1:18010/v1/chat/completions
export GROQ_API_KEY=dummy
OUT="$GVS5H_ROOT/runs/smoke-longcat/results"
WS="$GVS5H_ROOT/runs/smoke-longcat/ws"
mkdir -p "$OUT" "$WS"
PYTHON=(uv run --no-project --python 3.12 --with "datasets<4" --with numpy --with anthropic python)
echo "[$(date +%F_%T)] ARM D longcat-lead start (par=3 cap=128000)"
env LEAD_MODEL="longcat:LongCat-2.5" HELPER_MODEL="groq:q38" MULTIAGENT_MODEL="groq:q38" \
    MULTIAGENT_WS="$WS/D_longcat_lead" BENCH_CHECKPOINT="$OUT/D_longcat_lead.ckpt.jsonl" \
  "${PYTHON[@]}" escalation/run_bench.py --engine multiagent --only lcb --lcb 3 \
    --ids-file escalation/smoke_ids.json --parallel 3 --out "$OUT/D_longcat_lead.json"
echo "[$(date +%F_%T)] ARM D exit=$?"
echo "[$(date +%F_%T)] LONGCAT LEAD SMOKE DONE"