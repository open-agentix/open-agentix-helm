{{/*
Naming
*/}}
{{- define "open-agentix.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "open-agentix.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Name of a component resource: <fullname>-<component>. Usage: include "open-agentix.componentName" (list $ "api") */}}
{{- define "open-agentix.componentName" -}}
{{- $root := index . 0 -}}
{{- printf "%s-%s" (include "open-agentix.fullname" $root | trunc 52 | trimSuffix "-") (index . 1) -}}
{{- end -}}

{{- define "open-agentix.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Labels. Usage: include "open-agentix.labels" (list $ "api")
*/}}
{{- define "open-agentix.labels" -}}
{{- $root := index . 0 -}}
helm.sh/chart: {{ include "open-agentix.chart" $root }}
{{ include "open-agentix.selectorLabels" . }}
app.kubernetes.io/version: {{ $root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: open-agentix
{{- with $root.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "open-agentix.selectorLabels" -}}
{{- $root := index . 0 -}}
app.kubernetes.io/name: {{ include "open-agentix.name" $root }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- if gt (len .) 1 }}
app.kubernetes.io/component: {{ index . 1 }}
{{- end }}
{{- end -}}

{{/* Common metadata annotations (only rendered when set). */}}
{{- define "open-agentix.annotations" -}}
{{- with .Values.commonAnnotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Image reference. Usage: include "open-agentix.image" (list $ "api")
registry/repository:tag[@digest]; tag defaults to the appVersion.
*/}}
{{- define "open-agentix.image" -}}
{{- $root := index . 0 -}}
{{- $img := index $root.Values.image (index . 1) -}}
{{- $tag := default $root.Chart.AppVersion $img.tag -}}
{{- $ref := printf "%s:%s" $img.repository $tag -}}
{{- if $root.Values.image.registry -}}
{{- $ref = printf "%s/%s" $root.Values.image.registry $ref -}}
{{- end -}}
{{- if $img.digest -}}
{{- $ref = printf "%s@%s" $ref $img.digest -}}
{{- end -}}
{{- $ref -}}
{{- end -}}

{{- define "open-agentix.imagePullSecrets" -}}
{{- with .Values.image.pullSecrets }}
imagePullSecrets:
{{- range . }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end -}}

{{/* ServiceAccount names */}}
{{- define "open-agentix.serviceAccountName" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- $sa := index $root.Values.serviceAccount $component -}}
{{- if $sa.create -}}
{{- default (include "open-agentix.componentName" (list $root $component)) $sa.name -}}
{{- else -}}
{{- default "default" $sa.name -}}
{{- end -}}
{{- end -}}

{{/*
URLs
*/}}
{{- define "open-agentix.publicUrl" -}}
{{- if .Values.config.publicUrl -}}
{{- .Values.config.publicUrl | trimSuffix "/" -}}
{{- else if .Values.ingress.enabled -}}
{{- printf "%s://%s" (ternary "https" "http" .Values.ingress.tls.enabled) .Values.ingress.host -}}
{{- else -}}
{{- printf "http://%s.%s.svc:%v" (include "open-agentix.componentName" (list . "api")) .Release.Namespace .Values.api.service.port -}}
{{- end -}}
{{- end -}}

{{- define "open-agentix.uiUrl" -}}
{{- if .Values.config.uiUrl -}}
{{- .Values.config.uiUrl | trimSuffix "/" -}}
{{- else if .Values.ui.enabled -}}
{{- include "open-agentix.publicUrl" . -}}
{{- end -}}
{{- end -}}

{{- define "open-agentix.trustProxy" -}}
{{- if kindIs "bool" .Values.config.trustProxy -}}
{{- .Values.config.trustProxy -}}
{{- else -}}
{{- .Values.ingress.enabled -}}
{{- end -}}
{{- end -}}

