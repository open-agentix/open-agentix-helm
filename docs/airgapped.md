# Air-gapped installs (`airgapped.enabled`)

For clusters without internet access. The chart cannot download anything at run time; this page
covers the offline bundle and the values.

## What the switch does

`airgapped.enabled=true`:

- sets `OAX_AIRGAPPED=true` on api, worker and the migrations Job so the platform refuses
  features that need the internet;
- applies `airgapped.pullPolicy` (default `IfNotPresent`, use `Never` for nodes preloaded with
  images) to **every** image, including PostgreSQL and Valkey;
- replaces the registry of every image with `airgapped.registry` (keep the repository paths when
  mirroring) and appends `airgapped.pullSecrets` to `image.pullSecrets`;
- requires `networkPolicy.enabled=true` (default deny stays on), and **rejects** egress rules that
  contain `0.0.0.0/0` or `::/0` and any outbound proxy (`proxy.*`).

Allow only what lives inside your network: the LDAP/OIDC server, an in-cluster Ollama or other
model server, internal MCP servers, the OTLP collector. See
[`examples/values-airgapped.yaml`](../examples/values-airgapped.yaml).

> `OAX_AIRGAPPED` is passed through to the platform; the chart's own guarantees (no internet
> egress, no pulls, no proxy) hold regardless of how far the platform release honours it.

## Offline bundle: mirror images and chart

On a machine with internet access (pin everything; digests are listed in `values.yaml` for
PostgreSQL and Valkey, and in the platform release notes for the platform images):

```bash
REG=registry.internal.example
VER=0.1.0
helm package charts/open-agentix                       # open-agentix-0.2.1.tgz, no dependencies

# Mirror with skopeo (or crane / oras). --all keeps the multi-arch index, so digests are unchanged.
skopeo copy --all docker://ghcr.io/open-agentix/open-agentix-api:$VER    docker://$REG/open-agentix/open-agentix-api:$VER
skopeo copy --all docker://ghcr.io/open-agentix/open-agentix-worker:$VER docker://$REG/open-agentix/open-agentix-worker:$VER
skopeo copy --all docker://ghcr.io/open-agentix/open-agentix-ui:$VER     docker://$REG/open-agentix/open-agentix-ui:$VER
skopeo copy --all docker://docker.io/library/postgres:16.15-alpine@sha256:721873c34ceb9f8d8fc265984940dc982404c105f19ad51be9fdc5970a6080ea \
                  docker://$REG/library/postgres:16.15-alpine
# Optional (valkey.enabled):
skopeo copy --all docker://docker.io/valkey/valkey:8.0.11-alpine@sha256:fd348c9b6999ef15719a1d6b43b810ee1bf2068ded2d7ab6f6dd15943841f28b \
                  docker://$REG/valkey/valkey:8.0.11-alpine
```

Without a registry, create a tarball per image and load it on every node:

```bash
skopeo copy docker://ghcr.io/open-agentix/open-agentix-api:$VER docker-archive:api.tar:ghcr.io/open-agentix/open-agentix-api:$VER
# on each node:  ctr -n k8s.io images import api.tar     (or: docker load -i api.tar)
```

With preloaded images set `airgapped.pullPolicy=Never` and keep `airgapped.registry` empty.
Transfer the bundle (chart `.tgz`, image tarballs, your values file, `SHA256SUMS`) on removable
media and verify the checksums before importing.

Copying with `--all` preserves the manifest digest, so `image.*.digest` and the PostgreSQL/Valkey
digests stay valid against the mirror. Verify with
`skopeo inspect --raw docker://$REG/library/postgres:16.15-alpine | sha256sum`.

## Install

```bash
helm install oax open-agentix-0.2.1.tgz -n openagentix --create-namespace -f values-airgapped.yaml
```

Offline notes:

- Nothing in the chart pulls charts, CRDs or scripts at install or run time; `lookup`-generated
  secrets need only the cluster API.
- CRDs for `observability.serviceMonitor` / `gateway` must already be installed.
- The kubelet needs access to your registry (and `airgapped.pullSecrets` if it requires login).
- Bedrock and other cloud providers are not reachable by definition; use an in-cluster model
  server (`kind: ollama`, `clearance: restricted`).
- Backups (`postgresql.backup`) write to a PVC inside the cluster; copy them out through your
  own approved channel.
