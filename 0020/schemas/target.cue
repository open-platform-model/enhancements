// Target schema for enhancement 0020 — Contract Promotion and Retirement.
//
// These shapes describe two movements along enhancement 0010 D34's contract
// ladder: promotion to a higher level (D1-D5) and retirement of a key that
// stops shipping (D6-D11). They are written standalone rather than importing
// opmodel.dev/core, so the entry vets without a registry round-trip; the
// types they mirror are named in comments. This follows enhancement 0015's
// convention for the same reason.
//
// Delta manifest — every top-level definition, classified against
// opmodel.dev/core@v2 (core/src/*.cue). MIRROR = an unchanged core type
// restated narrowly for this file's self-containment; mirrors are NOT part
// of the proposed delta and get no section in spec.md.
//
//   #Name                MIRROR   core #NameType (types.cue) — regex kept, rune bounds dropped
//   #Version             MIRROR   core #VersionType (types.cue) — simplified pre-release tail
//   #APIVersion          MIRROR   core #APIVersionType (types.cue:81) — the D34 ladder grammar, unchanged
//   #ContractFQN         MIRROR   core #ContractFQNType (types.cue) — collapsed to one segment class
//   #LevelRank           NEW      (D2/D5) decomposes an #APIVersion into a comparable rank; core has no level comparator today — 0010 D34 records that ordering never reaches the matcher and exists only for diagnostics, so this is the first ordering the schema itself asserts
//   #ContractMetadata    CHANGED  vs core #Resource/#Trait/#Blueprint metadata (resource.cue, trait.cue, blueprint.cue) — optional `promotedFrom` added (D1); the rest is stated narrowly, not proposed
//   #Tombstone           NEW      (D6/D8/D9) the published record that a contract key stopped shipping
//   #CatalogRemoved      CHANGED  vs core #Catalog (catalog.cue) — `#removed` added as a fourth member map beside 0015 D1's #resources/#traits/#blueprints, same key-stamping pattern constraint; stated standalone here
//   #PromotionGate       NEW      (D1/D2/D3/D5) what `opm catalog publish` unifies against, once per promoted member
//   #TombstoneGate       NEW      (D6/D9/D11) what `opm catalog publish` unifies against, once per tombstone record
//
// BOTH GATES MUST BE UNIFIED INTO A NON-HIDDEN VALUE. `cue vet -c` does not
// check hidden fields, so a gate parked in a `_`-prefixed slot passes
// silently while checking nothing. This is #TraitOptionalGate's warning
// (core/src/trait.cue:119) and it applies unchanged here.
//
// WHAT IS DELIBERATELY NOT HERE. Three rules in this entry need a SECOND
// BUILD and therefore cannot be CUE at all: D6's absent-and-not-tombstoned
// check, D2's comparison against the published predecessor, and D10's
// seasoning floor. Those live in library/opm/compat beside 0011 D23's
// backward scan and the field-wise comparator from 0011/experiments/03.
// The gates below check only what one build can see about itself.
//
// Unresolved fields carry `// OQN:` markers pointing at ../07-questions.md.
package schema

import (
	"regexp"
	"strconv"
)

// ---------------------------------------------------------------------------
// Shared vocabulary — mirrors of core types, narrowed to what this entry needs.
// ---------------------------------------------------------------------------

#Name: string & =~"^[a-z][a-z0-9-]*$"

#Version: string & =~"^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

// The D34 ladder: vN, vNalphaM, vNbetaM. Unchanged from core types.cue:81.
#APIVersion: string & =~"^v[0-9]+((alpha|beta)[0-9]+)?$"

// path/name@vN, terminated by the contract's own level (0010 D4/D21).
#ContractFQN: string & =~"^[a-z0-9.]+(/[a-z0-9-]+)+@v[0-9]+((alpha|beta)[0-9]+)?$"

// ---------------------------------------------------------------------------
// #LevelRank (NEW) — D2/D5
//
// Decomposes an #APIVersion into (major, tier, seq) so two levels can be
// ordered. 0010 D34 records that ordering never reaches the matcher and is
// needed only for diagnostics; D2 needs it for a different reason — a
// promotion must move UP, and `promotedFrom` naming an equal or higher level
// is not a promotion. tier ranks alpha < beta < GA.
// ---------------------------------------------------------------------------

#LevelRank: {
	apiVersion!: #APIVersion

	_m: regexp.FindSubmatch(#"^v(\d+)(?:(alpha|beta)(\d+))?$"#, apiVersion)

	major: int & >=0 & strconv.Atoi(_m[1])

	// 0 alpha, 1 beta, 2 GA. A bare vN has no tier segment and is GA.
	tier: int & >=0 & <=2
	if _m[2] == "alpha" {tier: 0}
	if _m[2] == "beta" {tier: 1}
	if _m[2] == "" {tier: 2}

	seq: int & >=0
	if _m[3] == "" {seq: 0}
	if _m[3] != "" {seq: strconv.Atoi(_m[3])}

	// A single comparable integer. Ordering within a major is tier then seq;
	// across majors the major dominates. The multipliers are wide enough that
	// no realistic seq or tier can carry into the next place.
	rank: (major * 1000000) + (tier * 1000) + seq
}

// ---------------------------------------------------------------------------
// #ContractMetadata (CHANGED) — D1
//
// The metadata a contract-bearing primitive carries, narrowed to the fields
// this entry reads. The ONLY proposed change is `promotedFrom`: absent on a
// contract born at its level, present on one that arrived by promotion, and
// permanent rather than consumed at publish and dropped.
// ---------------------------------------------------------------------------

