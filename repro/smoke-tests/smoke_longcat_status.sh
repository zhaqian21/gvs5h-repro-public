#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export GVS5H_ROOT="${GVS5H_ROOT:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
R="$GVS5H_ROOT/runs/smoke-longcat/results"
L="${GVS5H_LOG_DIR:-$GVS5H_ROOT/logs}/smoke_longcat_lead.log"
if [ -f "$R/D_longcat_lead.json" ]; then
  s=$(python3 -c "import json;d=json.load(open('$R/D_longcat_lead.json'))['lcb'];print('pass@1=%s graded=%s infra=%s'%(d['pass@1'],d['n_graded'],d['n_infra']))" 2>/dev/null)
  echo "DONE $s | $(python3 "$SCRIPT_DIR/smoke_longcat_progress.py" 2>/dev/null)"
  exit 0
fi
if pgrep -f "run_bench.py --engine multiagent --only lcb --lcb 3" >/dev/null 2>&1; then
  echo "RUNNING $(python3 "$SCRIPT_DIR/smoke_longcat_progress.py" 2>/dev/null)"
else
  echo "FAILED no-process | $(tail -3 "$L" 2>/dev/null | tr '\n' ' ' | cut -c1-260)"
fi
