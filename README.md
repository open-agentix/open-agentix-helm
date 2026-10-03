# open-agentix Helm charts

> **open-agentix – the agentic platform. Built by agentix-zero, an AI agent. That is how much we
> trust our goal and vision.**
>
> *open-agentix – die agentische Plattform. Gebaut von agentix-zero, einem KI-Agenten. So sehr
> vertrauen wir unserem Ziel und unserer Vision.*

Helm chart for [open-agentix](https://github.com/open-agentix/open-agentix), the open-source,
self-hostable agent platform: events come in, agents act on them through MCP tools and APIs, and
every step is policy-checked, audited and cost-tracked.

agentix-zero is the project's agent account; humans review and own every decision (maintainer:
the project lead). See [GOVERNANCE.md](GOVERNANCE.md).

| Chart | Version | App version | Path |
| --- | --- | --- | --- |
| `open-agentix` | 0.1.0 | 0.1.0 | [`charts/open-agentix`](charts/open-agentix) |

## What gets deployed

```
                    Ingress (nginx / AWS ALB)
                     |                 |
              /v1, /openapi.json       /   (optional)
                     |                 |
   control node:   api (Deployment, HPA, PDB)      ui (nginx-unprivileged, optional)
                     |
   data plane:     worker (Deployment, HPA)  -- in-process runner (MVP)
                     |                           Kubernetes Job runner prepared for v0.2
   hooks:          migrations Job (pre-install / pre-upgrade)
                     |
   data:           PostgreSQL 16+ (external by default, bundled optional)
                   Valkey/Redis cache (optional, external by default)
```

Hardened by default:

- PodSecurity `restricted`: non-root (uid 1000), read-only root file system, all capabilities
  dropped, no privilege escalation, seccomp `RuntimeDefault`, no ServiceAccount token mounted.
- NetworkPolicies: default deny for every pod of the release, explicit egress only to DNS, the
  database, the cache and the providers / MCP servers / event sources you list.
- No secret in values: every secret (database, run-token key, audit signing key, OIDC client
  secret, LDAP bind password, admin password, metrics token, provider keys) comes from an
  existing Kubernetes Secret. The schema rejects plaintext provider keys.
- Strict `values.schema.json`: unknown keys and insecure security contexts fail at install time.

## Requirements

- Kubernetes >= 1.27 (tested in CI against 1.34 schemas), Helm >= 3.14.
- PostgreSQL 16 or newer (external) — or `postgresql.enabled=true` for tests and homelabs.
- A CNI that enforces NetworkPolicies (Calico, Cilium, AWS VPC CNI with network policy agent, ...). Without it the policies are inert.
- Prometheus Operator CRDs only if `observability.serviceMonitor/prometheusRule.enabled`.

## Install

### 1. Prepare secrets

Nothing secret goes into values. Create the Secrets first (names are examples):

```bash
kubectl create namespace openagentix
kubectl label namespace openagentix pod-security.kubernetes.io/enforce=restricted

# Database password of the application role (URL-safe characters only) - or a full URL, see urlKey
kubectl -n openagentix create secret generic oax-db --from-literal=password="$(openssl rand -hex 24)"

# HMAC key for run tokens between control node and workers (>= 32 characters)
kubectl -n openagentix create secret generic oax-run-token --from-literal=run-token-secret="$(openssl rand -hex 32)"

# Ed25519 key that signs audit checkpoints (recommended)
openssl genpkey -algorithm ed25519 -out ed25519.pem
kubectl -n openagentix create secret generic oax-audit-signing-key --from-file=ed25519.pem && shred -u ed25519.pem

# Optional: local bootstrap admin (>= 12 characters)
kubectl -n openagentix create secret generic oax-admin --from-literal=password="$(openssl rand -base64 18)"
```

