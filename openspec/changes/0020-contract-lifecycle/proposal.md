# 0020: Contract Promotion and Retirement

A contract is what a catalog offers others. Each is keyed by an API level, and a module matches that exact key. This entry adds rules for moving a contract up a level and for removing one.

## Why

Moving a contract from beta to stable changes the key every consumer depends on, so each promotion is a flag day. The publish gate finds a predecessor by name plus level, so a stable contract that drops a field of its beta predecessor publishes green. Nothing refuses a removal, and nothing records when or why a contract went. Of 71 versioned members of the first-party catalog, 41 sit at beta (measured 2026-08-22).

## What Changes

- A catalog promotes a contract by shipping both levels in one build. The old level is defined as the new one, and the promoted contract records its origin.
- A promotion is checked against its origin and refused if it breaks it. A build promotes a contract or changes its shape, never both.
- A beta or stable contract that stops shipping leaves a tombstone: a published record with a reason and an optional replacement. A removal without one is refused. A removal with one is never blocked.
- The record is cumulative. A key cannot be withdrawn before its replacement has been published for a minimum time.

## What this is not

- Not a deadline for consumers. Nothing expires a module or a pin.
- Not a guard against stranding live instances. The controller owns that.
- Not a matcher that follows a promotion.
- Not a rule for alpha contracts or transformers.

## Example

```text
build 12   container at v1beta1
build 13   container at v1       the definition
           container at v1beta1  the same value, still matched by every module
build 20   container at v1
           tombstone: container at v1beta1 went in build 20, replaced by container at v1
```

## Capabilities

- **New:** `contract-promotion`, `contract-retirement`, `tombstone-record`
- **Modified:** `catalog-contracts`, `artifact-publishing`

## Impact

- **Catalog authors** pay two builds for a promotion and one record for a removal.
- **Module authors** keep matching during a promotion and move when they choose.
- **Four repos** change: core, cli, catalog_opm and opmodel.dev. Not breaking: every schema addition is optional.

## Open questions

- Blocking: Is the seasoning floor counted in published builds or in wall-clock time, or in both, whichever is longer? Builds are what the history scan already lists but a catalog can publish throwaway patches to clear them. Time cannot be gamed but puts a date comparison into a gate that is otherwise pure history.
- Blocking: What is the value of the floor? It depends on the unit. The first-party catalog publishes only `1.0.0-alpha` builds today, so a release count clears in days and a time count cannot clear at all. The value must hold against that fleet. One outside critique proposes twelve months for a comparable window.
- Not blocking: Are tombstones ever prunable? The record grows without bound. The value sits in the long tail, which argues for never pruning. Candidates: never, prune at a major bump, or prune when no build in the major still carries a member that could have depended on the key. The old register also calls this contract-level.
- Blocking: Does the raw Kubernetes family take part in promotion at all? Its levels mirror upstream and are not OPM's to move. Candidates: exempt from promotion and its check, exempt from promotion but still tombstoned, or the whole ladder does not apply to the family.
- Not blocking: What does a consumer see at render when it demands a tombstoned key? Today it is a missing key. The tombstone could say when the key went and what replaced it, but the match step is offline and deterministic. Does the match step read the record, or does only the platform check and the controller?
- Blocking: Does the promotion field take part in the match key or in any comparison other than the promotion check? It must or must not join the list of provenance fields that the operand filter removes before unification. A new metadata field that reaches the match changes matching.
- Not blocking: What happens when a catalog is published outside the OPM publish command? Every rule here sits on that gate and inherits the exposure. Does a missing tombstone in a bypassed build poison the record for good, or does the record degrade gracefully, as the within-level scan does?
- Not blocking: Does the registry check command gain a lifecycle mode? The report would be the level census plus the seasoning state of each outstanding tombstone. It needs the contract inventory of enhancement 0015, and it is an aid, not a guarantee.