{{/* OAX_PROVIDERS JSON: config.providers plus the optional Bedrock entry. */}}
{{- define "open-agentix.providersJson" -}}
{{- $providers := list -}}
{{- range .Values.config.providers -}}
{{- $providers = append $providers . -}}
{{- end -}}
{{- with .Values.aws.bedrock -}}
{{- if .enabled -}}
{{- $b := dict "kind" "bedrock" "name" .name "region" (default $.Values.aws.region .region) "clearance" .clearance -}}
{{- if .vpcEndpointUrl -}}{{- $_ := set $b "endpoint" .vpcEndpointUrl -}}{{- end -}}
{{- if .proxyUrl -}}{{- $_ := set $b "proxyUrl" .proxyUrl -}}{{- end -}}
{{- $providers = append $providers $b -}}
{{- end -}}
{{- end -}}
{{- toJson $providers -}}
{{- end -}}

{{/*
Bundled subchart service names (groundhog2k naming: <release>-<alias> unless overridden).
*/}}
{{- define "open-agentix.subchartFullname" -}}
{{- $root := index . 0 -}}
{{- $alias := index . 1 -}}
{{- $vals := index $root.Values $alias -}}
{{- if $vals.fullnameOverride -}}
{{- $vals.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default $alias $vals.nameOverride -}}
{{- if contains $name $root.Release.Name -}}
{{- $root.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $root.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Database environment. Usage: include "open-agentix.env.database" (list $ "app"|"migrations")
Produces OAX_DATABASE_URL either from a URL key or composed from parts ($(VAR) expansion).
*/}}
{{- define "open-agentix.env.database" -}}
{{- $root := index . 0 -}}
{{- $role := index . 1 -}}
{{- if $root.Values.postgresql.enabled -}}
{{- $pg := $root.Values.postgresql.userDatabase -}}
- name: OAX_DB_NAME
  valueFrom: { secretKeyRef: { name: {{ $pg.existingSecret | quote }}, key: {{ $pg.name.secretKey | quote }} } }
- name: OAX_DB_USER
  valueFrom: { secretKeyRef: { name: {{ $pg.existingSecret | quote }}, key: {{ $pg.user.secretKey | quote }} } }
- name: OAX_DB_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ $pg.existingSecret | quote }}, key: {{ $pg.password.secretKey | quote }} } }
- name: OAX_DATABASE_URL
  value: {{ printf "postgres://$(OAX_DB_USER):$(OAX_DB_PASSWORD)@%s:5432/$(OAX_DB_NAME)?sslmode=disable" (include "open-agentix.subchartFullname" (list $root "postgresql")) | quote }}
{{- else -}}
{{- $db := $root.Values.externalDatabase -}}
{{- $secret := $db.existingSecret -}}
{{- $user := $db.user -}}
{{- $passwordKey := $db.passwordKey -}}
{{- $urlKey := $db.urlKey -}}
{{- if eq $role "migrations" -}}
{{- with $db.migrations -}}
{{- if .existingSecret }}{{ $secret = .existingSecret }}{{ end -}}
{{- if .user }}{{ $user = .user }}{{ end -}}
{{- if or .existingSecret .user }}{{ $passwordKey = .passwordKey }}{{ end -}}
{{- if .urlKey }}{{ $urlKey = .urlKey }}{{ end -}}
{{- end -}}
{{- end -}}
{{- if $urlKey -}}
- name: OAX_DATABASE_URL
  valueFrom: { secretKeyRef: { name: {{ $secret | quote }}, key: {{ $urlKey | quote }} } }
{{- else -}}
- name: OAX_DB_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ $secret | quote }}, key: {{ $passwordKey | quote }} } }
- name: OAX_DATABASE_URL
  value: {{ printf "postgres://%s:$(OAX_DB_PASSWORD)@%s:%v/%s?sslmode=%s" $user $db.host $db.port $db.database $db.sslmode | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Run-token secret (api, worker and migrations: loadConfig requires it in production). */}}
{{- define "open-agentix.env.runToken" -}}
- name: OAX_RUN_TOKEN_SECRET
  valueFrom: { secretKeyRef: { name: {{ .Values.runToken.existingSecret | quote }}, key: {{ .Values.runToken.key | quote }} } }
- name: OAX_RUN_TOKEN_TTL_SECONDS
  value: {{ .Values.runToken.ttlSeconds | quote }}
{{- end -}}

{{/*
Environment shared by api and worker. Usage: include "open-agentix.env.common" (list $ "api"|"worker")
*/}}
{{- define "open-agentix.env.common" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- $v := $root.Values -}}
- name: NODE_ENV
  value: production
