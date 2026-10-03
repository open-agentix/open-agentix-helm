#!/usr/bin/env bash
# Renders the chart for every render case into an output directory (one file per case).
#   scripts/render.sh [outdir]          default: .out/rendered
# Cases: examples/values-*.yaml, charts/open-agentix/ci/*-values.yaml, tests/values/*.yaml
# Requires helm (and `helm dependency build` for cases with bundled subcharts).
set -euo pipefail
cd "$(dirname "$0")/.."
CHART=charts/open-agentix
OUT=${1:-.out/rendered}
KUBE_VERSION=${KUBE_VERSION:-1.34.0}
mkdir -p "$OUT"

cases() {
  ls examples/values-*.yaml "$CHART"/ci/*-values.yaml tests/values/*.yaml
}

for f in $(cases); do
  name=$(basename "$f" .yaml)
  [ "$(dirname "$f")" = "$CHART/ci" ] && name="ci-$name"
  [ "$(dirname "$f")" = "tests/values" ] && name="case-$name"
  helm template oax "$CHART" --namespace openagentix --kube-version "$KUBE_VERSION" \
    -f "$f" > "$OUT/$name.yaml"
  echo "rendered $f -> $OUT/$name.yaml"
done
