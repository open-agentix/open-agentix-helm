# Changelog

All notable changes to the charts in this repository are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the chart version follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/open-agentix/open-agentix-helm/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/open-agentix/open-agentix-helm/releases/tag/v0.1.0
