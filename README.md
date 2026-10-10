# open-agentix Helm charts

> **open-agentix – the agentic platform. Built by agentix-zero, an AI agent. That is how much we
> trust our goal and vision.**
>
> *open-agentix – die agentische Plattform. Gebaut von agentix-zero, einem KI-Agenten. So sehr
> vertrauen wir unserem Ziel und unserer Vision.*

Helm chart for [open-agentix](https://github.com/open-agentix/open-agentix), the open-source,
self-hostable agent platform: events come in, agents act on them through MCP tools and APIs, and
every step is policy-checked, audited and cost-tracked.

agentix-zero is the project's agent account; humans review and own every decision. See
[GOVERNANCE.md](GOVERNANCE.md).

| Chart | Version | App version | Path |
| --- | --- | --- | --- |
| `open-agentix` | 0.2.1 | 0.1.0 | [`charts/open-agentix`](charts/open-agentix) |

## One command

```bash
helm install oax ./charts/open-agentix -n openagentix --create-namespace
```

That installs a complete working stack without any other chart, operator or prepared Secret: API,
worker, UI, a hardened PostgreSQL with a PVC, the migrations Job, generated credentials and
default-deny NetworkPolicies. See [docs/install.md](docs/install.md) for sign-in, production
settings and uninstall.

## What gets deployed

```
                    Ingress (nginx / ALB) or Gateway API HTTPRoute
                     |                 |
              /v1, /openapi.json       /
                     |                 |
   control node:   api (Deployment, HPA, PDB)      ui (nginx-unprivileged)
                     |
   data plane:     worker (Deployment, HPA)  -- in-process runner (MVP)
                     |                           Kubernetes Job runner prepared for v0.2
   hooks:          migrations Job (post-install / pre-upgrade with the bundled DB,
                     |             pre-install / pre-upgrade with an external DB)
   data:           PostgreSQL 16 (bundled StatefulSet + PVC + optional backup CronJob,
                                  or external: RDS, CloudNativePG, ...)
                   Valkey cache (optional, bundled or external)
```

Hardened by default:

- PodSecurity `restricted` for every pod, including PostgreSQL and Valkey: non-root, read-only root
  file system, all capabilities dropped, no privilege escalation, seccomp `RuntimeDefault`, no
  ServiceAccount token mounted.
- NetworkPolicies: default deny for every pod of the release, explicit egress only to DNS, the
  database, the cache and the providers / MCP servers / event sources you list; the bundled
  PostgreSQL and Valkey accept connections only from the chart's own pods and have no egress.
- No secret in values: credentials are generated once by the chart (random, kept via `lookup`,
  kept on uninstall) or referenced from existing Kubernetes Secrets (`existingSecret`).
- Strict `values.schema.json`: unknown keys and insecure security contexts fail at install time.
- Modes: `demo.enabled` (read-only public demo), `airgapped.enabled` (no pulls, no internet egress,
  private registry), `postgresql.enabled=false` for a managed database.

## Requirements

- Kubernetes >= 1.27 (tested in CI against 1.34 schemas), Helm >= 3.14.
- Nothing else: PostgreSQL is bundled. For production use PostgreSQL 16 or newer as an external service.
- A StorageClass (default class) for the PostgreSQL volume.
- A CNI that enforces NetworkPolicies (Calico, Cilium, AWS VPC CNI with network policy agent, ...). Without it the policies are inert.
- Prometheus Operator CRDs only if `observability.serviceMonitor/prometheusRule.enabled`.

## Install

```bash
helm install oax ./charts/open-agentix -n openagentix --create-namespace       # everything included
helm install oax ./charts/open-agentix -n openagentix -f examples/values-eks.yaml   # a preset
```

OCI publishing is on the [roadmap](ROADMAP.md); until then install from a checkout. Nothing is
downloaded: the chart has no sub-chart dependencies.

Presets:

| File | Scenario |
| --- | --- |
| [`examples/values-minimal.yaml`](examples/values-minimal.yaml) | defaults: bundled PostgreSQL, generated secrets, simulated provider |
| [`examples/values-demo.yaml`](examples/values-demo.yaml) | public read-only demo with seeded fake data ([docs/demo.md](docs/demo.md)) |
| [`examples/values-airgapped.yaml`](examples/values-airgapped.yaml) | offline cluster: private registry, no internet egress, Ollama in-cluster, LDAP ([docs/airgapped.md](docs/airgapped.md)) |
| [`examples/values-eks.yaml`](examples/values-eks.yaml) | Amazon EKS: IRSA, ALB, Bedrock VPC endpoint, RDS, ElastiCache, OIDC, Prometheus Operator |
| [`examples/values-homelab.yaml`](examples/values-homelab.yaml) | single node, bundled PostgreSQL with backups, nginx + cert-manager |

Production: use an external PostgreSQL (`postgresql.enabled=false`), keep secrets in your secret
manager and reference them with `existingSecret` ([docs/install.md](docs/install.md)).

### Upgrade

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

The database volume (bundled PostgreSQL), the backup volume and the generated Secret are kept on
purpose; [docs/install.md](docs/install.md#uninstall) lists the commands to delete them.

## Configuration

All values with defaults: [charts/open-agentix/README.md](charts/open-agentix/README.md#values)
(generated from `values.yaml`). The mapping to the platform's environment variables follows the
[configuration contract](https://github.com/open-agentix/open-agentix/blob/main/docs/configuration.md).

Most used settings:

| Topic | Values |
| --- | --- |
| Images | `image.registry`, `image.{api,worker,ui}.{repository,tag,digest}`, `image.pullSecrets` |
| Database | bundled: `postgresql.*` (`persistence`, `backup`, `auth.existingSecret`); external: `postgresql.enabled=false` + `externalDatabase.*` |
| Cache | `valkey.enabled`, or `cache.enabled` + `cache.existingSecret`/`cache.url` |
| Auth | `auth.oidc.*`, `auth.ldap.*`, `auth.bootstrapAdmin.*` (all secrets via `existingSecret`) |
| Keys | `runToken.existingSecret`, `audit.signingKey.existingSecret` (both generated when empty) |
| Providers | `config.providers` (JSON list), `secrets.files` / `secrets.env` for API keys, `aws.bedrock.*` |
| Scaling | `api.autoscaling.*`, `worker.autoscaling.*`, `worker.concurrency`, `*.pdb.*`, `defaultTopologySpread` |
| Network | `networkPolicy.*`, `ingress.*` or `gateway.*`, `proxy.*` |
| Modes | `demo.enabled`, `airgapped.{enabled,registry,pullPolicy,pullSecrets}` |
| Observability | `observability.serviceMonitor.*`, `observability.prometheusRule.*`, `observability.otel.{endpoint,protocol,insecure,headersSecret,resourceAttributes,exceptionDetail}` |
| v0.2 preparation | `runners.kubernetesJob.*`, `runners.toolboxes.allowlist` (disabled) |

## Documentation

- [docs/install.md](docs/install.md) – install, generated secrets, production, Gateway API, uninstall
- [docs/demo.md](docs/demo.md) – read-only public demo
- [docs/airgapped.md](docs/airgapped.md) – offline bundle and air-gapped values
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

Questions and discussion: [GitHub Discussions](https://github.com/open-agentix/open-agentix-helm/discussions) and [Issues](https://github.com/open-agentix/open-agentix-helm/issues). General contact: info@openagentix.si.

## License

[Apache-2.0](LICENSE)
