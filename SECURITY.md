# Security Policy

## Supported versions

| Chart version | Supported |
| --- | --- |
| 0.1.x | :white_check_mark: |
| < 0.1 | :x: |

Until 1.0.0 only the latest minor release receives security fixes.

## Reporting a vulnerability

**Please do not open public issues for security problems.**

Report privately via
[GitHub Security Advisories](https://github.com/open-agentix/open-agentix-helm/security/advisories/new)
("Report a vulnerability"). For problems in the platform itself use the
[main repository](https://github.com/open-agentix/open-agentix/security/advisories/new).
We acknowledge reports within 3 working days and aim to ship a fix for critical issues within
14 days, coordinate disclosure with you and credit you unless you prefer otherwise.

## Scope

In scope: templates and default values of the charts in this repository, for example

- secrets that end up in rendered manifests, ConfigMaps or logs,
- pods that do not meet PodSecurity `restricted` with default values,
- NetworkPolicies that allow more than documented,
- RBAC that grants more than documented (e.g. cluster-wide permissions),
- supply-chain issues (unpinned dependencies or actions).

The security model is described in [docs/security.md](docs/security.md).
