# Backup and restore notes

The control node and workers are stateless. Everything that matters lives in PostgreSQL and in
your Kubernetes Secrets.

## What to back up

| Item | Where | Why |
| --- | --- | --- |
| PostgreSQL database | external DB or bundled PVC | agents (`agents.md` versions), runs, steps, events, costs, users, policies and the append-only **audit trail** |
| Run-token Secret | `runToken.existingSecret` or the generated Secret | tokens of running workers become invalid when it changes |
| Audit signing key | `audit.signingKey.existingSecret` or the generated Secret | needed to keep signing; its public key verifies historic checkpoints |
| Generated Secret | `<release>-open-agentix-generated` | passwords of the bundled database, run-token key, audit key, admin password; the database volume is useless without it |
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

- Bundled PostgreSQL: enable the backup CronJob, which writes `pg_dump -Fc` archives to its own
  PVC and prunes archives older than `postgresql.backup.retentionDays`:

  ```yaml
  postgresql:
    backup:
      enabled: true
      schedule: "17 2 * * *"
      retentionDays: 14
      persistence: { size: 10Gi, storageClass: "" }   # or existingClaim: <pvc>
  ```

  The job runs as the owner role with a read-only root file system and is allowed to reach only
  DNS and the database. Run one on demand with
  `kubectl -n <ns> create job --from=cronjob/<release>-open-agentix-postgresql-backup manual-1`.
  A PVC next to the database is **not** a disaster-recovery copy: also snapshot the volumes
  (Velero, CSI snapshots) or copy the archives off the cluster. List and fetch them with
  `kubectl -n <ns> run ls --rm -it --restart=Never --image=<postgres image> ...` mounting the claim
  `<release>-open-agentix-postgresql-backup`.

## Audit trail integrity

The audit table is a hash chain with signed checkpoints. A restore must contain the complete
table; partial restores break the chain. After a restore, run the verification endpoint
(`GET /v1/audit/verify`) and keep the result as evidence. Keep previous signing public keys in
`audit.publicKeys` so historic checkpoints stay verifiable.

## Restore

1. Scale the workers to zero (`worker.replicaCount=0` or `kubectl scale`) so no runs start.
2. Restore the database (same or newer PostgreSQL major version).
3. Re-create the Secrets with the same names and keys (including `<release>-open-agentix-generated`
   when the chart generated them).
4. Bundled PostgreSQL: restore a dump into the running instance, for example
   `kubectl -n <ns> exec -i <release>-open-agentix-postgresql-0 -- pg_restore --clean --if-exists --no-owner -U openagentix_migrator -d openagentix < openagentix.dump`
   (the migrator password is in the generated Secret, `PGPASSWORD` applies).
5. `helm upgrade --install` with your values; the migrations Job brings the schema to the chart's
   application version.
6. Verify the audit chain, then scale the workers up again.
