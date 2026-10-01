# Task 6 — Plan a depot-scoped job reference migration

Northline Dispatch currently treats a job `reference` as globally unique. Multi-depot
customers need the same reference to be valid in different depots.

Read the supplied planning packet and the repository. Produce `PLAN.md` for a senior
engineer to approve before implementation. Do not write production code.

The plan must:

- reconstruct the relevant current behaviour and identify evidence that remains uncertain;
- state assumptions and questions that must be resolved;
- compare at least two viable migration approaches and choose one;
- preserve API compatibility, retry idempotency and existing dispatch history;
- cover schema and data migration, rollout order, mixed-version operation, rollback and observability;
- identify concurrency, security and operational failure modes;
- break implementation into reviewable stages with validation and stop conditions.

Do not invent certainty. If the packet conflicts with the repository, call out the conflict
and explain how you would resolve it.

Keep `PLAN.md` below 1,800 words. Prioritise decisions, dependencies and release safety over
generic explanation.
