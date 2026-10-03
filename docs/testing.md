# Testing the chart

| Check | Tool | Local | CI |
| --- | --- | --- | --- |
| Template structure (balanced blocks, includes) | `scripts/check-templates.py` (Python) | yes | yes |
| All values files against `values.schema.json` | `scripts/validate-values.cjs` (ajv) | when `ajv`/`yaml` are on `NODE_PATH` | yes |
| Unit tests | helm-unittest suites in `charts/open-agentix/tests/` | when helm + plugin are installed | yes (pinned action/plugin) |
| Template coverage >= 80 % | `scripts/coverage.py` | yes | yes (+ job summary) |
| Lint | `helm lint --strict` for every values file | with helm | yes |
| Golden files | `scripts/golden.sh` (`helm template` per render case vs `tests/golden/`) | with helm | yes |
| Schema validation of manifests | `scripts/kubeconform.sh` (pinned schema commits, strict) | with kubeconform | yes |
| chart-testing | `ct lint`; `ct install` on kind | – | lint always; install once images are published |
| README values table | `scripts/values-table.py --check` | yes | yes |

Run everything that is available locally:

```bash
scripts/test-local.sh
```

The script never downloads tools. Install pinned versions yourself (see the `env` block of
`.github/workflows/ci.yaml`): Helm, the helm-unittest plugin and kubeconform.

## Render cases

Golden files and kubeconform use the same render cases:

- `examples/values-*.yaml` – documented scenarios,
- `charts/open-agentix/ci/*-values.yaml` – chart-testing install values,
- `tests/values/full.yaml` – every optional feature on,
- `tests/values/bundled.yaml` – bundled PostgreSQL and Valkey.

## Coverage

"Coverage" for a chart means: every template is rendered and asserted on by at least one unit
test. `scripts/coverage.py` lists each template with the number of assertions that target it and
fails below 80 %. Rendering every template under several value sets is additionally ensured by
the golden-file cases above.

## Updating golden files

After an intended template change run `scripts/golden.sh --update` with the Helm version pinned
in CI and commit the diff together with the change. Until the first golden files are committed
CI uploads the rendered output as the `golden-candidate` artifact.
