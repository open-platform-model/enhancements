# Specification changes: Contract Promotion and Retirement

<!--
This document pre-drafts the core/SPEC.md co-update that the core slice
will need at implementation time (the `core-schema-edit` skill gates that
co-update via pre-commit hook + CI). It is required, with examples.cue,
from the draft → accepted gate.
-->

Five constructs. Two are new definitions, one is a new field on three existing primitives, and two are new publish gates. Nothing is removed and nothing is tightened for a catalog that neither promotes nor retires a contract.

## `promotedFrom` on `#Resource`, `#Trait`, `#Blueprint` (CHANGED vs SPEC.md §2.1, §2.2, §3.3)

### Definition

A contract-bearing primitive may record the API version it was **promoted from**. Its presence states that this contract previously shipped at a lower level in this catalog and has been moved up the ladder `#APIVersionType` describes; its absence states that the contract was born at the level it carries. It is provenance in the same family as `catalogVersion` (§2.1): authored once, never derived, and never a component of any key.

### Shape

```cue
metadata: {
    // ... existing fields unchanged ...
    promotedFrom?: #APIVersionType   // the level this contract was promoted from
}
```

### Constraints

- **Added.** `metadata.promotedFrom`, when present, MUST be an `#APIVersionType`.
- **Added.** `promotedFrom` MUST name a level strictly below `metadata.apiVersion` under the ordering alpha < beta < GA within a major, and major-dominant across majors. Equal or higher is refused by `#PromotionGate`.
- **Added.** `promotedFrom` MUST NOT enter any contract key. The key is terminated by `apiVersion` alone (§2.1), and a promoted contract is reachable only at its own level.
- **Added.** A catalog release MUST NOT change or remove `promotedFrom` on a published member. It records a historical fact, and a fact that moves is not provenance.
- **Unchanged.** Every existing constraint on `metadata` holds. `promotedFrom` is optional, so no existing member becomes invalid.

### Rationale

**Why a declared field rather than an inferred relationship.** A promotion could be detected by looking for the same `name` at a lower level in the published history. That reading makes every newly published GA contract look like a promotion of whatever happened to share its name, so an author starting a genuinely new contract at GA gets compared against an unrelated predecessor and refused. Declaring the origin makes the comparison fire exactly when the author says it should.

**Why it is permanent rather than a publish-time input.** The alternative was to accept `promotedFrom` at publish, use it for the gate, and drop it from the artifact. That leaves the published contract with no statement of its own lineage, and a consumer reading `container@v1` cannot tell whether the `container@v1beta1` it currently depends on is the same contract or a different one that shares a name. The field is small and the question is common.

**Why it is not in the key.** Enhancement 0010 D4 keys a contract on its own level precisely so the key survives a catalog release. A key that also carried the origin would change when a contract was promoted a second time, which is the churn D4 exists to remove.

## `#Tombstone` (NEW)

### Definition

A `#Tombstone` is the published record that a contract key has stopped shipping. It names the key that went, the catalog build it went in, why, and optionally what replaced it. It exists because the alternative record, the member itself, is what is gone: a marker on a live member describes a deprecation, which is a weaker and different statement than a removal, and it disappears at exactly the moment the record becomes necessary.

### Shape

```cue
#Tombstone: {
    fqn!:        #ContractFQNType   // the key that went, terminated by its own apiVersion
    since!:      #VersionType       // the catalog build carrying this record
    reason!:     string             // why; required
    replacedBy?: #ContractFQNType   // the successor, when there is one
}
```

### Constraints

- `fqn` MUST be a `#ContractFQNType` and MUST equal the key of the `#removed` entry carrying it (§ below).
- Because `fqn` is terminated by `apiVersion`, a tombstone is per **level**, not per contract name. A promoted contract retires its origin level while continuing to ship the level it was promoted to.
- `since` MUST be the version of the catalog build carrying this tombstone, not the last build that carried the member. A consumer reads "gone as of" rather than "last seen in".
- `reason` MUST be present and non-empty.
- `replacedBy`, when present, MUST NOT equal `fqn`.
- A tombstone MUST NOT be written for a member whose `apiVersion` is an alpha level.
- `#ComponentTransformer` MUST NOT be tombstoned. It carries no `apiVersion` (§4.1) and therefore no key a tombstone could name.

### Rationale

**Why removal is recorded rather than refused.** A publish gate has no knowledge of who consumes a catalog, so a hard refusal would be arbitrary if it blocked always and useless if it blocked never. The cluster-side rule that *does* know its dependents lives in the operator. What publish can do is convert a silent disappearance into a deliberate statement, at a cost of one record, so a legitimate removal is never blocked and an accidental one is never quiet.

**Why `reason` is required and `replacedBy` is not.** They answer different questions and only one always has an answer. A contract retired as a mistake has no successor, and requiring one would force the author to invent a pointer, which would make the field's presence uninformative everywhere else. Requiring `reason` keeps the record useful in exactly the case where there is nothing to point at.

**Why the record is per level.** The alternative, tombstoning a contract by name, cannot express the central case: a promoted contract is simultaneously retired at one level and live at another.

## `#Catalog.#removed` (CHANGED vs SPEC.md §5.2)

### Definition

