# Roadmap (Helm charts)

Chart roadmap, aligned with the platform roadmap
([open-agentix ROADMAP.md](https://github.com/open-agentix/open-agentix/blob/main/ROADMAP.md)).
Items are mirrored as GitHub milestones/issues.

## 0.1.x – stabilise

- [ ] Commit the first golden files from CI (`golden-candidate` artifact) and the `Chart.lock`.
- [ ] Enable the kind install test once the platform images are published
      (`OAX_IMAGES_PUBLISHED`), including an upgrade test from the previous chart version.
- [ ] Publish the UI image and enable `ui` in the examples.

## 0.2 – distribution and worker nodes

- [ ] **OCI publishing**: push the chart to `oci://ghcr.io/open-agentix/charts/open-agentix` on
      tags; GitHub Pages index as a fallback.
- [ ] **cosign signing** of the chart (keyless, GitHub OIDC) and provenance/SBOM attestations;
      verification instructions in the README.
- [ ] **Kubernetes Job runner**: wire `runners.kubernetesJob` and the toolbox allowlist into the
      platform's runner configuration once it ships (v0.2 of the platform); per-toolbox egress
      NetworkPolicies; admission policy examples (Kyverno, sigstore policy-controller) that only
      admit signed, allowlisted toolbox digests.
- [ ] **KEDA scaling** of workers on queue depth (`oax_runs_by_status{status="queued"}` or a
      PostgreSQL scaler) as an alternative to the CPU HPA.

## 0.3 – multi-tenancy and GitOps

- [ ] **Multi-tenancy**: one release per tenant namespace with shared operators, per-tenant
      quotas (ResourceQuota/LimitRange), tenant-scoped run namespaces and IRSA roles.
- [ ] **Argo CD examples**: Application/ApplicationSet manifests, sync waves instead of Helm
      hooks for migrations, External Secrets Operator examples.
- [ ] Lambda and CI runner settings (platform v0.3).

## Later

- [ ] Gateway API (`HTTPRoute`) as an alternative to Ingress.
- [ ] Grafana dashboards as ConfigMaps.
- [ ] CloudNativePG cluster as a production-grade bundled database option.
