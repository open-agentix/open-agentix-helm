# Security model of the chart

The chart encodes the platform's security model (see the platform's `SECURITY.md` and
`docs/architecture.md`) into Kubernetes defaults. Everything below is on by default; turning
something off is an explicit, reviewable values change.

## Secrets

- No secret is ever read from `values.yaml`. Every secret is referenced by Secret name + key:
  database (`externalDatabase.existingSecret`), run-token HMAC key (`runToken.existingSecret`,
  required), audit checkpoint Ed25519 key (`audit.signingKey.existingSecret`), OIDC client secret,
  LDAP bind password, bootstrap admin password, `/metrics` token, cache URL with password.
- Secrets used by agents (provider API keys, webhook signing secrets, MCP credentials) are
  references by name in the platform. Provide them with `secrets.files` (Secrets projected as
  read-only files into `OAX_SECRETS_DIR`, preferred) or `secrets.env` (`OAX_SECRET_<NAME>` keys).
- `values.schema.json` refuses a plaintext `apiKey` on provider entries.
- The database URL is composed inside the pod (`$(OAX_DB_PASSWORD)` expansion) so the password
  never appears in the rendered manifest. The password must be URL-safe; otherwise put the
  complete URL into the Secret and set `externalDatabase.urlKey`.
- Use an external secret manager (External Secrets Operator, Secrets Store CSI driver, sealed
  secrets) to create these Secrets; the chart only needs their names.

## Pod security

All pods satisfy the PodSecurity `restricted` profile (label your namespace
`pod-security.kubernetes.io/enforce=restricted`):

- `runAsNonRoot`, uid/gid 1000 (`node` in the platform images; 101 for the nginx UI),
- `readOnlyRootFilesystem: true`, `/tmp` is a size-limited `emptyDir`,
- `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, seccomp `RuntimeDefault`,
- `automountServiceAccountToken: false` on every pod (the worker gets a token only when the v0.2
  Kubernetes Job runner is enabled),
- the schema rejects `allowPrivilegeEscalation: true`, `runAsNonRoot: false` and added
  capabilities.

The bundled PostgreSQL/Valkey subcharts get seccomp `RuntimeDefault` added so they pass
`restricted` as well.

## Network

`networkPolicy.enabled: true` renders:

| Policy | Ingress | Egress |
| --- | --- | --- |
| default deny (all release pods) | none | none |
| api | ingress controller (`networkPolicy.ingress.from`), worker pods, Prometheus (`metricsFrom`), run Jobs (v0.2) | DNS, database, cache, OTLP (`egress.otel`), identity providers (`egress.auth`) |
| worker | none | DNS, database, cache, API, OTLP, model providers (`egress.providers`), MCP servers (`egress.mcp`), event sources (`egress.eventSources`), Kubernetes API (v0.2) |
| ui | ingress controller | none |
| migrations | none | DNS, database |
| run Jobs (v0.2, runs namespace) | none | DNS, API |

This mirrors the platform's non-negotiable "no outbound calls except configured providers, MCP
servers and event sources". When `egress.database` is empty the database rule is limited by port
only; list the database CIDR or selector to restrict it further. NOTES.txt warns when OIDC/LDAP,
Bedrock or OTLP is enabled without a matching egress rule.

## Identity and RBAC

- Separate ServiceAccounts for api and worker; IRSA annotations only where needed (worker for
  Bedrock).
- The chart creates no ClusterRole. The v0.2 Job runner gets a namespaced Role in the dedicated
  runs namespace (jobs, pods read, pods/log read, secrets create/delete for per-run credentials).
- Toolbox images for worker nodes are allowlisted by digest (`runners.toolboxes.allowlist`);
  enforce signatures with an admission policy (Kyverno / sigstore policy-controller).

## Audit trail

- The application database role must not have UPDATE/DELETE on the audit tables; use separate
  roles for the app and the migrations Job (`externalDatabase.migrations.*`).
- Configure `audit.signingKey.existingSecret` so checkpoints are signed; keep old public keys in
  `audit.publicKeys` after a rotation (they are public, not secret).

## Supply chain

- Images can be pinned by digest (`image.*.digest`); air-gapped installs should mirror and pin.
- Chart dependencies are pinned by version and their archive SHA-256 is verified in CI
  (`dependency-digests.txt`). GitHub Actions are pinned by commit SHA.
- Signing the chart with cosign and publishing it as an OCI artifact is on the roadmap.

Report vulnerabilities privately, see [SECURITY.md](../SECURITY.md).
