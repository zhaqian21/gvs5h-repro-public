#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export GVS5H_ROOT="${GVS5H_ROOT:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
set -u
export PATH=$HOME/.local/bin:$PATH
cd "$GVS5H_ROOT/codebase/v2-current" || exit 1
if [[ -n "${DASHSCOPE_ENV_FILE:-}" ]]; then
  set -a
  . "$DASHSCOPE_ENV_FILE"
  set +a
fi
export LCB_RELEASE=release_v6 HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}" HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
export MULTIAGENT_MAX_ITERS=10 MULTIAGENT_MAX_TASKS=12
export ESCALATION_CLOUD_TIMEOUT=14400 ESCALATION_CLOUD_MAX_TOKENS=128000
export ESCALATION_GROQ_REASONING=""
export ESCALATION_OPENAI_BASE=http://127.0.0.1:18010/v1/chat/completions
export GROQ_API_KEY=dummy
export ESCALATION_DASHSCOPE_BASE=https://api.deepseek.com/chat/completions
OUT="$GVS5H_ROOT/runs/smoke-hetero/results"
WS="$GVS5H_ROOT/runs/smoke-hetero/ws"
LOG="${GVS5H_LOG_DIR:-$GVS5H_ROOT/logs}"
mkdir -p "$OUT" "$WS" "$LOG"
PYTHON=(uv run --no-project --python 3.12 --with "datasets<4" --with numpy --with anthropic python)
env LEAD_MODEL="dashscope:deepseek-flash" HELPER_MODEL="dashscope:deepseek-flash" MULTIAGENT_MODEL="dashscope:deepseek-flash" MULTIAGENT_WS="$WS/B_ds" BENCH_CHECKPOINT="$OUT/B_ds.ckpt.jsonl" \
  "${PYTHON[@]}" escalation/run_bench.py --engine multiagent --only lcb --lcb 3 --ids-file escalation/smoke_ids.json --parallel 2 --out "$OUT/B_ds.json" > "$LOG/armB.log" 2>&1 &
PB=$!
env LEAD_MODEL="dashscope:deepseek-flash" HELPER_MODEL="groq:q38" MULTIAGENT_MODEL="groq:q38" MULTIAGENT_WS="$WS/C_hetero" BENCH_CHECKPOINT="$OUT/C_hetero.ckpt.jsonl" \
  "${PYTHON[@]}" escalation/run_bench.py --engine multiagent --only lcb --lcb 3 --ids-file escalation/smoke_ids.json --parallel 2 --out "$OUT/C_hetero.json" > "$LOG/armC.log" 2>&1 &
PC=$!
echo "[$(date +%F_%T)] PARALLEL started B=$PB C=$PC"
wait $PB; echo "[$(date +%F_%T)] ARM B exit=$?"
wait $PC; echo "[$(date +%F_%T)] ARM C exit=$?"
echo "[$(date +%F_%T)] PARALLEL SMOKE DONE"
