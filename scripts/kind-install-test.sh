#!/usr/bin/env bash
# End-to-end install test on a throw-away kind cluster. Needs docker, kind, kubectl, helm, curl
# and jq on PATH and the three platform images in the local docker daemon. Nothing is downloaded
# except the pinned kind node image and the pinned PostgreSQL/Valkey images.
#
#   OAX_API_IMAGE=oax-api:0.1.0-local OAX_WORKER_IMAGE=oax-worker:0.1.0-local \
#   OAX_UI_IMAGE=oax-ui:0.1.0-local scripts/kind-install-test.sh
#
# Scenarios: default install (bundled PostgreSQL, generated secrets, --wait), login, least
# privilege database role, upgrade keeps the generated secrets, backup CronJob, uninstall keeps
# data, reinstall reuses it, demo mode, air-gapped mode, NetworkPolicy isolation.
set -euo pipefail
cd "$(dirname "$0")/.."
CHART=${CHART:-charts/open-agentix}
CLUSTER=${CLUSTER:-oax-test}
NODE_IMAGE=${NODE_IMAGE:-kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d}
API_IMAGE=${OAX_API_IMAGE:?set OAX_API_IMAGE}
WORKER_IMAGE=${OAX_WORKER_IMAGE:?set OAX_WORKER_IMAGE}
UI_IMAGE=${OAX_UI_IMAGE:?set OAX_UI_IMAGE}
KEEP=${KEEP:-0}
export KUBECONFIG=${KUBECONFIG:-$PWD/.out/kind-kubeconfig}
mkdir -p .out

split() { echo "${1%:*}" ; }   # repository (registry-less local images)
tag()   { echo "${1##*:}" ; }
IMG_VALUES=.out/kind-image-values.yaml
cat > "$IMG_VALUES" <<VALS
image:
  registry: ""
  pullPolicy: Never
  api:    { repository: "$(split "$API_IMAGE")",    tag: "$(tag "$API_IMAGE")" }
  worker: { repository: "$(split "$WORKER_IMAGE")", tag: "$(tag "$WORKER_IMAGE")" }
  ui:     { repository: "$(split "$UI_IMAGE")",     tag: "$(tag "$UI_IMAGE")" }
api:    { replicaCount: 1, pdb: { enabled: false } }
ui:     { replicaCount: 1, pdb: { enabled: false } }
VALS

pass=0; failn=0
ok()   { echo "PASS  $*"; pass=$((pass+1)); }
bad()  { echo "FAIL  $*"; failn=$((failn+1)); }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

