# Public demo (`demo.enabled`)

`demo.enabled=true` turns the release into a safe, read-only showcase such as
`demo.openagentix.si`:

- `OAX_DEMO_MODE=true` on the API: on first start the platform seeds its deterministic data set
  (2 tenants, users for all six roles, 6 agents, runs, approvals, costs and a verifiable audit
  chain). The API is read-only except sign-in and side-effect-free checks (validate, dry-run,
  policy evaluation, hardening review, audit verify). Responses carry `x-oax-demo: true`.
- The simulated provider is the only provider (`config.providers` and Bedrock are ignored).
- `OAX_DEMO_MCP=true` on the worker registers the built-in demo MCP servers.
- No bootstrap admin is created; sign in as `admin@example.org`, `engineer@example.org`,
  `integrator@example.org`, `operator@example.org`, `auditor@example.org`, `viewer@example.org` or
  `contractor@example.org` with the shared password `demo.password` (default `demo-password-2026`,
  not a secret).
- Validation rejects OIDC, LDAP and Bedrock together with demo mode.

```bash
helm install demo ./charts/open-agentix -n demo --create-namespace -f examples/values-demo.yaml \
  --set ingress.host=demo.example.com
```

The demo uses the bundled PostgreSQL. To reset it to the seed state, delete the database volume
and restart:

```bash
kubectl -n demo scale statefulset/demo-open-agentix-postgresql --replicas=0
kubectl -n demo delete pvc -l app.kubernetes.io/instance=demo
kubectl -n demo scale statefulset/demo-open-agentix-postgresql --replicas=1
kubectl -n demo rollout restart deployment/demo-open-agentix-api
```

Do not put real data or real credentials into a demo release.
