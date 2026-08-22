# Design — Contract Promotion and Retirement

Two movements along enhancement 0010 D34's ladder get rules, and they turn out to be one mechanism seen from two ends. A contract is **promoted** by shipping the new level beside the old one, with the old level defined as the new. A contract is **retired** by leaving a **tombstone**, a published record that the key is gone and where its successor is. The tombstone's `replacedBy` is the supersession edge the promotion needs, so the two halves emit and consume the same record.

## Design Goals

- A contract that has earned a higher level can reach it without a coordinated flag day across the fleet.
- A promotion is checked against the level it promotes from, closing the hole where a bumped level finds no predecessor and passes trivially.
- A contract that stops shipping leaves a machine-readable record instead of a hole, so a consumer's diagnostic names when it went and what replaced it.
- A catalog cannot withdraw a beta or GA key faster than its consumers can reasonably follow.
- Every new rule is checkable by the tooling that already exists, at the surface that already checks the neighbouring rule.
- The ladder keeps carrying information: a level says something about the contract, not about how long nobody looked at it.

## Non-Goals

- **A consumer-facing support window.** Enhancement 0010 D34 rejected importing Kubernetes deprecation windows because "a platform moves only when someone edits `version:` in its own source, so any window would be arbitrary". That reasoning stands and this entry does not disturb it. See `## The distinction D34 did not draw` below.
- **Forcing any consumer to migrate, ever.** Nothing here expires a module, a pin, or a platform subscription.
- **A read-side compatibility check.** 0010 D35 settled that enforcement is publish-side plus the match rung, and that a check command is an aid rather than a guarantee. This entry inherits that posture unchanged.
- **Contract enumeration.** Enhancement 0015 D1 already owns it. This entry depends on it and does not redefine it.
- **Blocking a provider removal that would strand live instances.** That needs cluster-side knowledge of dependents, which no publish gate has. It belongs to the operator, alongside 0015 D3's finalizer and D16's shrink refusal.
- **Cross-catalog relocation.** 0015 OQ5 raises promotion between catalogs as well as between levels. Enhancement 0010 D47 and D49 shrank the first-party case to a level bump inside one catalog, which is what this entry solves. The third-party relocation flag day is left open.
- **Arbitrating between two providers of one contract.** Unchanged from 0010 D37 and 0015 D2.

## The distinction D34 did not draw

D34's rejection of deprecation windows is aimed at a rule that **forces consumers to move**: Kubernetes needs one because a cluster upgrade withdraws an API version whether or not the workload is ready. Under 0010 D14 nothing withdraws anything, because a platform's catalog bytes change only when someone edits `version:`. A window that expires a consumer's pin would indeed be arbitrary.

This entry's clock points the other way. It is a **floor on how fast a producer may withdraw a key**, not a deadline by which a consumer must leave it. Nobody is expired. The catalog author is told they may not tombstone a key until its replacement has been available for long enough that a consumer had a real chance to move. That is a promise to consumers rather than an obligation on them, and D34's argument does not reach it.

The producer-side obligation D34 also never addressed is the promotion one: whether an author may leave a contract at beta forever. The ladder is a claim about a contract's maturity, and a level that only ever moves when something breaks makes that claim unfalsifiable.

## High-Level Approach

**Promotion is dual-shipping with an alias.** The catalog publishes both levels in one build, and the outgoing level is *defined as* the incoming one rather than restated:

```
resources/v1/container.cue        the definition
resources/v1beta1/container.cue   the same value, re-keyed, carrying promotedFrom
```

Both keys land in the match index. Every existing module keeps matching, untouched. Consumers move imports whenever they like. The old key is retired later, under the retirement rules below. This requires no change to the matcher, no change to the key model, and no new coexistence concept: enhancement 0010 D27 and D34 already permit two levels in one build, and this is the compatible case of the thing they permit for breaks.

**Promotion is declared, not inferred.** The promoted member carries `promotedFrom`, naming the level it came from. That gives the gate a key to look up and gives the published artifact a permanent statement of lineage.

**Promotion is gated against the level below.** When a build introduces a member at a new level carrying `promotedFrom`, the gate resolves the named predecessor and applies the same additive-only comparison it already applies within a level. A promotion that breaks its origin is refused. This closes the trivially-passes hole.

**Retirement is a tombstone, not a refusal.** A publish gate cannot know who consumes a catalog, so a hard block on removal would be either arbitrary or useless. Instead: a member that was published at beta or GA and is absent from this build must be **declared removed**. Present, or tombstoned, or refused. A legitimate removal costs the author one record and is never blocked.

**The tombstone record is cumulative.** Every build carries the whole history, not a delta, so a consumer answers "what happened to this key" from the build it already holds, and the gate does not reconstruct history from every prior build.

