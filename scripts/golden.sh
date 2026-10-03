#!/usr/bin/env bash
# Golden-file test: compares freshly rendered manifests with tests/golden/*.yaml.
#   scripts/golden.sh            compare (exit 1 on any difference)
#   scripts/golden.sh --update   rewrite the golden files after an intended change
# Exit code 2 = bootstrap: no golden files are committed yet (the rendered output is left in
# .out/golden-candidate so it can be reviewed and committed).
set -euo pipefail
cd "$(dirname "$0")/.."
GOLDEN=tests/golden
CANDIDATE=.out/golden-candidate
rm -rf "$CANDIDATE"
scripts/render.sh "$CANDIDATE" >/dev/null

if [ "${1:-}" = "--update" ]; then
  find "$GOLDEN" -name '*.yaml' -delete
  cp "$CANDIDATE"/*.yaml "$GOLDEN"/
  echo "golden: updated $(ls "$GOLDEN"/*.yaml | wc -l) files"
  exit 0
fi

if ! ls "$GOLDEN"/*.yaml >/dev/null 2>&1; then
  echo "golden: no golden files committed yet - review $CANDIDATE and run scripts/golden.sh --update"
  exit 2
fi

status=0
for f in "$CANDIDATE"/*.yaml; do
  g="$GOLDEN/$(basename "$f")"
  if [ ! -f "$g" ]; then
    echo "golden: missing $g (new render case?)"; status=1; continue
  fi
  if ! diff -u "$g" "$f"; then status=1; fi
done
for g in "$GOLDEN"/*.yaml; do
  [ -f "$CANDIDATE/$(basename "$g")" ] || { echo "golden: stale $g (case removed?)"; status=1; }
done
[ $status -eq 0 ] && echo "golden: all $(ls "$GOLDEN"/*.yaml | wc -l) files match"
exit $status
