# Changelog

All notable changes to the charts in this repository are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the chart version follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-04

### Added

- **One-command install:** `helm install oax charts/open-agentix` now deploys a complete working
  stack (API, worker, UI, PostgreSQL, migrations) without prepared Secrets or other charts.
- Bundled PostgreSQL as a hardened StatefulSet shipped with the chart (official image pinned by
  digest, PVC kept on uninstall, probes, resource limits, non-root, read-only root file system,
  separate owner and least-privilege application roles, NetworkPolicy without egress) and an
  optional backup CronJob (`pg_dump -Fc` to a PVC with retention).
- Credentials generated once and kept via `lookup` in the Secret `<release>-open-agentix-generated`
  (run-token key, database passwords, Ed25519 audit checkpoint key, bootstrap admin password,
  Valkey password); `existingSecret` references still take precedence.
- Bundled Valkey as a small password-protected Deployment (official image pinned by digest).
- `demo.enabled`: read-only public demo mode (`OAX_DEMO_MODE`, simulated provider only, demo MCP
  servers, no bootstrap admin) and `examples/values-demo.yaml`.
- `airgapped.enabled`: `OAX_AIRGAPPED=true`, pull policy and private registry for every image,
  required NetworkPolicies, validation against internet egress rules and outbound proxies;
  `docs/airgapped.md` with the offline bundle steps.
- Gateway API `HTTPRoute` as an alternative to the Ingress (`gateway.*`).
- Docs: `docs/install.md` (install, generated secrets, production, uninstall), `docs/demo.md`,
  `docs/airgapped.md`; backup, upgrade and security docs updated.
- Unit tests for every new template, golden files for the demo, Gateway and bundled cases, and
  `scripts/kind-install-test.sh`, an end-to-end install/upgrade/uninstall test on kind.

### Changed

- **Breaking (pre-1.0, MINOR):** the optional groundhog2k sub-charts are removed (no chart
  dependencies, nothing to download, no `Chart.lock`); `postgresql.enabled` now defaults to `true`.
  Installs with an external database must set `postgresql.enabled=false`; the `postgresql.*` and
  `valkey.*` values changed (see `docs/upgrades.md`). A 0.1.x release using the bundled sub-chart
  database cannot be upgraded in place.
- `ui.enabled`, `auth.bootstrapAdmin.enabled` and `audit.signingKey.generate` default to `true`.
- With the bundled database the API migrates on start (`api.migrateOnStart: null` = automatic) so
  `helm install --wait` works although the migrations hook runs post-install.

### Fixed

- `OAX_BODY_LIMIT_BYTES` and `OAX_WEBHOOK_MAX_BYTES` were rendered as `1.048576e+06`; they are now
  integers.
- Replaced personal maintainer details in `Chart.yaml`, `GOVERNANCE.md` and
  `CODE_OF_CONDUCT.md` by the project agent account and contact address.

## [0.1.1] - 2026-10-03

### Fixed

- Removed the non-standard `license` key from `Chart.yaml` (chart-testing schema); the license stays in the `artifacthub.io/license` annotation.

### Added

- Golden files rendered by Helm in CI for all seven render cases.

## [0.1.0] - 2026-10-03

First release of the `open-agentix` chart (appVersion 0.1.0).

### Added

- Control node API (Deployment, Service, HPA, PDB), worker (Deployment, HPA, PDB) and an
  optional nginx-unprivileged UI.
- Database migrations as a Helm hook Job (`pre-install,pre-upgrade`; `post-install` with the
  bundled database), optional separate migration role.
- External PostgreSQL by default (`externalDatabase.*`, password or full URL from an existing
  Secret); optional bundled PostgreSQL and Valkey (groundhog2k charts, pinned versions and
  archive digests).
- Configuration of the platform contract: OIDC, LDAP, bootstrap admin, run-token key, audit
  checkpoint Ed25519 key, providers and price table, Bedrock via VPC endpoint, HTTPS proxy,
  OpenTelemetry, secret references (`secrets.files`, `secrets.env`). No secret in values.
- PodSecurity `restricted` for every pod, separate ServiceAccounts with IRSA annotations, no
  automounted tokens.
- Default-deny NetworkPolicies with explicit egress for DNS, database, cache, OTLP, identity
  providers, model providers, MCP servers and event sources.
- Ingress for nginx and AWS ALB, TLS, ServiceMonitor and PrometheusRule (optional).
- Preparation for the v0.2 Kubernetes Job runner (namespaced RBAC, run namespace, toolbox
  allowlist, isolated run NetworkPolicy), disabled by default.
- Strict `values.schema.json`, example values (minimal, EKS, air-gapped, homelab), helm-unittest
  suites with a template coverage gate, golden-file and kubeconform checks, CI pipeline.

[Unreleased]: https://github.com/open-agentix/open-agentix-helm/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/open-agentix/open-agentix-helm/compare/v0.1.1...v0.2.0
[0.1.0]: https://github.com/open-agentix/open-agentix-helm/releases/tag/v0.1.0
