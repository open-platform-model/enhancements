# Delivery log: 0009

The old `delivery.yaml` of 0009, kept as a record. The landed repo changes are ticked in `../tasks.md` with their change names, except the second line below. Source: `delivery.yaml` of `0009` at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements`. Decision numbers below are the old ones; the old text is `decision-log.md`.

| Date | Repo | What landed | Change |
| --- | --- | --- | --- |
| 2026-09-01 | library | The unread kernel injection slots are removed (logger, tracer and clock options, the Clock type, the otel dependency). The controller migrated in the same wave. | `library-slot-prune` |
| 2026-10-05 | library | The directory and synthesis verbs check the caller's context at entry and between stages. Render and the registry fetch check it after their step. A running load or build is not interrupted, and cancellation inside a stage stays this entry's. | `type-fetch-errors-and-check-cancellation` |

The second line is not ticked. The library change `type-fetch-errors-and-check-cancellation` declares only enhancement 0021 and says it delivers no 0009 decision. The old delivery log named it as a landing of the cancellation checks, but a change that disclaims the entry does not become a tick (DECISIONS.md 2026-10-11 10:45). Task 2.2 in `../tasks.md` stays open and carries no change name.
