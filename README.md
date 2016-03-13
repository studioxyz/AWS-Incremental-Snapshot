# AWS-Incremental-Snapshot
Bash script for performing incremental AWS snapshots.

Description
-----------
This is a bash script that is intended to be run by cron. Utilizing Amazon AWS, the script performs an immediate backup of the passed volume id and cleans up existing backups according to passed arguments. The cron user must have AWS credentials configured.

Usage
-----
```
backup-volume.sh -k10 vol-f0f0f0f0
```

Options
-------
By default the script preserves the last 24 hours of snapshots. The -k option specifies the number of days to preserve in the snapshot history. One snapshot per day is preserved earlier than the last 24 hours. This is similar to how Time Machine works on Mac OS. The default is to keep only the last 24 hours of snapshots. The optional -d option can be used to specify a snapshot description, and the -v option produces verbose output.
