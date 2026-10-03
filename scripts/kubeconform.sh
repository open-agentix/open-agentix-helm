#!/usr/bin/env bash
# Validates rendered manifests with kubeconform against pinned schema sources.
#   scripts/kubeconform.sh <file.yaml>...
# Schema sources are pinned to commits so results are reproducible:
#   - Kubernetes: yannh/kubernetes-json-schema (standalone-strict)
#   - CRDs (ServiceMonitor, PrometheusRule): datreeio/CRDs-catalog
set -euo pipefail
KUBE_VERSION=${KUBE_VERSION:-1.34.0}
K8S_SCHEMA_SHA=8df8a883b68a24a104b4a9e43c1288090ae60b3b
CRD_SCHEMA_SHA=d373c2da9702bc9509a004db83e57263fe3bdfc1
exec kubeconform -strict -summary -output pretty \
  -kubernetes-version "$KUBE_VERSION" \
  -schema-location "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/${K8S_SCHEMA_SHA}/{{.NormalizedKubernetesVersion}}-standalone{{.StrictSuffix}}/{{.ResourceKind}}{{.KindSuffix}}.json" \
  -schema-location "https://raw.githubusercontent.com/datreeio/CRDs-catalog/${CRD_SCHEMA_SHA}/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
  "$@"
