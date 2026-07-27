#!/usr/bin/env bash
# Generate every fusion listed in missing.json. Resumable: skips a fusion whose
# _fit.png already exists, so a re-run only fills the gaps.
set -u
S="tools/sidmod_editor/sprites"
MODEL="${MODEL:-gpt-image-2}"
QUALITY="${QUALITY:-high}"

PAIRS=$(python -c "
import json;print(' '.join(f\"{r['head']}.{r['body']}\" for r in json.load(open('$S/missing.json'))))")

echo "=== generating $(echo $PAIRS | wc -w) sprites | model=$MODEL quality=$QUALITY ==="
ok=0; fail=0
for p in $PAIRS; do
  out="$S/out/${p}_edit_${MODEL}_0_fit.png"
  if [ -f "$out" ]; then echo "[skip] $p (already done)"; ok=$((ok+1)); continue; fi
  for attempt in 1 2; do
    if timeout 300 python $S/gen_sprite.py "$p" --mode edit --model "$MODEL" \
         --quality "$QUALITY" 2>&1 | grep -vE "Deprecat|return len|for px in" | sed 's/^/    /'; then
      :
    fi
    if [ -f "$out" ]; then ok=$((ok+1)); break; fi
    echo "    attempt $attempt failed for $p"
    [ $attempt -eq 2 ] && fail=$((fail+1))
    sleep 3
  done
done
echo "=== done: $ok ok, $fail failed ==="
