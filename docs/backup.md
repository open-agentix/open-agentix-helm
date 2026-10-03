# Backup and restore notes

The control node and workers are stateless. Everything that matters lives in PostgreSQL and in
your Kubernetes Secrets.

## What to back up

| Item | Where | Why |
| --- | --- | --- |
| PostgreSQL database | external DB or bundled PVC | agents (`agents.md` versions), runs, steps, events, costs, users, policies and the append-only **audit trail** |
| Run-token Secret | `runToken.existingSecret` | tokens of running workers become invalid when it changes |
| Audit signing key | `audit.signingKey.existingSecret` | needed to keep signing; its public key verifies historic checkpoints |
| Other Secrets | DB, OIDC, LDAP, provider keys | needed to restore the configuration |
| Values file | your Git repository | the release configuration |

Secrets belong in your secret manager's backup; never put them into the database dump location
unencrypted.

## PostgreSQL

- Managed databases (RDS, Cloud SQL, Azure): automated backups with point-in-time recovery plus a
  snapshot before every upgrade.
- Self-managed: continuous archiving (pgBackRest, WAL-G, Barman, CloudNativePG backups) or at
  least a daily `pg_dump -Fc`:

  ```bash
  pg_dump -Fc -d "$OAX_DATABASE_URL" -f openagentix-$(date +%F).dump
  ```

- Bundled PostgreSQL (tests/homelab only): back up the PVC with your volume snapshot tooling
  (e.g. Velero) or `kubectl exec` a `pg_dump`.

## Audit trail integrity

The audit table is a hash chain with signed checkpoints. A restore must contain the complete
table; partial restores break the chain. After a restore, run the verification endpoint
(`GET /v1/audit/verify`) and keep the result as evidence. Keep previous signing public keys in
`audit.publicKeys` so historic checkpoints stay verifiable.

## Restore

1. Scale the workers to zero (`worker.replicaCount=0` or `kubectl scale`) so no runs start.
2. Restore the database (same or newer PostgreSQL major version).
3. Re-create the Secrets with the same names and keys.
4. `helm upgrade --install` with your values; the migrations Job brings the schema to the chart's
   application version.
5. Verify the audit chain, then scale the workers up again.
