# Contributing to the open-agentix Helm charts

Thanks for helping! By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
Project-wide rules live in the main repository's
[CONTRIBUTING.md](https://github.com/open-agentix/open-agentix/blob/main/CONTRIBUTING.md); this
file covers what is specific to the charts.

## Ground rules

- **English** for code, comments, commit messages, issues and pull requests.
- **Small, reviewable commits**: one concern per commit.
- **Tests ship with the change**: every template change comes with helm-unittest assertions in
  `charts/open-agentix/tests/` in the same commit. The template coverage gate is **>= 80 %**
  (`scripts/coverage.py`); render cases and golden files are updated with the change.
- **Secure defaults stay on**: no plaintext secrets in values, PodSecurity `restricted`,
  default-deny NetworkPolicies. Relaxing a default needs a documented reason.
- **Nothing is fetched at run time** from the internet by the chart or its hooks.

## Developer Certificate of Origin (DCO)

All commits must be signed off ([developercertificate.org](https://developercertificate.org/)):

```bash
git commit -s -m "feat(chart): add topology spread for the worker"
```

## Conventional Commits 1.0.0

```
<type>(<scope>)<!>: <description in imperative mood, max. 100 chars>
```

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`,
  `revert`. Scopes: `chart`, `examples`, `deps`, `ci`, `docs`.
- Breaking change (renamed/removed value, changed default behaviour, resource rename): `!` after
  the type/scope or a `BREAKING CHANGE:` footer.
- PR titles follow the same format (checked in CI).

## Semantic Versioning 2.0.0 for the chart

`version` in `charts/open-agentix/Chart.yaml` is the chart version and the tag of this repository
(`vX.Y.Z`); `appVersion` is the default platform image tag.

| Change | Bump |
| --- | --- |
| `fix` (no values change) | PATCH |
| `feat` (new values with compatible defaults, new templates) | MINOR |
| breaking change | MAJOR (MINOR before 1.0.0, flagged in the CHANGELOG) |
| new `appVersion` only | at least PATCH |

Every PR that changes the chart bumps `version` (chart-testing enforces it) and adds a line to
[CHANGELOG.md](CHANGELOG.md) under "Unreleased".

## Local checks

```bash
scripts/test-local.sh                       # everything whose tools are installed
helm unittest charts/open-agentix           # helm-unittest plugin
scripts/golden.sh --update                  # after intended template changes
python3 scripts/values-table.py --write charts/open-agentix/README.md
```

Document every new value with a `# --` comment in `values.yaml` and add it to
`values.schema.json` (the schema is strict: unknown keys are errors).

## Release

1. Move "Unreleased" in CHANGELOG.md to the new version.
2. Bump `version` (and `appVersion` if needed) in `Chart.yaml`.
3. Commit `chore(release): X.Y.Z`, tag `vX.Y.Z`, push; the GitHub release carries the notes.