- name: OAX_LOG_LEVEL
  value: {{ $v.config.logLevel | quote }}
{{ include "open-agentix.env.database" (list $root "app") }}
- name: OAX_DB_POOL_MAX
  value: {{ $v.config.database.poolMax | quote }}
- name: OAX_DB_STATEMENT_TIMEOUT_MS
  value: {{ $v.config.database.statementTimeoutMs | quote }}
- name: OAX_DB_MIGRATE_ON_START
  value: {{ and (eq $component "api") $v.api.migrateOnStart | quote }}
- name: OAX_PUBLIC_URL
  value: {{ include "open-agentix.publicUrl" $root | quote }}
{{- with (include "open-agentix.uiUrl" $root) }}
- name: OAX_UI_URL
  value: {{ . | quote }}
{{- end }}
{{- with $v.config.corsOrigins }}
- name: OAX_CORS_ORIGINS
  value: {{ join "," . | quote }}
{{- end }}
- name: OAX_TRUST_PROXY
  value: {{ include "open-agentix.trustProxy" $root | quote }}
- name: OAX_BODY_LIMIT_BYTES
  value: {{ $v.config.bodyLimitBytes | quote }}
- name: OAX_CACHE_MAX_ENTRIES
  value: {{ $v.config.cache.maxEntries | quote }}
- name: OAX_AUTH_CACHE_TTL_SECONDS
  value: {{ $v.config.cache.authTtlSeconds | quote }}
{{- if $v.valkey.enabled }}
- name: OAX_CACHE_URL
  value: {{ printf "redis://%s:6379" (include "open-agentix.subchartFullname" (list $root "valkey")) | quote }}
{{- else if $v.cache.enabled }}
{{- if $v.cache.existingSecret }}
- name: OAX_CACHE_URL
  valueFrom: { secretKeyRef: { name: {{ $v.cache.existingSecret | quote }}, key: {{ $v.cache.urlKey | quote }} } }
{{- else }}
- name: OAX_CACHE_URL
  value: {{ $v.cache.url | quote }}
{{- end }}
{{- end }}
- name: OAX_SESSION_TTL_SECONDS
  value: {{ $v.config.session.ttlSeconds | quote }}
- name: OAX_TOKEN_MAX_TTL_DAYS
  value: {{ $v.config.session.tokenMaxTtlDays | quote }}
- name: OAX_RATE_LIMIT_MAX
  value: {{ $v.config.rateLimit.max | quote }}
- name: OAX_RATE_LIMIT_LOGIN_MAX
  value: {{ $v.config.rateLimit.loginMax | quote }}
{{- with $v.auth.bootstrapAdmin }}
{{- if .enabled }}
- name: OAX_BOOTSTRAP_ADMIN_EMAIL
  value: {{ .email | quote }}
- name: OAX_BOOTSTRAP_ADMIN_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ .existingSecret | quote }}, key: {{ .passwordKey | quote }} } }
{{- end }}
{{- end }}
{{- with $v.auth.oidc }}
{{- if .enabled }}
- name: OAX_OIDC_ISSUER
  value: {{ .issuer | quote }}
- name: OAX_OIDC_CLIENT_ID
  value: {{ .clientId | quote }}
- name: OAX_OIDC_REDIRECT_URI
  value: {{ default (printf "%s/v1/auth/oidc/callback" (include "open-agentix.publicUrl" $root)) .redirectUri | quote }}
- name: OAX_OIDC_SCOPES
  value: {{ .scopes | quote }}
- name: OAX_OIDC_GROUPS_CLAIM
  value: {{ .groupsClaim | quote }}
- name: OAX_OIDC_ROLE_MAPPING
  value: {{ toJson .roleMapping | quote }}
{{- if .existingSecret }}
- name: OAX_OIDC_CLIENT_SECRET
  valueFrom: { secretKeyRef: { name: {{ .existingSecret | quote }}, key: {{ .clientSecretKey | quote }} } }
{{- end }}
{{- end }}
{{- end }}
{{- with $v.auth.ldap }}
{{- if .enabled }}
- name: OAX_LDAP_URL
  value: {{ .url | quote }}
{{- if .bindDn }}
- name: OAX_LDAP_BIND_DN
  value: {{ .bindDn | quote }}
{{- end }}
- name: OAX_LDAP_USER_BASE_DN
  value: {{ .userBaseDn | quote }}
