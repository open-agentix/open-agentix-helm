#!/usr/bin/env bash
# Local test entry point. Runs every check whose tools are installed and reports the rest as
# skipped (CI runs all of them). Nothing is downloaded: install helm, the helm-unittest plugin
# and kubeconform yourself (pinned versions in .github/workflows/ci.yaml).
set -uo pipefail
cd "$(dirname "$0")/.."
CHART=charts/open-agentix
KUBE_VERSION=${KUBE_VERSION:-1.34.0}
fail=0
ran=()
skipped=()

step() { echo; echo "==> $*"; }
run() { if "$@"; then return 0; else fail=1; return 1; fi; }

step "template structure (offline)"
run python3 scripts/check-templates.py "$CHART" && ran+=("check-templates")

step "values files against values.schema.json"
if command -v node >/dev/null; then
  run node scripts/validate-values.cjs "$CHART" examples/*.yaml "$CHART"/ci/*.yaml tests/values/*.yaml \
    && ran+=("validate-values")
else
  skipped+=("validate-values (node missing)")
fi

step "unit test template coverage (>= 80 %)"
run python3 scripts/coverage.py "$CHART" --min 80 >/dev/null && ran+=("coverage") && \
  python3 scripts/coverage.py "$CHART" | tail -1

if command -v helm >/dev/null; then
  step "helm lint"
  for f in examples/*.yaml "$CHART"/ci/*.yaml; do
    run helm lint "$CHART" --strict -f "$f" --quiet || echo "lint failed: $f"
  done
  ran+=("helm lint")

  step "helm template + golden files"
  scripts/golden.sh; rc=$?
  case $rc in
    0) ran+=("golden") ;;
    2) skipped+=("golden (bootstrap: no golden files yet)") ;;
    *) fail=1 ;;
  esac

  if command -v kubeconform >/dev/null; then
    step "kubeconform"
    run scripts/kubeconform.sh .out/golden-candidate/*.yaml
    ran+=("kubeconform")
  else
    skipped+=("kubeconform (binary missing)")
  fi

  if helm plugin list 2>/dev/null | grep -q '^unittest'; then
    step "helm unittest"
    run helm unittest "$CHART" && ran+=("helm unittest")
  else
    skipped+=("helm unittest (plugin missing)")
  fi
else
  skipped+=("helm lint" "helm template/golden" "kubeconform" "helm unittest" "(helm binary missing)")
fi

echo
echo "ran:     ${ran[*]:-none}"
echo "skipped: ${skipped[*]:-none}"
exit $fail
