# AWS MVP Recovery Guide

Recovery operations can interrupt services or destroy data. Inspect the exact target, preserve
current image and backup identity, and obtain approval before any live restore or rollback.

For ownership boundaries, see [docs/overview.md](overview.md).

## PostgreSQL Backup and Restore

The AWS MVP role installs:

- `api-observatory-mvp-backup-postgres`, which creates a custom-format dump from the Compose
  `ingestor-db` container and uploads it below `postgres/` in the retained S3 bucket.
- `api-observatory-mvp-restore-postgres <postgres/key.dump> [disposable_db_name]`, which accepts only
  bounded `postgres/` keys and restores into an explicitly named disposable database by default.

A backup is not recovery evidence until its identity is recorded and a disposable restore verifies
migrations plus representative reads. Promoting restored data into the active database is outside
the automated MVP contract and requires a separately reviewed procedure.

## Host and Workload Recovery

1. Capture the failing EC2 instance, immutable image lock, platform contract version, and last known
   good backup.
2. Decide whether the failure belongs to the app workload or the AWS host/platform boundary.
3. For workload failure, use a reviewed app lock revert and the normal app deployment path.
4. For host failure, review Terraform changes, replace/bootstrap the host through the documented
   SSM Ansible path, render runtime groups, and redeploy the unchanged reviewed app lock.
5. Verify readiness, one authenticated critical path, backup creation, and a disposable restore.

Record the environment, source/image identities, trigger, action, recovery time, validation, and
remaining uncertainty. A runbook without an exercised failure/recovery path is not production
ownership evidence.