- name: OAX_LDAP_USER_FILTER
  value: {{ .userFilter | quote }}
- name: OAX_LDAP_GROUP_ATTRIBUTE
  value: {{ .groupAttribute | quote }}
- name: OAX_LDAP_ROLE_MAPPING
  value: {{ toJson .roleMapping | quote }}
- name: OAX_LDAP_TLS_REJECT_UNAUTHORIZED
  value: {{ .tlsRejectUnauthorized | quote }}
{{- if .existingSecret }}
- name: OAX_LDAP_BIND_PASSWORD
  valueFrom: { secretKeyRef: { name: {{ .existingSecret | quote }}, key: {{ .bindPasswordKey | quote }} } }
{{- end }}
{{- end }}
{{- end }}
{{- with $v.audit }}
{{- if .signingKey.existingSecret }}
- name: OAX_AUDIT_SIGNING_KEY
  valueFrom: { secretKeyRef: { name: {{ .signingKey.existingSecret | quote }}, key: {{ .signingKey.key | quote }} } }
{{- end }}
- name: OAX_AUDIT_SIGNING_KEY_ID
  value: {{ .signingKey.keyId | quote }}
- name: OAX_AUDIT_PUBLIC_KEYS
  value: {{ toJson .publicKeys | quote }}
- name: OAX_AUDIT_CHECKPOINT_EVERY
  value: {{ .checkpointEvery | quote }}
{{- end }}
{{ include "open-agentix.env.runToken" $root }}
- name: OAX_PROVIDERS
  value: {{ include "open-agentix.providersJson" $root | quote }}
- name: OAX_PRICE_TABLE
  value: {{ toJson $v.config.priceTable | quote }}
- name: OAX_CONTROL_MAX_TOOL_CALLS_PER_MINUTE
  value: {{ $v.config.control.maxToolCallsPerMinute | quote }}
- name: OAX_DEFAULT_MAX_STEPS
  value: {{ $v.config.control.defaultMaxSteps | quote }}
- name: OAX_DEFAULT_TIMEOUT_SECONDS
  value: {{ $v.config.control.defaultTimeoutSeconds | quote }}
- name: OAX_WEBHOOK_TOLERANCE_SECONDS
  value: {{ $v.config.webhook.toleranceSeconds | quote }}
- name: OAX_WEBHOOK_MAX_BYTES
  value: {{ $v.config.webhook.maxBytes | quote }}
- name: OAX_SSE_POLL_MS
  value: {{ $v.config.ssePollMs | quote }}
{{- if eq $component "worker" }}
- name: OAX_WORKER_CONCURRENCY
  value: {{ $v.worker.concurrency | quote }}
- name: OAX_WORKER_POLL_MS
  value: {{ $v.worker.pollMs | quote }}
- name: OAX_WORKER_LEASE_SECONDS
  value: {{ $v.worker.leaseSeconds | quote }}
- name: OAX_WORKER_MAX_ATTEMPTS
  value: {{ $v.worker.maxAttempts | quote }}
- name: OAX_APPROVAL_POLL_MS
  value: {{ $v.worker.approvalPollMs | quote }}
- name: OAX_DEMO_MCP
  value: {{ $v.worker.demoMcp | quote }}
{{- end }}
{{- if $v.observability.metrics.existingSecret }}
- name: OAX_METRICS_TOKEN
  valueFrom: { secretKeyRef: { name: {{ $v.observability.metrics.existingSecret | quote }}, key: {{ $v.observability.metrics.key | quote }} } }
{{- end }}
{{- with $v.observability.otel.endpoint }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ . | quote }}
{{- end }}
- name: OTEL_SERVICE_NAME
  value: {{ printf "openagentix-%s" $component | quote }}
{{- if $v.secrets.files }}
- name: OAX_SECRETS_DIR
  value: {{ $v.secrets.mountPath | quote }}
{{- end }}
{{- $region := default $v.aws.region $v.aws.bedrock.region }}
{{- if $region }}
- name: AWS_REGION
  value: {{ $region | quote }}
