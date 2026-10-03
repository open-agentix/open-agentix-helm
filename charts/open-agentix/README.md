# open-agentix Helm chart

> **open-agentix – the agentic platform.** Built by agentix-zero, an AI agent. That is how much
> we trust our goal and vision.

Deploys the open-agentix control node (API, optional UI), the worker and the database migrations
onto Kubernetes (including Amazon EKS) with hardened defaults: PodSecurity `restricted`, read-only
root file systems, default-deny NetworkPolicies with explicit egress, and every secret taken from
an existing Kubernetes Secret.

- Chart version: `0.1.0` · App version: `0.1.0` · Kubernetes `>= 1.27`
- Installation, upgrades and the security model: see the
  [repository README](https://github.com/open-agentix/open-agentix-helm#readme) and `docs/`.
- Application configuration contract: platform
  [`docs/configuration.md`](https://github.com/open-agentix/open-agentix/blob/main/docs/configuration.md).

## Quick start

```bash
kubectl create namespace openagentix
kubectl -n openagentix create secret generic oax-db --from-literal=password='<url-safe password>'
kubectl -n openagentix create secret generic oax-run-token --from-literal=run-token-secret="$(openssl rand -hex 32)"
helm install oax ./charts/open-agentix -n openagentix \
  --set externalDatabase.host=postgres.example.internal \
  --set externalDatabase.existingSecret=oax-db \
  --set runToken.existingSecret=oax-run-token
```

## Values

Generated from the `# --` comments in `values.yaml` by `scripts/values-table.py`
(CI fails when this table is out of date). `values.schema.json` rejects unknown keys.

<!-- values-table:start -->
| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `nameOverride` | string | `""` | Override the chart name used in resource names. |
| `fullnameOverride` | string | `""` | Override the full resource name prefix. |
| `commonLabels` | object | `{}` | Labels added to every resource. |
| `commonAnnotations` | object | `{}` | Annotations added to every resource. |
| `global` | object | `{}` | Global values shared with subcharts (Helm convention). |
| `defaultTopologySpread` | bool | `true` | Render soft topology spread (zone + node) for components whose `topologySpreadConstraints` list is empty. |
| `image.registry` | string | `"ghcr.io"` | Registry of the platform images. |
| `image.pullPolicy` | string | `"IfNotPresent"` | Image pull policy for all platform images. |
| `image.pullSecrets` | list | `[]` | Names of existing image pull secrets (`kubernetes.io/dockerconfigjson`). |
| `image.api.repository` | string | `"open-agentix/open-agentix-api"` | Repository of the control node image (also runs the migrations Job). |
| `image.api.tag` | string | `""` | Tag; defaults to the chart appVersion. |
| `image.api.digest` | string | `""` | Digest (`sha256:...`). When set it is appended to the reference and pins the image. |
| `image.worker.repository` | string | `"open-agentix/open-agentix-worker"` | Repository of the worker image. |
| `image.worker.tag` | string | `""` | Tag; defaults to the chart appVersion. |
| `image.worker.digest` | string | `""` | Digest (`sha256:...`). |
| `image.ui.repository` | string | `"open-agentix/open-agentix-ui"` | Repository of the static UI image (nginx-unprivileged based, listens on 8080). |
| `image.ui.tag` | string | `""` | Tag; defaults to the chart appVersion. |
| `image.ui.digest` | string | `""` | Digest (`sha256:...`). |
| `config.publicUrl` | string | `""` | `OAX_PUBLIC_URL`. Empty = derived from `ingress.host` (https when `ingress.tls.enabled`). |
| `config.uiUrl` | string | `""` | `OAX_UI_URL`. Empty = same as the public URL when `ui.enabled`. |
| `config.corsOrigins` | list | `[]` | `OAX_CORS_ORIGINS`. Only needed when the UI is served from a different origin. |
| `config.trustProxy` | null | `null` | `OAX_TRUST_PROXY`. `null` = true when `ingress.enabled`, else false. |
| `config.logLevel` | string | `"info"` | `OAX_LOG_LEVEL` (fatal, error, warn, info, debug, trace, silent). |
| `config.bodyLimitBytes` | int | `1048576` | `OAX_BODY_LIMIT_BYTES`. |
| `config.database.poolMax` | int | `20` | `OAX_DB_POOL_MAX` per process. |
| `config.database.statementTimeoutMs` | int | `15000` | `OAX_DB_STATEMENT_TIMEOUT_MS`. |
| `config.cache.maxEntries` | int | `10000` | `OAX_CACHE_MAX_ENTRIES` of the in-memory LRU. |
| `config.cache.authTtlSeconds` | int | `30` | `OAX_AUTH_CACHE_TTL_SECONDS`. |
| `config.session.ttlSeconds` | int | `28800` | `OAX_SESSION_TTL_SECONDS`. |
| `config.session.tokenMaxTtlDays` | int | `365` | `OAX_TOKEN_MAX_TTL_DAYS`. |
| `config.rateLimit.max` | int | `600` | `OAX_RATE_LIMIT_MAX` requests per minute per token/IP. |
| `config.rateLimit.loginMax` | int | `10` | `OAX_RATE_LIMIT_LOGIN_MAX` login attempts per minute per IP. |
| `config.webhook.toleranceSeconds` | int | `300` | `OAX_WEBHOOK_TOLERANCE_SECONDS`. |
| `config.webhook.maxBytes` | int | `1048576` | `OAX_WEBHOOK_MAX_BYTES`. |
| `config.ssePollMs` | int | `500` | `OAX_SSE_POLL_MS`. |
| `config.control.maxToolCallsPerMinute` | int | `30` | `OAX_CONTROL_MAX_TOOL_CALLS_PER_MINUTE`. |
| `config.control.defaultMaxSteps` | int | `50` | `OAX_DEFAULT_MAX_STEPS`. |
| `config.control.defaultTimeoutSeconds` | int | `1800` | `OAX_DEFAULT_TIMEOUT_SECONDS`. |
| `config.providers` | list | `[{"kind": "simulated", "name": "simulated"}]` | `OAX_PROVIDERS` as a list (rendered as JSON). API keys are secret references (`apiKeySecret`), resolved from `secrets.*`. The Bedrock entry from `aws.bedrock` is appended. |
| `config.priceTable` | list | `[]` | `OAX_PRICE_TABLE` as a list (rendered as JSON). |
| `config.extraEnv` | list | `[]` | Extra environment variables for api, worker and migrations (list of EnvVar). |
| `externalDatabase.host` | string | `""` | Host name of the external PostgreSQL. |
| `externalDatabase.port` | int | `5432` | Port. |
| `externalDatabase.database` | string | `"openagentix"` | Database name. |
| `externalDatabase.user` | string | `"openagentix_app"` | Application user (least-privilege role `openagentix_app`, see backup/security docs). |
| `externalDatabase.sslmode` | string | `"require"` | `sslmode` appended to the URL (`disable`, `require`, `verify-ca`, `verify-full`). |
| `externalDatabase.existingSecret` | string | `""` | Existing Secret with the password (or the full URL, see `urlKey`). Required. |
| `externalDatabase.passwordKey` | string | `"password"` | Key of the password in `existingSecret`. Must be URL-safe (no `@`, `:`, `/`, `%`). |
| `externalDatabase.urlKey` | string | `""` | Key with a complete `postgres://` URL. When set, host/port/user/password are ignored. |
| `externalDatabase.migrations.user` | string | `""` | Optional separate owner role for the migrations Job (`openagentix_migrator`). Empty = app user. |
| `externalDatabase.migrations.existingSecret` | string | `""` | Existing Secret for the migration role. Empty = `externalDatabase.existingSecret`. |
| `externalDatabase.migrations.passwordKey` | string | `"password"` | Key of the migration password. |
| `externalDatabase.migrations.urlKey` | string | `""` | Key with a complete URL for the migration role. |
| `postgresql.enabled` | bool | `false` | Deploy the bundled PostgreSQL instead of using `externalDatabase`. |
| `postgresql.image.tag` | string | `"16.10-alpine"` | PostgreSQL image tag (major 16 like the platform's reference setup). |
| `postgresql.userDatabase.existingSecret` | string | `""` | Existing Secret with keys `database`, `user`, `password` (create it before install). |
| `postgresql.userDatabase.name.secretKey` | string | `"database"` | Key of the database name. |
| `postgresql.userDatabase.user.secretKey` | string | `"user"` | Key of the user name. |
| `postgresql.userDatabase.password.secretKey` | string | `"password"` | Key of the password (URL-safe). |
| `postgresql.settings.existingSecret` | string | `""` | Existing Secret with the superuser password (key `superuser-password`). |
| `postgresql.settings.superuserPassword.secretKey` | string | `"superuser-password"` | Key of the superuser password. |
| `postgresql.storage.requestedSize` | string | `"8Gi"` | Size of the data volume. |
| `postgresql.storage.className` | string | `""` | StorageClass (empty = cluster default). |
| `postgresql.storage.keepPvc` | bool | `true` | Keep the data PVC on `helm uninstall`. |
| `postgresql.podSecurityContext` | object | `{"seccompProfile": {"type": "RuntimeDefault"}}` | Adds seccomp RuntimeDefault so the pod passes PodSecurity `restricted`. |
| `postgresql.securityContext` | object | `{"seccompProfile": {"type": "RuntimeDefault"}}` | Container seccomp profile (merged with the subchart's restricted defaults). |
| `cache.enabled` | bool | `false` | Use an external Valkey/Redis (`OAX_CACHE_URL`). |
| `cache.url` | string | `""` | Non-secret URL (`redis://host:6379`) when the cache has no password. |
| `cache.existingSecret` | string | `""` | Existing Secret holding the URL (use when it contains a password). |
| `cache.urlKey` | string | `"url"` | Key of the URL in `existingSecret`. |
| `valkey.enabled` | bool | `false` | Deploy the bundled Valkey. |
| `valkey.podSecurityContext` | object | `{"seccompProfile": {"type": "RuntimeDefault"}}` | Adds seccomp RuntimeDefault so the pod passes PodSecurity `restricted`. |
| `valkey.securityContext` | object | `{"seccompProfile": {"type": "RuntimeDefault"}}` | Container seccomp profile. |
| `auth.bootstrapAdmin.enabled` | bool | `false` | Create a local admin when the user table is empty. |
| `auth.bootstrapAdmin.email` | string | `""` | `OAX_BOOTSTRAP_ADMIN_EMAIL`. |
| `auth.bootstrapAdmin.existingSecret` | string | `""` | Existing Secret with the password (>= 12 characters). |
| `auth.bootstrapAdmin.passwordKey` | string | `"password"` | Key of the password. |
| `auth.oidc.enabled` | bool | `false` | Enable OIDC login. |
| `auth.oidc.issuer` | string | `""` | `OAX_OIDC_ISSUER`. |
| `auth.oidc.clientId` | string | `""` | `OAX_OIDC_CLIENT_ID`. |
| `auth.oidc.redirectUri` | string | `""` | `OAX_OIDC_REDIRECT_URI`. Empty = `<publicUrl>/v1/auth/oidc/callback`. |
| `auth.oidc.scopes` | string | `"openid profile email"` | `OAX_OIDC_SCOPES`. |
| `auth.oidc.groupsClaim` | string | `"groups"` | `OAX_OIDC_GROUPS_CLAIM`. |
| `auth.oidc.roleMapping` | object | `{}` | `OAX_OIDC_ROLE_MAPPING`: group -> `role`, `role@team-slug` or a list. |
| `auth.oidc.existingSecret` | string | `""` | Existing Secret with the client secret (empty = public client with PKCE). |
| `auth.oidc.clientSecretKey` | string | `"client-secret"` | Key of the client secret. |
| `auth.ldap.enabled` | bool | `false` | Enable LDAP/AD bind login. |
| `auth.ldap.url` | string | `""` | `OAX_LDAP_URL` (`ldaps://...:636`). |
| `auth.ldap.bindDn` | string | `""` | `OAX_LDAP_BIND_DN` of the search service account. |
| `auth.ldap.userBaseDn` | string | `""` | `OAX_LDAP_USER_BASE_DN`. |
| `auth.ldap.userFilter` | string | `"(uid={username})"` | `OAX_LDAP_USER_FILTER`. AD: `(sAMAccountName={username})`. |
| `auth.ldap.groupAttribute` | string | `"memberOf"` | `OAX_LDAP_GROUP_ATTRIBUTE`. |
| `auth.ldap.roleMapping` | object | `{}` | `OAX_LDAP_ROLE_MAPPING`: group DN -> role. |
| `auth.ldap.tlsRejectUnauthorized` | bool | `true` | `OAX_LDAP_TLS_REJECT_UNAUTHORIZED`. |
| `auth.ldap.existingSecret` | string | `""` | Existing Secret with the bind password. |
| `auth.ldap.bindPasswordKey` | string | `"bind-password"` | Key of the bind password. |
| `runToken.existingSecret` | string | `""` | Existing Secret with the run-token HMAC key (>= 32 characters). Required. |
| `runToken.key` | string | `"run-token-secret"` | Key in the Secret. |
| `runToken.ttlSeconds` | int | `14400` | `OAX_RUN_TOKEN_TTL_SECONDS`. |
| `audit.signingKey.existingSecret` | string | `""` | Existing Secret with the Ed25519 private key (PKCS#8 PEM) for audit checkpoints. Empty = checkpoints are not signed (not recommended for production). |
| `audit.signingKey.key` | string | `"ed25519.pem"` | Key in the Secret. |
| `audit.signingKey.keyId` | string | `"default"` | `OAX_AUDIT_SIGNING_KEY_ID`. |
| `audit.publicKeys` | object | `{}` | `OAX_AUDIT_PUBLIC_KEYS`: `{keyId: publicKeyPem}` of rotated keys (public, not secret). |
| `audit.checkpointEvery` | int | `1000` | `OAX_AUDIT_CHECKPOINT_EVERY`. |
| `secrets.files` | list | `[]` | Existing Secrets projected as files into `OAX_SECRETS_DIR` (key = reference name). |
| `secrets.env` | list | `[]` | Existing Secrets loaded with `envFrom` (keys must be `OAX_SECRET_<NAME>`). |
| `secrets.mountPath` | string | `"/var/run/openagentix/secrets"` | Mount path of `secrets.files`. |
| `aws.region` | string | `""` | `AWS_REGION` for the AWS SDK (Bedrock). Empty = not set. |
| `aws.bedrock.enabled` | bool | `false` | Append a Bedrock provider entry to `OAX_PROVIDERS`. |
| `aws.bedrock.name` | string | `"bedrock"` | Provider name referenced by agents. |
| `aws.bedrock.region` | string | `""` | Bedrock region (defaults to `aws.region`). |
| `aws.bedrock.vpcEndpointUrl` | string | `""` | VPC interface endpoint URL (`https://vpce-...bedrock-runtime.<region>.vpce.amazonaws.com`). |
| `aws.bedrock.proxyUrl` | string | `""` | Per-provider HTTPS proxy URL (`http://egress-proxy:3128`). |
| `aws.bedrock.clearance` | string | `"confidential"` | Highest data classification sent to Bedrock. |
| `proxy.httpsProxy` | string | `""` | `HTTPS_PROXY` for SDKs that honour it (AWS SDK). Per-provider `proxyUrl` is preferred. |
| `proxy.httpProxy` | string | `""` | `HTTP_PROXY`. |
| `proxy.noProxy` | string | `""` | `NO_PROXY`. The cluster-internal defaults are always prepended. |
| `observability.otel.endpoint` | string | `""` | `OTEL_EXPORTER_OTLP_ENDPOINT` (OTLP/HTTP). Empty = tracing off. |
| `observability.metrics.existingSecret` | string | `""` | Existing Secret with the bearer token protecting `/metrics` (`OAX_METRICS_TOKEN`). |
| `observability.metrics.key` | string | `"token"` | Key in the Secret. |
| `observability.serviceMonitor.enabled` | bool | `false` | Create a ServiceMonitor (Prometheus Operator CRD required). |
| `observability.serviceMonitor.interval` | string | `"30s"` | Scrape interval. |
| `observability.serviceMonitor.scrapeTimeout` | string | `"10s"` | Scrape timeout. |
| `observability.serviceMonitor.labels` | object | `{}` | Extra labels (e.g. `release: kube-prometheus-stack`). |
| `observability.prometheusRule.enabled` | bool | `false` | Create a PrometheusRule with default alerts. |
| `observability.prometheusRule.labels` | object | `{}` | Extra labels. |
| `observability.prometheusRule.errorRateThreshold` | float | `0.05` | 5xx ratio that fires `OpenAgentixApiErrorRate`. |
| `observability.prometheusRule.latencyP95Seconds` | float | `0.5` | p95 latency (seconds) that fires `OpenAgentixApiLatencyHigh`. |
| `observability.prometheusRule.queueBacklogThreshold` | int | `100` | Queued runs that fire `OpenAgentixRunQueueBacklog`. |
| `observability.prometheusRule.extraRules` | list | `[]` | Extra rules appended to the group. |
| `serviceAccount.api.create` | bool | `true` | Create the control node ServiceAccount. |
| `serviceAccount.api.name` | string | `""` | Name (empty = `<fullname>-api`). |
| `serviceAccount.api.annotations` | object | `{}` | Annotations, e.g. `eks.amazonaws.com/role-arn` (IRSA). |
| `serviceAccount.worker.create` | bool | `true` | Create the worker ServiceAccount. |
| `serviceAccount.worker.name` | string | `""` | Name (empty = `<fullname>-worker`). |
| `serviceAccount.worker.annotations` | object | `{}` | Annotations, e.g. `eks.amazonaws.com/role-arn` for Bedrock (IRSA). |
| `podSecurityContext.runAsNonRoot` | bool | `true` | Run as non-root. |
| `podSecurityContext.runAsUser` | int | `1000` | UID (`node` in the platform images). |
| `podSecurityContext.runAsGroup` | int | `1000` | GID. |
| `podSecurityContext.fsGroup` | int | `1000` | fsGroup for mounted volumes. |
| `podSecurityContext.seccompProfile.type` | string | `"RuntimeDefault"` | Seccomp profile. |
| `containerSecurityContext.allowPrivilegeEscalation` | bool | `false` | No privilege escalation. |
| `containerSecurityContext.readOnlyRootFilesystem` | bool | `true` | Read-only root file system (`/tmp` is an emptyDir). |
| `containerSecurityContext.runAsNonRoot` | bool | `true` | Run as non-root. |
| `containerSecurityContext.capabilities.drop` | list | `["ALL"]` | Dropped capabilities. |
| `containerSecurityContext.seccompProfile.type` | string | `"RuntimeDefault"` | Seccomp profile. |
| `api.replicaCount` | int | `2` | Replicas when autoscaling is off. |
| `api.migrateOnStart` | bool | `false` | `OAX_DB_MIGRATE_ON_START` for the API. Keep false when `migrations.enabled`. |
| `api.resources` | object | `{"requests": {"cpu": "100m", "memory": "256Mi"}, "limits": {"memory": "512Mi"}}` | Resources. |
| `api.service.type` | string | `"ClusterIP"` | Service type. |
| `api.service.port` | int | `80` | Service port. |
| `api.service.annotations` | object | `{}` | Service annotations. |
| `api.autoscaling.enabled` | bool | `false` | Enable the HorizontalPodAutoscaler. |
| `api.autoscaling.minReplicas` | int | `2` | Minimum replicas. |
| `api.autoscaling.maxReplicas` | int | `10` | Maximum replicas. |
| `api.autoscaling.targetCPUUtilizationPercentage` | int | `70` | Target CPU utilisation in percent. |
| `api.autoscaling.targetMemoryUtilizationPercentage` | null | `null` | Target memory utilisation in percent (null = off). |
| `api.pdb.enabled` | bool | `true` | Create a PodDisruptionBudget. |
| `api.pdb.minAvailable` | int | `1` | minAvailable (ignored when maxUnavailable is set). |
| `api.pdb.maxUnavailable` | null | `null` | maxUnavailable. |
| `api.livenessProbe` | object | `{"httpGet": {"path": "/healthz", "port": "http"}, "periodSeconds": 15, "timeo...` | Liveness probe. |
| `api.readinessProbe` | object | `{"httpGet": {"path": "/readyz", "port": "http"}, "periodSeconds": 10, "timeou...` | Readiness probe. |
| `api.startupProbe` | object | `{"httpGet": {"path": "/healthz", "port": "http"}, "periodSeconds": 5, "failur...` | Startup probe. |
| `api.podAnnotations` | object | `{}` | Pod annotations. |
| `api.podLabels` | object | `{}` | Pod labels. |
| `api.nodeSelector` | object | `{}` | Node selector. |
| `api.tolerations` | list | `[]` | Tolerations. |
| `api.affinity` | object | `{}` | Affinity. |
| `api.topologySpreadConstraints` | list | `[]` | Topology spread constraints. Empty = soft spread across zones and nodes. |
| `api.priorityClassName` | string | `""` | Priority class. |
| `api.terminationGracePeriodSeconds` | int | `30` | Termination grace period. |
| `api.extraEnv` | list | `[]` | Extra env vars (list of EnvVar). |
| `api.extraVolumes` | list | `[]` | Extra volumes. |
| `api.extraVolumeMounts` | list | `[]` | Extra volume mounts. |
| `worker.replicaCount` | int | `1` | Replicas when autoscaling is off (in-process runner of the MVP). |
| `worker.concurrency` | int | `4` | `OAX_WORKER_CONCURRENCY` parallel runs per pod. |
| `worker.pollMs` | int | `500` | `OAX_WORKER_POLL_MS`. |
| `worker.leaseSeconds` | int | `60` | `OAX_WORKER_LEASE_SECONDS`. |
| `worker.maxAttempts` | int | `3` | `OAX_WORKER_MAX_ATTEMPTS`. |
| `worker.approvalPollMs` | int | `1000` | `OAX_APPROVAL_POLL_MS`. |
| `worker.demoMcp` | bool | `false` | `OAX_DEMO_MCP` (built-in demo MCP servers; demo only). |
| `worker.resources` | object | `{"requests": {"cpu": "100m", "memory": "256Mi"}, "limits": {"memory": "1Gi"}}` | Resources. |
| `worker.autoscaling.enabled` | bool | `false` | Enable the HorizontalPodAutoscaler (CPU based; KEDA on queue depth is on the roadmap). |
| `worker.autoscaling.minReplicas` | int | `1` | Minimum replicas. |
| `worker.autoscaling.maxReplicas` | int | `5` | Maximum replicas. |
| `worker.autoscaling.targetCPUUtilizationPercentage` | int | `75` | Target CPU utilisation in percent. |
| `worker.autoscaling.targetMemoryUtilizationPercentage` | null | `null` | Target memory utilisation in percent (null = off). |
| `worker.pdb.enabled` | bool | `true` | Create a PodDisruptionBudget (only rendered with more than one replica, or minReplicas > 1 under autoscaling). |
| `worker.pdb.minAvailable` | int | `1` | minAvailable. |
| `worker.pdb.maxUnavailable` | null | `null` | maxUnavailable. |
| `worker.livenessProbe` | object | `{}` | Liveness probe (the worker has no HTTP endpoint; empty = none). |
| `worker.podAnnotations` | object | `{}` | Pod annotations. |
| `worker.podLabels` | object | `{}` | Pod labels. |
| `worker.nodeSelector` | object | `{}` | Node selector. |
| `worker.tolerations` | list | `[]` | Tolerations. |
| `worker.affinity` | object | `{}` | Affinity. |
| `worker.topologySpreadConstraints` | list | `[]` | Topology spread constraints. Empty = soft spread across zones and nodes. |
| `worker.priorityClassName` | string | `""` | Priority class. |
| `worker.terminationGracePeriodSeconds` | int | `60` | Grace period after SIGTERM; unfinished runs are requeued when their lease expires. |
| `worker.extraEnv` | list | `[]` | Extra env vars. |
| `worker.extraVolumes` | list | `[]` | Extra volumes. |
| `worker.extraVolumeMounts` | list | `[]` | Extra volume mounts. |
| `ui.enabled` | bool | `false` | Deploy the static UI (disabled until the UI image is published). |
| `ui.replicaCount` | int | `2` | Replicas. |
| `ui.containerPort` | int | `8080` | Container port of the nginx-unprivileged based image. |
| `ui.runAsUser` | int | `101` | UID/GID of the UI container (nginx-unprivileged uses 101). |
| `ui.resources` | object | `{"requests": {"cpu": "10m", "memory": "32Mi"}, "limits": {"memory": "128Mi"}}` | Resources. |
| `ui.service.type` | string | `"ClusterIP"` | Service type. |
| `ui.service.port` | int | `80` | Service port. |
| `ui.service.annotations` | object | `{}` | Service annotations. |
| `ui.pdb.enabled` | bool | `true` | Create a PodDisruptionBudget. |
| `ui.pdb.minAvailable` | int | `1` | minAvailable. |
| `ui.pdb.maxUnavailable` | null | `null` | maxUnavailable. |
| `ui.livenessProbe` | object | `{"httpGet": {"path": "/", "port": "http"}, "periodSeconds": 20}` | Liveness probe. |
| `ui.readinessProbe` | object | `{"httpGet": {"path": "/", "port": "http"}, "periodSeconds": 10}` | Readiness probe. |
| `ui.podAnnotations` | object | `{}` | Pod annotations. |
| `ui.podLabels` | object | `{}` | Pod labels. |
| `ui.nodeSelector` | object | `{}` | Node selector. |
| `ui.tolerations` | list | `[]` | Tolerations. |
| `ui.affinity` | object | `{}` | Affinity. |
| `ui.topologySpreadConstraints` | list | `[]` | Topology spread constraints. Empty = soft spread across zones and nodes. |
| `ui.priorityClassName` | string | `""` | Priority class. |
| `migrations.enabled` | bool | `true` | Run `node dist/migrate-cli.js` as a Helm hook Job. |
| `migrations.hookEvents` | string | `""` | Hook events. Empty = `pre-install,pre-upgrade` (external DB) or `post-install,pre-upgrade` (bundled PostgreSQL, which does not exist before install). |
| `migrations.backoffLimit` | int | `3` | Job backoffLimit. |
| `migrations.activeDeadlineSeconds` | int | `600` | Job activeDeadlineSeconds. |
| `migrations.ttlSecondsAfterFinished` | int | `3600` | ttlSecondsAfterFinished (the hook is also deleted before the next run). |
| `migrations.resources` | object | `{"requests": {"cpu": "50m", "memory": "128Mi"}, "limits": {"memory": "256Mi"}}` | Resources. |
| `ingress.enabled` | bool | `false` | Create an Ingress. |
| `ingress.className` | string | `""` | IngressClass (`nginx`, `alb`, ...). |
| `ingress.annotations` | object | `{}` | Annotations (see examples for nginx and AWS ALB). |
| `ingress.host` | string | `"openagentix.example.com"` | Host name. |
| `ingress.apiPaths` | list | `["/v1", "/openapi.json"]` | Paths routed to the API (the rest goes to the UI when `ui.enabled`). |
| `ingress.pathType` | string | `"Prefix"` | pathType of the generated paths. |
| `ingress.tls.enabled` | bool | `false` | Terminate TLS at the ingress. |
| `ingress.tls.secretName` | string | `""` | TLS Secret (empty with ALB/ACM or cert-manager annotations). |
| `networkPolicy.enabled` | bool | `true` | Create NetworkPolicies: default deny for all chart pods plus the explicit rules below. |
| `networkPolicy.dns.enabled` | bool | `true` | Allow DNS to the cluster resolver. |
| `networkPolicy.dns.to` | list | `[{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-...` | Peers of the DNS rule. |
| `networkPolicy.ingress.from` | list | `[{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "ingre...` | Peers allowed to reach api and ui (the ingress controller). ALB in IP mode: VPC CIDR. |
| `networkPolicy.ingress.metricsFrom` | list | `[]` | Peers allowed to scrape `/metrics` on the API. |
| `networkPolicy.egress.database` | list | `[]` | Peers of the external database (CIDR or selectors). Bundled PostgreSQL is added automatically. |
| `networkPolicy.egress.databasePort` | int | `5432` | Database port. |
| `networkPolicy.egress.cache` | list | `[]` | Peers of the external cache. Bundled Valkey is added automatically. |
| `networkPolicy.egress.cachePort` | int | `6379` | Cache port. |
| `networkPolicy.egress.otel` | list | `[]` | Egress rules (`to` + `ports`) to the OTLP collector. |
| `networkPolicy.egress.auth` | list | `[]` | Egress rules of the API to identity providers (OIDC issuer, LDAP). |
| `networkPolicy.egress.providers` | list | `[]` | Egress rules of the worker to model providers (Bedrock VPC endpoint, proxy, Ollama, ...). |
| `networkPolicy.egress.mcp` | list | `[]` | Egress rules of the worker to MCP servers. |
| `networkPolicy.egress.eventSources` | list | `[]` | Egress rules of the worker to event sources (Kafka, ...). |
| `networkPolicy.egress.kubernetesApi` | list | `[]` | Egress rules to the Kubernetes API (needed by the v0.2 Job runner). |
| `runners.kubernetesJob.enabled` | bool | `false` | Render RBAC and configuration for the Kubernetes Job runner. |
| `runners.kubernetesJob.namespace` | string | `"openagentix-runs"` | Dedicated namespace for run Jobs (must differ from the release namespace). |
| `runners.kubernetesJob.createNamespace` | bool | `false` | Create the namespace (with PodSecurity `restricted` labels). |
| `runners.kubernetesJob.jobServiceAccount` | object | `{"name": "openagentix-run", "annotations": {}}` | ServiceAccount used by run Job pods (no token, no RBAC). Annotate for IRSA. |
| `runners.kubernetesJob.jobServiceAccount.name` | string | `"openagentix-run"` | Name of the ServiceAccount in the runs namespace. |
| `runners.kubernetesJob.jobServiceAccount.annotations` | object | `{}` | Annotations (e.g. IRSA role for Bedrock from worker nodes). |
| `runners.kubernetesJob.jobResources` | object | `{"requests": {"cpu": "100m", "memory": "128Mi"}, "limits": {"memory": "512Mi"}}` | Default resources of a run Job. |
| `runners.kubernetesJob.activeDeadlineSeconds` | int | `1800` | activeDeadlineSeconds of a run Job. |
| `runners.kubernetesJob.ttlSecondsAfterFinished` | int | `600` | ttlSecondsAfterFinished of a run Job. |
| `runners.kubernetesJob.apiFrom` | list | `[]` | Peers in the runs namespace may reach the API over these rules (run-token channel). |
| `runners.toolboxes.allowlist` | list | `[]` | Allowlisted toolbox images; only these may run as worker nodes. Pin by digest. |
<!-- values-table:end -->
