# An example planning task

This is the planning brief used in the video, kept here so you can run it against
your own route and read the result yourself.

The job is to plan a migration that changes a job `reference` from globally unique
to unique within a depot. The code for that change is short. The order you do
things in is the difficult part, because one of the steps cannot be undone: in the
environment described here, restoring `UNIQUE(reference)` after dropping it needs
a full validating rebuild that does not fit the release window.

## The files

- [`BRIEF.md`](BRIEF.md) — the instruction. It asks for a `PLAN.md` a senior
  engineer would approve, under 1,800 words, with at least two approaches compared
  and an explicit stance on rollback and mixed-version operation.
- [`PACKET.md`](PACKET.md) — the facts. Scale, lock budget, release window,
  rollout timing, four internal statements that do not entirely agree with each
  other, a data-quality sample whose own footnote undermines it, and the failure
  history of two previous attempts.

The packet is self-contained. You do not need the application it describes; the
repository facts a plan depends on are stated in the packet itself.

## Running it

Give Plan Mode the brief and the packet, and ask for `PLAN.md`:

```bash
cd /path/to/any/checkout
pi
```

```
/plan Read example-project/planning-task/BRIEF.md and PACKET.md and produce PLAN.md
as specified. Do not write production code.
```

Plan Mode is the right state for this because nothing about the task should
produce an edit. If the session tries to write the plan into your repository
anyway, you will find out immediately rather than after the fact.

## What to look at in the answer

Most of a plan for this will be fine, and the fine parts are not where the
interesting reading is. Four places are worth checking against the packet before
anything else.

1. **The unique index arrives before legacy writers stop bypassing it, or after.**
   Before is a plan that has not finished thinking.
2. **The shared tablet fleets.** Two legacy fleets share one service account across
   depots and omit `depotId`. A plan that infers a depot for them anyway has
   guessed, and a plan that trusts a payload `depotId` without comparing it to the
   authenticated depot has created a cross-depot write.
3. **The 900 million dispatch-history rows.** They cannot be mutated and cannot be
   rewritten in the window, so depot grouping for analytics has to come from a
   separate mapping.
4. **When the old constraint is dropped, relative to the 72-hour offline sync
   horizon.** Field tablets can be offline and sync queued events up to 72 hours
   late. If the plan drops global uniqueness before that window closes while still
   accepting the writes that global uniqueness was preventing, then for the
   remaining hours the collisions it protected against are possible and the
   protection is gone. Ask what the plan says happens to a straggler that syncs
   into that gap. A plan that never raises the question is the one to send back.

Point four is the one the deadline in the packet fights. Operations wants the
change on Tuesday; the tablet rollout takes 40 minutes; the sync horizon is 72
hours. A plan that sequences the irreversible step off the deploy window rather
than off the sync horizon is internally inconsistent, and the inconsistency is easy
to miss because everything around it reads as competent.