- name: AWS_STS_REGIONAL_ENDPOINTS
  value: regional
{{- end }}
{{- include "open-agentix.env.proxy" $root }}
{{- with $v.config.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- $extra := (index $v $component).extraEnv }}
{{- with $extra }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Proxy variables (only when a proxy is configured). */}}
{{- define "open-agentix.env.proxy" -}}
{{- $p := .Values.proxy -}}
{{- if or $p.httpsProxy $p.httpProxy }}
{{- $noProxy := list "localhost" "127.0.0.1" ".svc" ".cluster.local" -}}
{{- if $p.noProxy }}{{ $noProxy = append $noProxy $p.noProxy }}{{ end }}
{{- with $p.httpsProxy }}
- name: HTTPS_PROXY
  value: {{ . | quote }}
{{- end }}
{{- with $p.httpProxy }}
- name: HTTP_PROXY
  value: {{ . | quote }}
{{- end }}
- name: NO_PROXY
  value: {{ join "," $noProxy | quote }}
{{- end }}
{{- end -}}

{{/* envFrom for secret references (OAX_SECRET_<NAME>). */}}
{{- define "open-agentix.envFrom" -}}
{{- with .Values.secrets.env }}
envFrom:
{{- range . }}
  - secretRef:
      name: {{ . }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Volumes shared by api and worker pods. Usage: (list $ "api") */}}
{{- define "open-agentix.volumes" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
- name: tmp
  emptyDir:
    sizeLimit: 256Mi
{{- with $root.Values.secrets.files }}
- name: secret-refs
  projected:
    defaultMode: 0440
    sources:
{{- range . }}
      - secret:
          name: {{ . }}
{{- end }}
{{- end }}
{{- with (index $root.Values $component).extraVolumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "open-agentix.volumeMounts" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
- name: tmp
  mountPath: /tmp
{{- if $root.Values.secrets.files }}
- name: secret-refs
  mountPath: {{ $root.Values.secrets.mountPath }}
  readOnly: true
{{- end }}
{{- with (index $root.Values $component).extraVolumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Topology spread: explicit list or soft defaults. Usage: (list $ "api") */}}
{{- define "open-agentix.topologySpread" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- $cfg := index $root.Values $component -}}
{{- if $cfg.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml $cfg.topologySpreadConstraints | nindent 2 }}
{{- else if $root.Values.defaultTopologySpread }}
topologySpreadConstraints:
{{- range list "topology.kubernetes.io/zone" "kubernetes.io/hostname" }}
  - maxSkew: 1
    topologyKey: {{ . }}
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        {{- include "open-agentix.selectorLabels" (list $root $component) | nindent 8 }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Scheduling block shared by all pods. Usage: (list $ "api") */}}
{{- define "open-agentix.scheduling" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- $cfg := index $root.Values $component -}}
{{- with $cfg.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- include "open-agentix.topologySpread" . }}
{{- end -}}

{{/* Migrations hook events. */}}
{{- define "open-agentix.migrationHooks" -}}
{{- if .Values.migrations.hookEvents -}}
{{- .Values.migrations.hookEvents -}}
{{- else if .Values.postgresql.enabled -}}
post-install,pre-upgrade
{{- else -}}
pre-install,pre-upgrade
{{- end -}}
{{- end -}}

{{/*
Validation of required values; fails the render with an actionable message.
*/}}
{{- define "open-agentix.validate" -}}
{{- $v := .Values -}}
{{- if not $v.runToken.existingSecret -}}
{{- fail "runToken.existingSecret is required: create a Secret with a random value of >= 32 characters (key runToken.key) and reference it." -}}
{{- end -}}
{{- if $v.postgresql.enabled -}}
{{- if not $v.postgresql.userDatabase.existingSecret -}}
{{- fail "postgresql.userDatabase.existingSecret is required when postgresql.enabled=true (keys: database, user, password)." -}}
{{- end -}}
{{- else -}}
{{- if not $v.externalDatabase.existingSecret -}}
{{- fail "externalDatabase.existingSecret is required (or set postgresql.enabled=true for the bundled database)." -}}
{{- end -}}
{{- if and (not $v.externalDatabase.urlKey) (not $v.externalDatabase.host) -}}
{{- fail "externalDatabase.host is required unless externalDatabase.urlKey points to a complete URL." -}}
{{- end -}}
{{- end -}}
{{- if and $v.cache.enabled $v.valkey.enabled -}}
{{- fail "cache.enabled (external) and valkey.enabled (bundled) are mutually exclusive." -}}
{{- end -}}
{{- if and $v.cache.enabled (not $v.cache.url) (not $v.cache.existingSecret) -}}
{{- fail "cache.enabled requires cache.url or cache.existingSecret." -}}
{{- end -}}
{{- if and $v.auth.bootstrapAdmin.enabled (or (not $v.auth.bootstrapAdmin.email) (not $v.auth.bootstrapAdmin.existingSecret)) -}}
{{- fail "auth.bootstrapAdmin.enabled requires email and existingSecret." -}}
{{- end -}}
{{- if and $v.auth.oidc.enabled (or (not $v.auth.oidc.issuer) (not $v.auth.oidc.clientId)) -}}
{{- fail "auth.oidc.enabled requires issuer and clientId." -}}
{{- end -}}
{{- if and $v.auth.ldap.enabled (or (not $v.auth.ldap.url) (not $v.auth.ldap.userBaseDn)) -}}
{{- fail "auth.ldap.enabled requires url and userBaseDn." -}}
{{- end -}}
{{- if and $v.aws.bedrock.enabled (not (or $v.aws.bedrock.region $v.aws.region)) -}}
{{- fail "aws.bedrock.enabled requires aws.region or aws.bedrock.region." -}}
{{- end -}}
{{- if and $v.api.migrateOnStart $v.migrations.enabled -}}
{{- fail "api.migrateOnStart and migrations.enabled are mutually exclusive: use the migrations Job (recommended) or migrate on start." -}}
{{- end -}}
{{- if and $v.ingress.enabled (not $v.ingress.host) -}}
{{- fail "ingress.host is required when ingress.enabled=true." -}}
{{- end -}}
{{- if $v.runners.kubernetesJob.enabled -}}
{{- if eq $v.runners.kubernetesJob.namespace .Release.Namespace -}}
{{- fail "runners.kubernetesJob.namespace must be a dedicated namespace, not the release namespace." -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
NetworkPolicy egress building blocks. Each renders zero or more list items for `egress:`.
*/}}
{{- define "open-agentix.netpol.dns" -}}
{{- if .Values.networkPolicy.dns.enabled }}
- to:
    {{- toYaml .Values.networkPolicy.dns.to | nindent 4 }}
  ports:
    - { protocol: UDP, port: 53 }
    - { protocol: TCP, port: 53 }
{{- end }}
{{- end -}}

{{- define "open-agentix.netpol.database" -}}
{{- if .Values.postgresql.enabled }}
- to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: {{ default "postgresql" .Values.postgresql.nameOverride }}
          app.kubernetes.io/instance: {{ .Release.Name }}
  ports:
    - { protocol: TCP, port: 5432 }
{{- else }}
- {{- with .Values.networkPolicy.egress.database }}
  to:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  ports:
    - { protocol: TCP, port: {{ .Values.networkPolicy.egress.databasePort }} }
{{- end }}
{{- end -}}

{{- define "open-agentix.netpol.cache" -}}
{{- if .Values.valkey.enabled }}
- to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: {{ default "valkey" .Values.valkey.nameOverride }}
          app.kubernetes.io/instance: {{ .Release.Name }}
  ports:
    - { protocol: TCP, port: 6379 }
{{- else if .Values.cache.enabled }}
- {{- with .Values.networkPolicy.egress.cache }}
  to:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  ports:
    - { protocol: TCP, port: {{ .Values.networkPolicy.egress.cachePort }} }
{{- end }}
{{- end -}}

{{/* Free-form egress rules. Usage: include "open-agentix.netpol.rules" .Values.networkPolicy.egress.otel */}}
{{- define "open-agentix.netpol.rules" -}}
{{- range . }}
- {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