**The clock is a floor on retirement.** A tombstone naming a `replacedBy` may not ship until that replacement has been published for a minimum seasoning. That is the enforceable form of "beta cannot be permanent": it does not expire a contract, it prices the withdrawal.

```
  build N            build N+1 .. N+k              build N+k+1
  ----------------   -------------------------     -----------------
  container@v1beta1  container@v1     (defined)    container@v1
                     container@v1beta1 (= @v1)     #removed:
                       promotedFrom: v1beta1         container@v1beta1
                                                       since:      N+k+1
       gate:              gate:                        replacedBy: @v1
       within-level       promotion compare
       compare            @v1 vs @v1beta1            gate: seasoning
                                                     (N+k+1) - (N+1) >= floor

  consumers:         consumers: both keys match,   consumers: diagnostic
  one key            migrate at will               names successor
```

## Schema / API Surface

Three changes in `opmodel.dev/core`, all additive. The compilable delta is [`schemas/target.cue`](schemas/target.cue); the spec delta is [`schemas/spec.md`](schemas/spec.md).

**`#Tombstone` (NEW).** A record that a contract key stopped shipping: the `fqn` that went, the `since` build it went in, an optional `replacedBy`, and a required `reason`.

**`#Catalog.#removed` (CHANGED).** A fourth member map beside enhancement 0015 D1's `#resources`, `#traits` and `#blueprints`, keyed by contract FQN and stamping the key onto each value the way `#transformers` already stamps provenance. The tombstone cannot live on the member, because the member is what is gone.

**`promotedFrom` on the three contract-bearing primitives (CHANGED).** Optional `#APIVersionType` on `#Resource`, `#Trait` and `#Blueprint` metadata. Absent on a contract born at its level; present on one that arrived by promotion.

**`#PromotionGate` and `#TombstoneGate` (NEW).** The within-artifact rules, shipped in `core` and unified against at publish, following the pattern `#TraitOptionalGate` and `#CatalogMemberFQNGate` established under 0011 D21/D22: the schema is the contract, CUE is the engine that checks it, and what the author reads is CUE's own error. Both gates carry `#TraitOptionalGate`'s warning: they must be unified into a non-hidden value, since `cue vet -c` does not check hidden fields and a gate parked under `_` passes while checking nothing.

Rules that need a second build cannot live in CUE and do not: the absent-and-not-tombstoned check, the promotion comparison, and the seasoning floor all need published history, which is `library/opm/compat`'s territory, where 0011 D23's backward scan and the field-wise comparator from `0011/experiments/03` already live.

## Affected Surfaces

| Repo | What changes |
| --- | --- |
| `core` | `#Tombstone`, `#Catalog.#removed`, `promotedFrom` on the three contract kinds, `#PromotionGate`, `#TombstoneGate`, and the SPEC.md sections for each |
| `library` | The cross-build rules in `opm/compat`: tombstone enforcement, promotion comparison, seasoning floor. All three extend 0011 D23's existing walk rather than adding a traversal |
| `cli` | `opm catalog publish` runs the new gates beside 0011 D9's; `opm catalog registry check` reports lifecycle state as a D35-style aid |
| `catalog_opm` | Authoring the tombstone map, and the first real promotion as the proof case |
| `opmodel.dev` | Reference documentation for the ladder, promotion, and retirement |

**Enhancement 0015 D1 is a prerequisite for less than it first appears.** The publish gates do not need it. Measured 2026-08-22, the shipped gate enumerates a catalog's members by a **filesystem walk** over enhancement 0010 D49's `<kind>/<apiVersion>` filing, not through the transformer graph, and it reads a fetched published build through the same `fs.FS` interface it reads a working tree with. Its own comment states why the value walk was rejected: `#Catalog` exposes only `#transformers`, which reach about half the contract members and no blueprints. So D6's absent-and-not-tombstoned check can see a predecessor build's members today, including the `fulfilment: "provider"` contracts no transformer demands.

What 0015 D1 is required for is a **value-level inventory a consumer can read**: the lifecycle report of OQ8, and anything the operator or a platform check needs to answer without a filesystem. Those are aids under enhancement 0010 D35's posture, not gates, so this entry can ship its enforcement before 0015 D1 lands and gain its reporting afterwards.

## Before / After

**Before.** A contract's level moves only when something breaks. 41 of `catalog_opm`'s 71 versioned members sit at beta with no rule that moves them. A level bump finds no predecessor and passes unchecked. A removed member publishes green and its consumers find out at render.

**After.** A contract is promoted by shipping two keys and retired by leaving a record. The promotion is compared against its origin. The removal is declared or refused. The withdrawal cannot outrun the replacement. A consumer of a gone key reads when it went and what replaced it, from the artifact it already has.