Prepare the database roles once with
[`deploy/sql/roles.sql`](https://github.com/open-agentix/open-agentix/blob/main/deploy/sql/roles.sql)
of the platform (application role `openagentix_app` without UPDATE/DELETE on the audit tables,
owner role `openagentix_migrator` for the migrations Job).

### 2. Install the chart

From a checkout of this repository (OCI publishing is on the [roadmap](ROADMAP.md)):

```bash
helm dependency build charts/open-agentix      # only needed for the bundled PostgreSQL/Valkey
helm install oax charts/open-agentix -n openagentix -f examples/values-minimal.yaml
kubectl -n openagentix get pods
```

Example values:

| File | Scenario |
| --- | --- |
| [`examples/values-minimal.yaml`](examples/values-minimal.yaml) | external PostgreSQL, local admin, simulated provider, no ingress |
| [`examples/values-eks.yaml`](examples/values-eks.yaml) | Amazon EKS: IRSA, ALB, Bedrock VPC endpoint, RDS, ElastiCache, OIDC, Prometheus Operator |
| [`examples/values-airgapped.yaml`](examples/values-airgapped.yaml) | no internet egress, internal registry with digests, Ollama in-cluster, LDAP |
| [`examples/values-homelab.yaml`](examples/values-homelab.yaml) | single node, external PostgreSQL on the LAN, nginx + cert-manager |

`helm dependency build` downloads the two optional subcharts (pinned versions, see
`charts/open-agentix/Chart.yaml`) from the groundhog2k chart repository; verify them with
`(cd charts/open-agentix && sha256sum -c dependency-digests.txt)`. Nothing is vendored in this
repository. Helm refuses to render the chart until the dependencies are built, even when both
are disabled.

### 3. Upgrade

```bash
helm upgrade oax charts/open-agentix -n openagentix -f my-values.yaml
```

The migrations Job runs as a `pre-upgrade` hook with the new image before any pod is replaced; if
it fails the upgrade stops and the old version keeps running. Details, rollback and the
compatibility rules: [docs/upgrades.md](docs/upgrades.md).

### Uninstall

```bash
helm uninstall oax -n openagentix
```

Secrets you created and the database are left untouched. With the bundled PostgreSQL the
PersistentVolumeClaim is kept (`postgresql.storage.keepPvc: true`); delete it yourself when the
data is no longer needed.

## Configuration

All values with defaults: [charts/open-agentix/README.md](charts/open-agentix/README.md#values)
(generated from `values.yaml`). The mapping to the platform's environment variables follows the
[configuration contract](https://github.com/open-agentix/open-agentix/blob/main/docs/configuration.md).

Most used settings:

| Topic | Values |
| --- | --- |
| Images | `image.registry`, `image.{api,worker,ui}.{repository,tag,digest}`, `image.pullSecrets` |
| Database | `externalDatabase.*` (`existingSecret`, `urlKey`, `migrations.*`) or `postgresql.enabled` |
| Cache | `cache.enabled` + `cache.existingSecret`/`cache.url`, or `valkey.enabled` |
| Auth | `auth.oidc.*`, `auth.ldap.*`, `auth.bootstrapAdmin.*` (all secrets via `existingSecret`) |
| Keys | `runToken.existingSecret` (required), `audit.signingKey.existingSecret` |
| Providers | `config.providers` (JSON list), `secrets.files` / `secrets.env` for API keys, `aws.bedrock.*` |
| Scaling | `api.autoscaling.*`, `worker.autoscaling.*`, `worker.concurrency`, `*.pdb.*`, `defaultTopologySpread` |
| Network | `networkPolicy.*`, `ingress.*`, `proxy.*` |
| Observability | `observability.serviceMonitor.*`, `observability.prometheusRule.*`, `observability.otel.endpoint` |
| v0.2 preparation | `runners.kubernetesJob.*`, `runners.toolboxes.allowlist` (disabled) |

## Documentation

- [docs/eks.md](docs/eks.md) – Amazon EKS: IRSA for Bedrock, VPC endpoints, ALB, RDS
- [docs/security.md](docs/security.md) – security model of the chart
- [docs/upgrades.md](docs/upgrades.md) – upgrades, migrations, rollback, versioning
- [docs/backup.md](docs/backup.md) – what to back up and how to restore
- [docs/testing.md](docs/testing.md) – unit tests, golden files, kubeconform, coverage

## Development

```bash
scripts/test-local.sh          # runs every check whose tools are installed, reports the rest
```

CI (GitHub-hosted runners, actions pinned by commit SHA) runs `helm lint`, `helm template` with
golden files, kubeconform with pinned schemas, helm-unittest, a template coverage gate (>= 80 %)
and chart-testing. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache-2.0](LICENSE)
