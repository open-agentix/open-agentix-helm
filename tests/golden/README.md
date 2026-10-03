# Golden files

`scripts/golden.sh` renders the chart for every render case (example values, chart-testing
values in `charts/open-agentix/ci/` and the extra cases in `tests/values/`) with
`helm template oax charts/open-agentix --namespace openagentix --kube-version 1.34.0` and compares
the output with the `*.yaml` files in this directory.

- After an intended template change: `scripts/golden.sh --update`, review the diff, commit it
  together with the template change.
- The golden files must be produced by the Helm version pinned in CI (`HELM_VERSION` in
  `.github/workflows/ci.yaml`); other versions may format output differently.
- While this directory contains no `*.yaml` yet, the script exits with code 2 ("bootstrap") and CI
  uploads the rendered candidates as the `golden-candidate` artifact so they can be reviewed and
  committed.
