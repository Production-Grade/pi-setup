# Northline Dispatch planning packet

## Product request

Multi-depot customers want job references scoped by depot. `JOB-3184` in `brisbane-south`
must not collide with `JOB-3184` in `townsville`. The dispatch intake payload may add
`depotId`, but existing integrations that omit it must continue to work during migration.

## Current repository snapshot

`DispatchJob.reference` is declared `unique=True`. The board view and the dispatch POST both
resolve a job by reference through `get_object_or_404(DispatchJob, reference=reference)`.
`PreflightCheck` rows hang off the job by foreign key. Dispatch history rows record the job
id and the reference string, but no depot. Existing tests assume one job per reference.

Production is PostgreSQL. The live uniqueness constraint is `UNIQUE(reference)`.

## Scale and operations

- 24 million jobs, 900 million dispatch-history rows.
- Peak intake is 9,000 job events per minute.
- Field tablets deploy gradually over 40 minutes; old and new versions will overlap.
- Database migrations must not hold an access-exclusive lock for more than five seconds.
- The release window is two hours. A full table rewrite does not fit.
- Dispatch history is retained for seven years and cannot be rewritten in the release window.
- Offline field tablets sync queued events for up to 72 hours after they are raised.
- The intake queue is at-least-once and may reorder events.

## Compatibility statements

Product says: integrations without `depotId` should behave exactly as they do today for at
least 90 days.

Platform says: all authenticated intake requests already carry a depot in the auth token, so
the service can infer it.

Support says: two legacy tablet fleets share one service credential across depots and cannot
distinguish depot in the token. Their payloads also omit `depotId`.

Security says: a caller must never be allowed to submit a `depotId` that differs from its
authenticated depot. Cross-depot existence must not be revealed by response differences.

## Data-quality sample

- 99.6% of recent jobs can be mapped to a depot from crew assignment metadata.
- 0.3% were raised on the shared tablet credential.
- 0.1% have deleted or incomplete crew metadata.
- A prior backfill report says "all active jobs are depot attributable", but it sampled only
  jobs created in the last 30 days.

## Proposed deadline behaviour

Operations wants depot-scoped writes enabled next Tuesday, before the quarter's new depot
opens. Analytics wants historical dispatch dashboards grouped by depot immediately.
Compliance says historical dispatch history may be joined to a separate immutable mapping
table; the history rows themselves must not be mutated.

## Existing failure history

- An earlier attempt to add a constraint during business hours held a lock for 41 seconds and
  stalled intake; the change was rolled back.
- A previous reference-format change was shipped without a rollback path and required a
  manual reconciliation over two days.
- Dropping `UNIQUE(reference)` is a one-way door in this environment: restoring it requires a
  full validating rebuild that does not fit the release window.
