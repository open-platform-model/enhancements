# Enhancement 0020 — Contract Promotion and Retirement

Enhancement 0010 gave every contract its own API version (D4, D25) and borrowed the Kubernetes ladder so the additive-only promise could bind at beta and GA while staying off at alpha (D27, D34). The ladder works. What it has never had is any rule about **movement along it**: a contract can be born at a level and it can be broken into a new one, but nothing describes a contract that has earned promotion, and nothing describes a contract leaving the catalog at all. This entry supplies both, and they turn out to be one mechanism seen from two ends.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

**A contract is promoted by dual-shipping, and the promotion is declared** (D1, D4). The catalog publishes both levels in one build with the outgoing level *defined as* the incoming one, so one value backs two keys and consumers migrate when they choose rather than on a flag day. Coexistence is not new — 0010 D27 and D34 already permit two levels in one build for a break, and 0010 D49's `<kind>/<apiVersion>/` filing already gives them two directories — what is new is that the compatible case uses the same permission. The promoted member carries `promotedFrom`, permanently, so the artifact states its own lineage.

**A promotion is checked against the level it came from** (D2, D3). This closes a hole rather than adding a rule: 0011 D9 keys its predecessor lookup on `name` plus `apiVersion`, so a member at a level never published before finds no predecessor and passes trivially. Measured against the shipped gate, a catalog may today publish `container@v1` that drops a field relative to `container@v1beta1` and report success. A build may promote or change shape, never both, so each release states one intent.

**A key that stops shipping leaves a tombstone** (D6-D9). 0011 OQ10 records that nothing refuses the removal of a beta or GA member, with evidence built into the test suite: the hermetic remove-then-readd test's removing build passes the full gate set on its way to seeding the case. A publish gate cannot know who consumes a catalog, so this entry does not block removal — it requires the removal to be *declared*. Present, or tombstoned, or refused. The record is cumulative across builds, lives on `#Catalog` beside 0015 D1's member maps, and carries a required `reason` and an optional `replacedBy`.

**A key cannot be withdrawn faster than its replacement has been available** (D10). This is the clock, and it is deliberately pointed at the producer. Enhancement 0010 D34 rejected Kubernetes-style deprecation windows because "a platform moves only when someone edits `version:` in its own source, so any window would be arbitrary" — an argument about rules that *force consumers to move*. Nothing here expires a module, a pin, or a subscription. What is constrained is how fast a catalog may withdraw a key after offering its successor, which is a promise to consumers rather than an obligation on them. D34's rejection is preserved, not reopened.

**The tombstone's `replacedBy` is the supersession edge the promotion needs**, which is why this is one entry and not two: promotion emits the record retirement consumes.

## Documents

1. [01-problem.md](01-problem.md) — the four gaps, measured 2026-08-22 against `catalog_opm/src`, `core/src/catalog.cue` and `compile/match.go`
2. [02-design.md](02-design.md) — dual-shipping, the declared promotion, the tombstone, and the distinction enhancement 0010 D34 did not draw
3. [03-decisions.md](03-decisions.md) — D1..D12
4. [04-graduation.md](04-graduation.md) — per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — risks, drawbacks, high-level alternatives
6. [06-operational.md](06-operational.md) — operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md) — Open Questions OQ1..OQ8

Pure-CUE definitions live in [`schemas/`](schemas/) as compilable files, never as fenced blocks inside markdown: `target.cue` (the core delta), `examples.cue` (concrete instances whose unification is the test), `spec.md` (the SPEC.md delta in four-part format).

## Scope

### In scope

- `promotedFrom` on `#Resource`, `#Trait` and `#Blueprint` metadata, and the promotion it declares (D1).
- The cross-level compatibility comparison at publish, closing the trivially-passes hole (D2).
- The rule that a build promotes or changes shape, never both (D3).
- Dual-shipping with the outgoing level aliased to the incoming one, as the sanctioned promotion mechanism (D4).
- Rung-skipping permitted, discouraged in documentation rather than in a check (D5).
- `#Tombstone`, and the rule that a beta or GA member cannot stop shipping without one (D6).
- The cumulative, append-only tombstone record (D7) and its home on `#Catalog` (D8).
- Required `reason`, optional `replacedBy` (D9).
- The seasoning floor on withdrawal (D10), with its unit and value as contract-level Open Questions.
- The alpha and transformer carve-outs, inherited from 0010 D34 and D44 (D11).
- `#PromotionGate` and `#TombstoneGate` in `core`, following 0011 D21/D22's pattern.

### Out of scope

- **A consumer-facing support window.** Enhancement 0010 D34 rejected it and that rejection stands; D10 constrains the producer instead.
- **Forcing any consumer to migrate**, at any point, by any mechanism.
- **A read-side compatibility check.** Enhancement 0010 D35 settled the posture: publish-side plus the match rung, with a check command as an aid and not a guarantee.
- **Contract enumeration.** Enhancement 0015 D1 owns it. This entry does not redefine it, and needs it only for a consumer-readable inventory (the lifecycle report of OQ8); the publish gates enumerate members by filesystem walk over 0010 D49's filing and do not wait on it.
- **Blocking a withdrawal that would strand live instances** (D12). That needs cluster-side knowledge of dependents and belongs to the operator, beside 0015 D3's finalizer and D16's shrink refusal.
- **Cross-catalog relocation.** 0015 OQ5 raises promotion between catalogs as well as between levels; 0010 D47 and D49 shrank the first-party case to a level bump inside one catalog, which is what this entry solves. The third-party relocation flag day is left open.
- **A matcher-following supersession edge.** Held in reserve by D4 rather than rejected; the tombstone records the edge as data either way, so adopting it later is additive.

## Deviations from Design

None at this stage. Update when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| [0010](../0010/) | The identity reshape this entry extends: D4 (contract keyed by its own API version), D27 (additive-only inside a level), D34 (the ladder, the alpha carve-out, and the deprecation-window rejection), D35 (publish-side-only enforcement), D44 (transformers carry no `apiVersion`), D47/D49 (catalog consolidation and version-segment filing) |
| [0011](../0011/) | The publishing pipeline this entry's gates join: D9 (the compatibility gate), D23 (predecessor selection by backward scan), D10 (published artifacts are immutable), D21/D22 (schema-as-gate, checked by CUE) — and OQ10, the open removal question this entry closes |
| [0015](../0015/) | `#Catalog` contract members (D1), the prerequisite for anything that iterates contracts; D16's removal-with-dependents refusal, whose cluster-side half this entry defers to; OQ5's deferred aliasing question, which this entry answers for the within-catalog level case |
| `core/SPEC.md` §2.1, §2.2, §3.3, §5.2, §5.3 | The sections the delta in [`schemas/spec.md`](schemas/spec.md) changes |
| `core/openspec/config.yaml` | The constitution governing `core` schema changes |
