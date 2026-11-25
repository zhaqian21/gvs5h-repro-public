#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export GVS5H_ROOT="${GVS5H_ROOT:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
set -u
export PATH=$HOME/.local/bin:$PATH
cd "$GVS5H_ROOT/codebase/v2-current" || exit 1
export LCB_RELEASE=release_v6 HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}" HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
export MULTIAGENT_MAX_ITERS=10 MULTIAGENT_MAX_TASKS=12
export ESCALATION_CLOUD_TIMEOUT=14400
export ESCALATION_GROQ_REASONING=""
export ESCALATION_OPENAI_BASE=http://127.0.0.1:18010/v1/chat/completions
export GROQ_API_KEY=dummy
export MULTIAGENT_MODEL=groq:q35-9b
OUT="$GVS5H_ROOT/runs/smoke-9b/results"
WS="$GVS5H_ROOT/runs/smoke-9b/ws"
LOG="${GVS5H_LOG_DIR:-$GVS5H_ROOT/logs}"
mkdir -p "$OUT" "$WS" "$LOG"
PYTHON=(uv run --no-project --python 3.12 --with "datasets<4" --with numpy --with anthropic python)
env ESCALATION_CLOUD_MAX_TOKENS=250000 MULTIAGENT_WS="$WS/single" BENCH_CHECKPOINT="$OUT/9b_single.ckpt.jsonl" \
  "${PYTHON[@]}" escalation/run_bench.py --engine single --only lcb --lcb 3 --ids-file escalation/smoke_ids.json --parallel 2 --out "$OUT/9b_single.json" > "$LOG/9b_single.log" 2>&1 &
PS=$!
env ESCALATION_CLOUD_MAX_TOKENS=128000 MULTIAGENT_WS="$WS/manager" BENCH_CHECKPOINT="$OUT/9b_manager.ckpt.jsonl" \
  "${PYTHON[@]}" escalation/run_bench.py --engine multiagent --only lcb --lcb 3 --ids-file escalation/smoke_ids.json --parallel 2 --out "$OUT/9b_manager.json" > "$LOG/9b_manager.log" 2>&1 &
PM=$!
echo "[$(date +%F_%T)] 9B started single=$PS manager=$PM"
wait $PS; echo "[$(date +%F_%T)] 9B single exit=$?"
wait $PM; echo "[$(date +%F_%T)] 9B manager exit=$?"
echo "[$(date +%F_%T)] SMOKE 9B DONE"
