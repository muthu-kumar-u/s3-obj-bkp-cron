# Object-storage backup starter

A generic encrypted restic backup job with overlap protection, optional preparation hook, retention and systemd scheduling. It does not assume MongoDB or any particular app. It can use S3-compatible storage, native Google Cloud Storage or other restic backends. This is a separate reference repo with its own CI/image/version history.

## Host setup

Linux host: install restic 0.19+ and util-linux (`flock`). Put real configuration in `/etc/application-backup/backup.env`, owned by the operator/root with mode 0600. Copy `.env.example`, set the source directory, repository URL, scoped identity and password-file path. Store the encryption password independently in a password manager.

Initialize the private bucket/repository once using the same trusted environment. Then:

```sh
sudo sh scripts/backup.sh /etc/application-backup/backup.env
```

Do a restore rehearsal before enabling retention/scheduling. The optional executable `PRE_BACKUP_SCRIPT` should safely produce a consistent database dump into the source directory and restart any paused writer on failure. Raw live database files are generally not a valid consistent dump. The script returns failure for partial backups and never updates `last-success` on failure.

Use `systemd/application-backup.service` and `.timer`, replacing checkout/config paths first, or invoke the same command from cron. Choose one scheduler. Default timer is 02:00 UTC with jitter. Monitor the success marker age and job exit code; this starter does not send alerts until you connect an actual alert destination.

## Docker use

CI publishes a separate image from this repo. Mount the source read-only, state writable, and environment/password files read-only. Environment paths must refer to their **container** paths. No Docker socket is needed. A host preparation hook must run on the host before invoking the container unless deliberately included inside it.

```sh
docker build -t object-storage-backup-starter:local .
# Configure container paths in /etc/application-backup/container.env first.
docker run --rm \
  -v /srv/application/backup-input:/data/input:ro \
  -v /var/lib/application-backup:/data/state \
  -v /etc/application-backup:/run/backup:ro \
  object-storage-backup-starter:local /run/backup/container.env
```

For that example set `BACKUP_SOURCE=/data/input`, `BACKUP_STATE_DIR=/data/state` and `RESTIC_PASSWORD_FILE=/run/backup/password` in container.env.

## Recovery and retention

Use the same repository identity and separately stored password, list snapshots and restore an exact accepted snapshot into an isolated directory. `backup .` restores relative contents into the target. Compare data and verify the restored application, not only file existence. Run periodic `restic check --read-data` rehearsals.

Retention groups by host/tags across changing source paths; enable it only after recovery works. Never expire current restic objects by age at the bucket level. Bucket versioning/noncurrent versions can increase storage cost. Deletion/prune permissions, account-deletion retention and key recovery need a deliberate operator policy. References: [restic storage backends](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html).
