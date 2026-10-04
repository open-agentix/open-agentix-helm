# Install

## One command

The chart is self-contained: PostgreSQL is part of it, every secret is generated, the UI is
included. No other chart, repository or operator is needed.

```bash
helm install oax ./charts/open-agentix -n openagentix --create-namespace
kubectl -n openagentix get pods -w
```

What this installs: the control node (`api`, 2 replicas), the `worker`, the `ui`, a hardened
single-instance PostgreSQL (StatefulSet with a PVC), the migrations Job and default-deny
NetworkPolicies. The simulated model provider is configured, so agents can run immediately.

Sign in with the generated local admin (the command is also printed by `helm install`):

```bash
kubectl -n openagentix get secret oax-open-agentix-generated \
  -o jsonpath='{.data.bootstrap-admin-password}' | base64 -d; echo
kubectl -n openagentix port-forward svc/oax-open-agentix-ui 8080:80      # UI
kubectl -n openagentix port-forward svc/oax-open-agentix-api 8081:80     # API (curl :8081/v1/version)
```

The user name is `auth.bootstrapAdmin.email` (default `admin@openagentix.local`). Change the
password in the UI after the first login.

> The bundled PostgreSQL is for evaluation, demos and homelabs. For production use a managed
> database, see [External PostgreSQL](#external-postgresql-production).

## Requirements

- Kubernetes >= 1.27, Helm >= 3.14, a StorageClass for the PostgreSQL volume.
- A CNI that enforces NetworkPolicies (Calico, Cilium, AWS VPC CNI with the network policy agent).
  Without one the policies are inert; the chart still works.
- The namespace may enforce PodSecurity `restricted`; every pod of the chart complies:

  ```bash
  kubectl label namespace openagentix pod-security.kubernetes.io/enforce=restricted
  ```

## How the generated secrets work

The chart creates the Secret `<release>-open-agentix-generated` on the first install and reads it
back with `lookup` on every upgrade, so values never change. It holds the run-token HMAC key, the
database passwords, the audit checkpoint Ed25519 key, the bootstrap admin password and (with
`valkey.enabled`) the cache password. The Secret is annotated `helm.sh/resource-policy: keep`: it
survives `helm uninstall`, because the kept database volume still contains the old passwords.

`lookup` is empty under `helm template`, `helm install --dry-run` and GitOps renderers (Argo CD
renders without cluster access). There, create the Secrets yourself and reference them; every
generated credential has an `existingSecret` value:

| Credential | Value | Keys |
| --- | --- | --- |
| Run-token HMAC key | `runToken.existingSecret` | `runToken.key` (`run-token-secret`) |
| Database passwords (bundled) | `postgresql.auth.existingSecret` | `postgresql.auth.keys.{postgres,app,migrator}` |
| Audit signing key | `audit.signingKey.existingSecret` | `audit.signingKey.key` (`ed25519.pem`) |
| Admin password | `auth.bootstrapAdmin.existingSecret` | `auth.bootstrapAdmin.passwordKey` |
| Valkey password | `valkey.auth.existingSecret` | `valkey.auth.key` |

```bash
kubectl -n openagentix create secret generic oax-run-token \
  --from-literal=run-token-secret="$(openssl rand -hex 32)"
openssl genpkey -algorithm ed25519 -out ed25519.pem
kubectl -n openagentix create secret generic oax-audit-key --from-file=ed25519.pem && shred -u ed25519.pem
helm install oax ./charts/open-agentix -n openagentix \
  --set runToken.existingSecret=oax-run-token --set audit.signingKey.existingSecret=oax-audit-key
```

## External PostgreSQL (production)

Create the roles once with the platform's
[`deploy/sql/roles.sql`](https://github.com/open-agentix/open-agentix/blob/main/deploy/sql/roles.sql)
(application role without UPDATE/DELETE on the audit tables, owner role for the migrations), then:

```bash
kubectl -n openagentix create secret generic oax-db --from-literal=password='<url-safe password>'
kubectl -n openagentix create secret generic oax-db-migrator --from-literal=password='<url-safe password>'
helm install oax ./charts/open-agentix -n openagentix \
  --set postgresql.enabled=false \
  --set externalDatabase.host=postgres.example.internal \
  --set externalDatabase.sslmode=verify-full \
  --set externalDatabase.existingSecret=oax-db \
  --set externalDatabase.migrations.user=openagentix_migrator \
  --set externalDatabase.migrations.existingSecret=oax-db-migrator
```

With an external database the migrations Job is a `pre-install,pre-upgrade` hook, so the schema is
ready before any pod starts. Allow the database in the NetworkPolicy
(`networkPolicy.egress.database`). [`docs/eks.md`](eks.md) shows RDS with IAM-friendly settings.

## Ingress or Gateway API

```bash
helm upgrade --install oax ./charts/open-agentix -n openagentix \
  --set ingress.enabled=true --set ingress.className=nginx \
  --set ingress.host=agents.example.com --set ingress.tls.enabled=true \
  --set ingress.tls.secretName=agents-tls
```

`/v1` and `/openapi.json` go to the API, everything else to the UI. For the Gateway API use an
HTTPRoute instead (mutually exclusive with the Ingress; needs the Gateway API CRDs and a Gateway):

```yaml
gateway:
  enabled: true
  tls: true                 # only affects the public URL (https://)
  hostnames: [agents.example.com]
  parentRefs:
    - { name: shared-gateway, namespace: gateways, sectionName: https }
networkPolicy:
  ingress:
    from:                   # peers of the Gateway data plane
      - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: gateways } }
```

## Valkey cache, scaling, monitoring

- `valkey.enabled=true` deploys a small password-protected Valkey and sets `OAX_CACHE_URL`
  (shared cache and invalidation across API replicas). Use `cache.*` for an external one.
- `api.autoscaling.enabled` / `worker.autoscaling.enabled` create HorizontalPodAutoscalers;
  PodDisruptionBudgets are on by default.
- `observability.serviceMonitor.enabled` and `observability.prometheusRule.enabled` need the
  Prometheus Operator CRDs; protect `/metrics` with `observability.metrics.existingSecret`.

## Providers, OIDC, LDAP

Providers and prices are plain values (`config.providers`, `config.priceTable`); API keys are
referenced by name and come from Secrets (`secrets.files` / `secrets.env`), never from values:

```yaml
config:
  providers:
    - { kind: simulated, name: simulated }
    - { kind: anthropic, name: anthropic, apiKeySecret: anthropic-key }
secrets:
  files: [oax-provider-keys]       # a Secret with the key "anthropic-key"
networkPolicy:
  egress:
    providers:
      - to: [{ ipBlock: { cidr: 0.0.0.0/0, except: [10.0.0.0/8] } }]
        ports: [{ protocol: TCP, port: 443 }]
```

OIDC (`auth.oidc.*`) and LDAP (`auth.ldap.*`) keep their secrets in `existingSecret`; open the
egress to the identity provider with `networkPolicy.egress.auth`. Amazon Bedrock with IRSA:
[`docs/eks.md`](eks.md).

## Presets

| File | Scenario |
| --- | --- |
| [`examples/values-minimal.yaml`](../examples/values-minimal.yaml) | defaults, nothing required |
| [`examples/values-demo.yaml`](../examples/values-demo.yaml) | public read-only demo ([demo.md](demo.md)) |
| [`examples/values-airgapped.yaml`](../examples/values-airgapped.yaml) | offline cluster ([airgapped.md](airgapped.md)) |
| [`examples/values-eks.yaml`](../examples/values-eks.yaml) | Amazon EKS: IRSA, ALB, RDS, ElastiCache, OIDC |
| [`examples/values-homelab.yaml`](../examples/values-homelab.yaml) | single node, nginx + cert-manager |

## Upgrade

See [upgrades.md](upgrades.md). In short: `helm upgrade oax ./charts/open-agentix -n openagentix
-f my-values.yaml`; the migrations Job runs first.

## Uninstall

```bash
helm uninstall oax -n openagentix
```

Kept on purpose, so that data and credentials are never lost by accident:

| Kept | Why | Delete with |
| --- | --- | --- |
| PostgreSQL data PVC `data-<release>-open-agentix-postgresql-0` | your database | `kubectl -n openagentix delete pvc -l app.kubernetes.io/instance=oax` |
| Backup PVC (`postgresql.backup`) | your dumps | same command |
| Secret `<release>-open-agentix-generated` | passwords belonging to the kept volume | `kubectl -n openagentix delete secret oax-open-agentix-generated` |

For a complete removal delete the PVCs and the Secret after `helm uninstall`, then the namespace.
Reinstalling with the kept PVC and Secret restores the previous state.
