#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export GVS5H_ROOT="${GVS5H_ROOT:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
set -u
export PATH=$HOME/.local/bin:$PATH
cd "$GVS5H_ROOT/codebase/v2-current" || exit 1
export LCB_RELEASE=release_v6
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
export MULTIAGENT_MAX_ITERS=10 MULTIAGENT_MAX_TASKS=12
export ESCALATION_OPENAI_BASE=http://127.0.0.1:18010/v1/chat/completions
export GROQ_API_KEY=dummy
export ESCALATION_GROQ_REASONING=""
export ESCALATION_CLOUD_TIMEOUT=14400
export MULTIAGENT_MODEL=groq:q38
OUT="$GVS5H_ROOT/runs/smoke/results"
WS="$GVS5H_ROOT/runs/smoke/ws"
mkdir -p "$OUT" "$WS"
PYTHON=(uv run --no-project --python 3.12 --with "datasets<4" --with numpy --with anthropic python)
echo "[$(date +%F_%T)] smoke single start"
env ESCALATION_CLOUD_MAX_TOKENS=250000 MULTIAGENT_WS="$WS/single" BENCH_CHECKPOINT="$OUT/single.ckpt.jsonl" \
  "${PYTHON[@]}" escalation/run_bench.py --engine single --only lcb --lcb 3 \
  --ids-file escalation/smoke_ids.json --parallel 2 --out "$OUT/single.json"
echo "[$(date +%F_%T)] smoke single exit=$?"
echo "[$(date +%F_%T)] smoke multiagent start"
env ESCALATION_CLOUD_MAX_TOKENS=128000 MULTIAGENT_WS="$WS/multiagent" BENCH_CHECKPOINT="$OUT/multiagent.ckpt.jsonl" \
  "${PYTHON[@]}" escalation/run_bench.py --engine multiagent --only lcb --lcb 3 \
  --ids-file escalation/smoke_ids.json --parallel 2 --out "$OUT/multiagent.json"
echo "[$(date +%F_%T)] smoke multiagent exit=$?"
echo "[$(date +%F_%T)] SMOKE DONE"
