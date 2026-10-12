# Delivery log: 0013

The old `delivery.yaml` of 0013, kept as a record. The landed repo changes are ticked in `../tasks.md` with their change names. The log below also holds the claims and the no-work notes that a task line cannot carry. Source: `delivery.yaml` of `0013` at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements`. Decision numbers below are the old ones; the old text is `decision-log.md`.

A note of 2026-09-08 in the old file: D9 and D12 were unclaimed from the first three lines below. The catalog and modules halves landed, but core still ships the legacy block that D9 deletes and D12 relocates, so no line carries them until the change that completes them.

| Date | Repo | What landed | Change |
| --- | --- | --- | --- |
| 2026-08-30 | catalog_opm | The legacy secret mechanism is deleted from the opm catalog (contract type, discovery walk, env from path, opm-secrets arm). The secret schema data is narrowed to string. The catalog was cut ahead of core's slice. | `catalog-remove-legacy-secrets` |
| 2026-08-30 | modules | The legacy `res.#Secret`, `#AutoSecrets` and `opm-secrets` are removed from all seven v2 modules. Sensitive fields are plain strings injected by value, marked as pending core's real secret type. | `modules-drop-legacy-secrets` |
| 2026-09-01 | modules | The fleet is re-pinned to catalog opm v4.0.0. The k8up module is updated for the removed env var `from`. | `fleet-repin-catalog-v4` |
| 2026-07-27 | core | Core stopped injecting the opm-secrets component into the module instance. It landed before delivery tracking. Instance-scoped group naming is still pending, so no decision is claimed. | commit `a77a12d66466ff20651c259d8be183e2e9105200` (no OpenSpec change, so no task line) |
| 2026-10-05 | library | A render reports the required contracts, every contract key of every component in the build, and fails closed on a missing resources map. D24 R1 (an instance using a secret source depends on its contract) stays open. | `expose-render-demand-and-instance-reads` |
| 2026-10-05 | opm-operator | The operator records an instance's contract demand from the kernel's render, and drops its own walk that read a missing resources map as no demand. D24 R1 stays open. | `read-demand-from-kernel` |

## No work

- D1: superseded by D10 the day it was written. Retained position only, no work to carry.
- D4: superseded by D11 the day it was written. Retained position only, no work to carry.
