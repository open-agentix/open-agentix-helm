# Upgrades and migrations

## How an upgrade runs

1. `helm upgrade` renders the new manifests.
2. The **migrations Job** (`pre-upgrade` hook, weight -5) runs `node dist/migrate-cli.js` with the
   *new* API image against the database. It uses the owner role from `externalDatabase.migrations`
   when configured. The previous Job is deleted first (`before-hook-creation`).
3. Only when the Job succeeds does Helm update the Deployments. API pods roll with
   `maxUnavailable: 0`; the PDB keeps at least one API pod during node drains.
4. Workers receive SIGTERM and stop polling the queue; runs a terminated worker could not finish
   are requeued when their lease expires and picked up by the new workers
   (`worker.leaseSeconds`, `worker.maxAttempts`, `worker.terminationGracePeriodSeconds`).

If the Job fails, the upgrade stops and the old pods keep serving. Inspect it with
`kubectl logs job/<release>-open-agentix-migrations`.

## Compatibility rules (platform)

Migrations follow expand/contract: a release only adds tables/columns or changes things in a
backwards-compatible way, so the old pods keep working against the migrated schema during the
rollout. Destructive changes ship in a later release. Breaking changes are listed in the platform
CHANGELOG.

## Rollback

- `helm rollback <release> <revision>` rolls back the Deployments. It does **not** roll back the
  database schema (migrations are forward-only). Thanks to expand/contract the previous version
  runs against the newer schema.
- To return to a state before a migration, restore the database backup taken before the upgrade
  (see [backup.md](backup.md)).

## Recommended upgrade procedure

1. Read the platform and chart CHANGELOGs for the target versions.
2. Take a database backup / snapshot.
3. `helm diff upgrade` (helm-diff plugin) or `helm template` + `diff` to review changes.
4. `helm upgrade --atomic --timeout 10m ...`.
5. Check `/readyz`, the migrations Job log and the `OpenAgentix*` alerts.

## Bundled PostgreSQL

The bundled database does not exist before the first install, so the migrations Job runs as a
`post-install` hook there. Do not use `--wait` for the first install with the bundled database (or
set `migrations.hookEvents` explicitly); later upgrades use `pre-upgrade` as usual. For production
use an external, backed-up PostgreSQL.

## Migrating on start instead of the Job

`migrations.enabled=false` + `api.migrateOnStart=true` lets the API migrate when it starts. Only
use this with a single API replica; the Job is the recommended way.

## Chart versions

The chart follows SemVer independently of the application: `version` in `Chart.yaml` is the chart
version (tag `vX.Y.Z` in this repository), `appVersion` the default platform image tag.

- PATCH: fixes, no values changes.
- MINOR: new values (with backwards-compatible defaults), new templates.
- MAJOR (MINOR before 1.0.0, flagged in the CHANGELOG): renamed/removed values, changed defaults
  that alter behaviour, resource renames that cause re-creation.

Unknown keys are rejected by the schema, so renamed values fail loudly instead of being ignored.