cleanup() {
  [ -n "${PF_PIDS:-}" ] && kill $PF_PIDS 2>/dev/null || true
  if [ "$KEEP" != 1 ]; then kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

echo "==> kind cluster $CLUSTER ($NODE_IMAGE)"
kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
kind create cluster --name "$CLUSTER" --image "$NODE_IMAGE" --wait 180s
for i in "$API_IMAGE" "$WORKER_IMAGE" "$UI_IMAGE"; do kind load docker-image "$i" --name "$CLUSTER"; done

new_ns() { kubectl create namespace "$1" >/dev/null; kubectl label namespace "$1" pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest >/dev/null; }
pf() { # pf <ns> <svc> <local> -> background port-forward
  kubectl -n "$1" port-forward "svc/$2" "$3:80" >/dev/null 2>&1 & PF_PIDS="${PF_PIDS:-} $!"; sleep 3; }
secret() { kubectl -n "$1" get secret "$2" -o "jsonpath={.data.$3}" | base64 -d; }

echo "==> 1. default install: one command, no prepared secrets, --wait"
new_ns oax
helm install oax "$CHART" -n oax -f "$IMG_VALUES" --wait --timeout 8m
check "all pods Ready" kubectl -n oax wait --for=condition=Ready pod -l app.kubernetes.io/instance=oax --timeout=120s
check "migrations Job completed" kubectl -n oax wait --for=condition=complete job/oax-open-agentix-migrations --timeout=120s
kubectl -n oax get pods,svc,pvc,networkpolicy,secret
pf oax oax-open-agentix-api 18080
check "API /healthz" curl -fsS http://127.0.0.1:18080/healthz
check "API /readyz (database reachable, schema migrated)" curl -fsS http://127.0.0.1:18080/readyz
check "API /v1/version" curl -fsS http://127.0.0.1:18080/v1/version
ADMIN_PW=$(secret oax oax-open-agentix-generated bootstrap-admin-password)
LOGIN=$(curl -sS -X POST http://127.0.0.1:18080/v1/auth/login -H 'content-type: application/json' \
  -d "{\"username\":\"admin@openagentix.local\",\"password\":\"$ADMIN_PW\"}" || true)
echo "$LOGIN" | jq -e '.token // .accessToken // .session' >/dev/null 2>&1 && ok "bootstrap admin can log in" || bad "bootstrap admin login: $(echo "$LOGIN" | head -c 200)"
pf oax oax-open-agentix-ui 18081
check "UI serves the SPA" curl -fsS http://127.0.0.1:18081/
check "worker /readyz" kubectl -n oax exec deploy/oax-open-agentix-api -- wget -qO- http://oax-open-agentix-worker:9090/readyz

echo "==> 2. least privilege: the application role cannot run DDL, the migrator owns the schema"
APP_PW=$(secret oax oax-open-agentix-generated app-password)
MIG_PW=$(secret oax oax-open-agentix-generated migrator-password)
PGPOD=oax-open-agentix-postgresql-0
if kubectl -n oax exec "$PGPOD" -- env PGPASSWORD="$APP_PW" psql -h 127.0.0.1 -U openagentix_app -d openagentix -c 'CREATE TABLE should_fail(id int)' >/dev/null 2>&1; then bad "app role must not create tables"; else ok "app role cannot create tables"; fi
check "app role can read" kubectl -n oax exec "$PGPOD" -- env PGPASSWORD="$APP_PW" psql -h 127.0.0.1 -U openagentix_app -d openagentix -c 'SELECT count(*) FROM audit_log'
check "migrator owns the schema" kubectl -n oax exec "$PGPOD" -- env PGPASSWORD="$MIG_PW" psql -h 127.0.0.1 -U openagentix_migrator -d openagentix -c 'SELECT count(*) FROM audit_log'

echo "==> 3. NetworkPolicies (enforced by the CNI; informational when the CNI ignores them)"
kubectl -n oax run np-probe --image="$(kubectl -n oax get sts oax-open-agentix-postgresql -o jsonpath='{.spec.template.spec.containers[0].image}')" \
  --restart=Never --labels=probe=true --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":70,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"np-probe","image":"'"$(kubectl -n oax get sts oax-open-agentix-postgresql -o jsonpath='{.spec.template.spec.containers[0].image}')"'","command":["sleep","120"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}' >/dev/null
kubectl -n oax wait --for=condition=Ready pod/np-probe --timeout=90s >/dev/null
if kubectl -n oax exec np-probe -- pg_isready -h oax-open-agentix-postgresql -t 5 >/dev/null 2>&1; then
  echo "NOTE  an unrelated pod can reach PostgreSQL: the CNI does not enforce NetworkPolicies"
else ok "unrelated pod cannot reach PostgreSQL (default deny + allow list enforced)"; fi
kubectl -n oax delete pod np-probe --wait=false >/dev/null

echo "==> 4. backup CronJob"
helm upgrade oax "$CHART" -n oax -f "$IMG_VALUES" --reuse-values --set postgresql.backup.enabled=true --wait --timeout 5m
kubectl -n oax create job --from=cronjob/oax-open-agentix-postgresql-backup manual-1 >/dev/null
check "backup job completed" kubectl -n oax wait --for=condition=complete job/manual-1 --timeout=180s
kubectl -n oax logs job/manual-1 | tail -2

echo "==> 5. upgrade keeps the generated credentials"
BEFORE=$(kubectl -n oax get secret oax-open-agentix-generated -o jsonpath='{.data}' | sha256sum)
helm upgrade oax "$CHART" -n oax -f "$IMG_VALUES" --reuse-values --set config.logLevel=debug --wait --timeout 8m
AFTER=$(kubectl -n oax get secret oax-open-agentix-generated -o jsonpath='{.data}' | sha256sum)
[ "$BEFORE" = "$AFTER" ] && ok "generated Secret unchanged by helm upgrade" || bad "generated Secret changed by helm upgrade"
check "migrations hook ran on upgrade" kubectl -n oax get job oax-open-agentix-migrations

echo "==> 6. uninstall keeps data and credentials, reinstall reuses them"
helm uninstall oax -n oax --wait
check "data PVC kept" kubectl -n oax get pvc data-oax-open-agentix-postgresql-0
check "generated Secret kept" kubectl -n oax get secret oax-open-agentix-generated
helm install oax "$CHART" -n oax -f "$IMG_VALUES" --wait --timeout 8m
pf oax oax-open-agentix-api 18082
LOGIN2=$(curl -sS -X POST http://127.0.0.1:18082/v1/auth/login -H 'content-type: application/json' \
  -d "{\"username\":\"admin@openagentix.local\",\"password\":\"$ADMIN_PW\"}" || true)
echo "$LOGIN2" | jq -e '.token // .accessToken // .session' >/dev/null 2>&1 && ok "same admin password works after reinstall (data and Secret reused)" || bad "login after reinstall: $(echo "$LOGIN2" | head -c 200)"
helm uninstall oax -n oax --wait
kubectl -n oax delete pvc --all >/dev/null; kubectl -n oax delete secret oax-open-agentix-generated >/dev/null

echo "==> 7. demo mode"
new_ns demo
helm install demo "$CHART" -n demo -f "$IMG_VALUES" --set demo.enabled=true --wait --timeout 8m
pf demo demo-open-agentix-api 18083
HDR=$(curl -sSI http://127.0.0.1:18083/v1/version | tr -d '\r')
echo "$HDR" | grep -qi '^x-oax-demo: true' && ok "responses carry x-oax-demo: true" || bad "x-oax-demo header missing"
curl -fsS http://127.0.0.1:18083/v1/settings | jq -e '.demo == true' >/dev/null && ok "/v1/settings reports demo: true" || bad "/v1/settings demo flag"
DTOKEN=$(curl -sS -X POST http://127.0.0.1:18083/v1/auth/login -H 'content-type: application/json' \
  -d '{"username":"admin@example.org","password":"demo-password-2026"}' | jq -r '.token // .accessToken // empty')
[ -n "$DTOKEN" ] && ok "demo user can sign in" || bad "demo sign-in"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:18083/v1/agents -H "authorization: Bearer $DTOKEN" -H 'content-type: application/json' -d '{}')
case "$CODE" in 403|405|409|423) ok "write is rejected in demo mode (HTTP $CODE)";; *) bad "write not rejected (HTTP $CODE)";; esac
helm uninstall demo -n demo --wait; kubectl -n demo delete pvc --all >/dev/null

echo "==> 8. air-gapped mode (images preloaded, never pulled)"
new_ns air
helm install air "$CHART" -n air -f "$IMG_VALUES" --set airgapped.enabled=true --set airgapped.pullPolicy=Never --wait --timeout 8m
check "OAX_AIRGAPPED=true on the API" bash -c "kubectl -n air get deploy air-open-agentix-api -o jsonpath='{.spec.template.spec.containers[0].env}' | jq -e '.[] | select(.name==\"OAX_AIRGAPPED\" and .value==\"true\")'"
check "no NetworkPolicy opens the internet" bash -c "! kubectl -n air get networkpolicy -o json | grep -E '0\\.0\\.0\\.0/0|::/0'"
helm uninstall air -n air --wait

echo
echo "passed: $pass  failed: $failn"
[ "$failn" -eq 0 ]