#ContractMetadata: {
	name!:           #Name
	apiVersion!:     #APIVersion
	catalogVersion!: #Version
	fqn!:            #ContractFQN

	// NEW (D1). The level this contract was promoted FROM. Its presence is
	// what makes D2's cross-level comparison fire at publish, and it stays on
	// the member permanently so the artifact states its own lineage.
	//
	// OQ6: whether this field must join the denylist that 0010 D30's operand
	// filter applies before the match comparison. A metadata field that is
	// NOT on that denylist participates in unification, so two builds
	// disagreeing about promotedFrom would conflict at match time.
	promotedFrom?: #APIVersion

	...
}

// ---------------------------------------------------------------------------
// #Tombstone (NEW) — D6/D8/D9
//
// The published record that a contract key stopped shipping. It cannot live
// on the member, because the member is what is gone (D8).
// ---------------------------------------------------------------------------

#Tombstone: {
	// The key that went. Terminated by its own apiVersion like any contract
	// key, so a tombstone is per LEVEL rather than per contract name: a
	// promoted contract retires its origin level and keeps the new one.
	fqn!: #ContractFQN

	// The catalog build in which the member stopped shipping. This is the
	// build carrying THIS tombstone, not the last build that carried the
	// member — a consumer reads "gone as of" rather than "last seen in".
	since!: #Version

	// Required (D9). The entire consumer-facing value of the record in the
	// case where there is no successor.
	reason!: string

	// Optional (D9). Absent for a contract retired as a mistake. When
	// present it is the supersession edge a promoted contract's origin
	// carries, and it is what D10's seasoning floor is measured against.
	replacedBy?: #ContractFQN
}

// ---------------------------------------------------------------------------
// #CatalogRemoved (CHANGED) — D6/D7/D8
//
// The fourth member map on #Catalog, beside 0015 D1's #resources, #traits
// and #blueprints. Stated standalone: only the #removed field is proposed.
//
// The key stamps itself onto the value the way core's #transformers pattern
// constraint stamps provenance (catalog.cue), so filing and key cannot drift
// — the discipline 0010 D49 applies to member filing.
//
// D7 makes the map CUMULATIVE across builds: every build carries the whole
// history, not the delta. That property spans two builds and so is enforced
// in library/opm/compat, not here.
// ---------------------------------------------------------------------------

#CatalogRemoved: {
	#removed: [K=#ContractFQN]: #Tombstone & {fqn: K}
}

// ---------------------------------------------------------------------------
// #PromotionGate (NEW) — D1/D2/D3/D5
//
// What `opm catalog publish` unifies against once per member carrying
// `promotedFrom`. It checks the two things ONE build can see about a
// promotion. The comparison against the published predecessor is D2's other
// half and lives in library/opm/compat, because it needs a second build.
// ---------------------------------------------------------------------------

#PromotionGate: {
	// The value under test: the promoted member's own metadata.
	name!:         #Name
	apiVersion!:   #APIVersion
	promotedFrom!: #APIVersion

	_to:   #LevelRank & {"apiVersion": apiVersion}
	_from: #LevelRank & {"apiVersion": promotedFrom}

	// RULE 1 (D1) — a promotion moves UP. An equal or lower origin is not a
	// promotion, and naming one is how an author would express a downgrade,
	// which the ladder does not have.
	promotesUpward: true
	promotesUpward: _to.rank > _from.rank

	// RULE 2 (D5) — rung-skipping is PERMITTED. Recorded as an explicit
	// non-constraint so an implementer does not add it: alpha promises
	// nothing under 0010 D34, so there is no intermediate promise to protect,
	// and the guidance against skipping lives in SPEC.md rather than here.
	//
	// RULE 3 (D3) — a build promotes OR changes shape, never both. That
	// compares the promoted member against its predecessor and therefore
	// needs a second build; it is not expressible here. Stated so the gate's
	// scope is not mistaken for the whole of D3.
}

// ---------------------------------------------------------------------------
// #TombstoneGate (NEW) — D6/D9/D11
//
// What `opm catalog publish` unifies against once per tombstone record.
// Checks what one build can see about the record's own coherence.
// ---------------------------------------------------------------------------

#TombstoneGate: {
	// The value under test: one entry from #removed.
	tombstone!: #Tombstone

	_gone: #LevelRank & {apiVersion: regexp.FindSubmatch(#"@(v\d+(?:(?:alpha|beta)\d+)?)$"#, tombstone.fqn)[1]}

	// RULE 1 (D11) — alpha members are never tombstoned. Alpha promises
	// nothing (0010 D34), so requiring a record at that level would be
	// ceremony enforcing a promise the label denies.
	notAlpha: true
	notAlpha: _gone.tier > 0

	// RULE 2 (D9) — a tombstone may not point at itself. A self-referential
	// replacedBy would report a key as its own successor, which a consumer
	// following the edge would loop on.
	if tombstone.replacedBy != _|_ {
		notSelfReferential: true
		notSelfReferential: tombstone.replacedBy != tombstone.fqn
	}

	// RULE 3 (D10) — the seasoning floor. NOT here: it asks when
	// `replacedBy` first appeared in the PUBLISHED HISTORY, which no single
	// build can answer. library/opm/compat owns it, over 0011 D23's scan.
	//
	// OQ1/OQ2: the floor's unit (published builds vs wall-clock) and value
	// are unresolved, and both are contract-level gates on `accepted`.
}
