# KASIRA Disaster Recovery

## Initial targets
- RPO <= 15 minutes for cloud canonical data
- RTO <= 1 hour for core SaaS services

Targets must be validated by actual restore drills.

## Backup
- encrypted database backups
- point-in-time recovery where available
- object storage backup
- configuration/secrets recovery procedure

## Restore drill

```
Backup
 -> Restore isolated environment
 -> Run migrations
 -> Run integrity checks
 -> Validate ledger counts/totals
 -> Validate application health
 -> Record evidence
```

## Integrity checks
- orphan records
- ledger balance
- payment/order consistency
- inventory projection vs ledger
- audit continuity
- tenant boundaries
- latest migration compatibility

A backup is not considered production-ready until restore has been tested.
