#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export GVS5H_ROOT="${GVS5H_ROOT:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
# Stop the D-arm smoke after arc196_c worker:3, then grade the stored solutions locally.
set -u
export PATH="$HOME/.local/bin:$PATH"
cd "$GVS5H_ROOT/codebase/v2-current" || exit 1
export LCB_RELEASE=release_v6
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
RES="$GVS5H_ROOT/runs/smoke-longcat/results"
BLOB="$RES/D_longcat_lead.stopped.json"
NATURAL="$RES/D_longcat_lead.json"
PY=(uv run --no-project --python 3.12 --with 'datasets<4' --with numpy --with anthropic python)

echo "[$(date +%F_%T)] watcher start: waiting for arc196_c worker:3"
python3 "$SCRIPT_DIR/stop_and_build_longcat.py" || { echo "WATCH-FAIL"; exit 1; }

if [ -f "$BLOB" ]; then
  echo "[$(date +%F_%T)] grading stored solutions via escalation/regrade.py"
  REGRADE_PROCS=16 "${PY[@]}" escalation/regrade.py "$BLOB" || echo "REGRADE-FAIL"
elif [ -f "$NATURAL" ]; then
  echo "[$(date +%F_%T)] run finished naturally; pass@1 from $NATURAL"
  python3 -c "
import json,sys
b=json.load(open(sys.argv[1]))['lcb']
print('pass@1 =', b['pass@1'])
for r in b['records']:
    print(' ', r['question_id'], 'PASS' if r.get('passed') else 'FAIL', r.get('n_calls'), 'calls')
" "$NATURAL"
fi

echo "[$(date +%F_%T)] final tally"
python3 "$SCRIPT_DIR/smoke_longcat_progress.py"
echo "[$(date +%F_%T)] FINISH-DONE"