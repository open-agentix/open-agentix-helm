## What and why

<!-- One concern per PR. Title follows Conventional Commits, e.g. `feat(chart): add worker topology spread`. -->

## How was it tested?

- [ ] helm-unittest assertions added/updated in the same commit (`helm unittest charts/open-agentix`)
- [ ] `scripts/test-local.sh` passes; template coverage >= 80 %
- [ ] Golden files updated (`scripts/golden.sh --update`) and the diff reviewed
- [ ] New values documented (`# --` comment), added to `values.schema.json`, README table regenerated

## Risk and rollback

<!-- Does this change defaults, resource names, hooks, NetworkPolicies or RBAC? Upgrade impact? -->

## Checklist

- [ ] Commits are signed off (DCO: `git commit -s`)
- [ ] Chart `version` bumped (SemVer) and CHANGELOG.md updated under "Unreleased"
- [ ] No plaintext secrets in values; PodSecurity `restricted` still holds with defaults