`#Catalog` gains a fourth member map. Where `#resources`, `#traits` and `#blueprints` declare what the catalog carries, `#removed` declares what it used to carry and no longer does. It is a published part of the catalog artifact, so a consumer answers "what happened to this key" from the build it already holds.

### Shape

```cue
#Catalog: {
    // ... existing fields and member maps unchanged ...
    #removed: [K=#ContractFQNType]: #Tombstone & {fqn: K}
}
```

### Constraints

- **Added.** Each entry's `fqn` is stamped from its map key, in the same way `#transformers` stamps provenance onto its members (§5.2). An entry MUST NOT author an `fqn` disagreeing with its key.
- **Added.** `#removed` MUST be cumulative: a catalog build MUST carry every tombstone its predecessor carried, plus any new ones. A build that drops a tombstone is refused at publish.
- **Added.** A catalog build MUST NOT both omit a member that a previous build published at beta or GA and lack a tombstone for that member's key.
- **Added.** A tombstone naming `replacedBy` MUST NOT be published until the named replacement has been present in the catalog's published history for the minimum seasoning.
- **Unchanged.** Every existing `#Catalog` constraint. `#removed` is additive, so an existing catalog remains valid with the map absent or empty.

### Rationale

**Why on `#Catalog`.** A tombstone is a statement by the catalog about its own membership, so it belongs beside where membership is declared. The alternatives each fail on a specific ground: a marker on the member cannot survive the member; the identity package states what the artifact *is* rather than what it no longer carries, and would become a dependency of every member; and a separate artifact introduces a second thing to version and keep in step for a record that is a property of one build.

**Why cumulative rather than a per-build delta.** A consumer holding one build must be able to answer "where did this key go" from the bytes in front of it. A delta forces a walk over every published build, which puts registry round-trips on a diagnostic path, and it forces the publish gate to reconstruct the same history to know whether a key was ever recorded.

**Why the seasoning floor is stated here.** It is a constraint on what a catalog build may contain, so it belongs with the map it constrains, even though only cross-build tooling can evaluate it. This mirrors the existing split at §5.3, where `#CatalogMemberFQNGate` states a rule the schema cannot enforce alone.

## `#PromotionGate` (NEW)

### Definition

`#PromotionGate` is what `opm catalog publish` unifies against once per member carrying `promotedFrom`, to hold catalogs to the promotion rules the primitive's own schema cannot express. It ships in `core` beside the identity gates and `#TraitOptionalGate` and is checked the same way: the schema is the contract, CUE is the engine that checks contracts, and what the author reads is CUE's own error.

### Shape

```cue
#PromotionGate: {
    name!:         #NameType
    apiVersion!:   #APIVersionType
    promotedFrom!: #APIVersionType

    promotesUpward: true   // apiVersion ranks strictly above promotedFrom
}
```

### Constraints

- A promotion MUST move upward: `apiVersion` MUST rank strictly above `promotedFrom`.
- Skipping a rung (alpha directly to GA) MUST be permitted. The guidance against it is documentation, not a constraint.
- The gate MUST be unified into a non-hidden value. `cue vet -c` does not check hidden fields, so a gate parked in a `_`-prefixed slot passes silently while checking nothing.
- The gate checks only what a single build can see. The comparison against the published predecessor at `promotedFrom`, and the rule that a build may promote or change shape but not both, both require a second build and are enforced by the publish tooling, not by this gate.

### Rationale

**Why a gate at all.** Enhancement 0011 D9 keys its predecessor lookup on `name` plus `apiVersion`, so a member published at a level that has never shipped finds no predecessor and passes trivially. That is a hole in an otherwise closed gate, and it opens at exactly the moment a catalog tells consumers a contract is more trustworthy.

**Why upward movement is a schema constraint and rung-skipping is not.** A downgrade is not a movement the ladder has, so refusing it keeps the vocabulary honest. Skipping a rung is a movement the ladder has and merely an unwise one: alpha promises nothing, so there is no intermediate promise for the skipped rung to protect, and enforcing a preference would be ceremony.

## `#TombstoneGate` (NEW)

### Definition

`#TombstoneGate` is what `opm catalog publish` unifies against once per tombstone record, to check the record's own coherence. Like `#PromotionGate` it ships in `core` and reports through CUE's own error.

### Shape

```cue
#TombstoneGate: {
    tombstone!: #Tombstone

    notAlpha:           true   // the retired key's level is beta or GA
    notSelfReferential: true   // replacedBy, when present, is not fqn
}
```

### Constraints

- The retired key's level MUST be beta or GA.
- `replacedBy`, when present, MUST NOT equal `fqn`.
- The gate MUST be unified into a non-hidden value, for the reason `#PromotionGate` states.
- The seasoning floor is NOT checked here. It asks when `replacedBy` first appeared in the published history, which no single build can answer.

### Rationale

**Why alpha is excluded rather than merely unenforced.** Enhancement 0010 D34's carve-out exists because alpha's definition is that it promises nothing. Requiring a removal record at that level would enforce a promise the label denies, and would put ceremony exactly where churn is supposed to be free.

**Why self-reference is refused.** A tombstone pointing at itself reports a key as its own successor. Any consumer or tool following the edge loops, and the record conveys nothing, so it is better refused at the source than interpreted downstream.
