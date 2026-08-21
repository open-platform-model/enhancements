// Schema for plans/<slug>/plan.yaml — delivery plans.
//
// A delivery plan is the structured execution layer for one or more
// enhancement designs: one small, single-concern **slice** per repo landing,
// with an explicit dependency order and a status. Plans live here, outside
// the enhancement entries, under a strict one-way reference relation:
//
//   plans → enhancements   ALLOWED. Slices cite decisions ("NNNN:D34") and
//                          Open Questions ("NNNN:OQ9"); `implements` names
//                          the entries this plan delivers. DN/OQN numbers
//                          are immutable per the enhancements repo's
//                          invariants, so a reference resolves for the life
//                          of the repo even after compaction.
//   enhancements → plans   FORBIDDEN. No enhancement document, config or
//                          history event may name a plan slug, a slice id,
//                          or a plan file. An enhancement records design
//                          intent; that it has been delivered is a plain
//                          fact (`implementation.status`), never a pointer.
//
// Validated with:
//   cue vet -d '#DeliveryPlan' plans/schema.cue plans/<slug>/plan.yaml
// Cross-referential integrity (id uniqueness, depends_on resolution,
// repo ∈ affects, cycle freedom, phase ordering, decision/OQ resolution)
// is enforced by `task plans:vet`, not by this schema — CUE is a poor fit
// for graph validation.
//
// A slice is deliberately thin: which repo, which phase, a one-line concern,
// what it depends on, and its status. Implementation detail belongs in that
// slice's own OpenSpec change in the target repo — a plan is a table of
// contents for execution, not the execution itself.
package plans

import "strings"

// Enhancement id — four-digit, zero-padded, resolving to ../NNNN/.
#IDStr: =~"^[0-9]{4}$"

#SlugStr: =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

// One-line display title for the generated PLAN.md heading. Optional — the
// plan directory's slug is the fallback identity.
#TitleStr: string & strings.MinRunes(1) & strings.MaxRunes(80)

// Controlled vocabulary of OPM areas — mirrors ../schema.cue's #Area.
// Membership of a slice's `repo` in the implemented entries' `affects` is
// checked by `task plans:vet`.
#Area: "core" | "library" | "catalog" | "cli" | "opm-operator" | "opmodel.dev" |
	"orca" | "modules" | "cross-cutting"

// A slice id is a short kebab-case slug, unique within one plan.
#SliceIDStr: #SlugStr

// A depends_on entry is either a local slice id (resolved within this same
// plan.yaml) or a cross-plan reference "<plan-slug>:<slice-id>" pointing at
// a slice declared in another plan under plans/.
#SliceRefStr: #SliceIDStr | =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?:[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

#SliceStatus: "planned" | "in-progress" | "done" | "cancelled"

// Which half of the work a slice belongs to. The test is what the slice is
// FOR, not which files it touches:
//
//   implementation — defines the system. Schema, code and docs changes:
//                    core, library, cli, opm-operator, opmodel.dev.
//   migration      — moves already-published artifacts onto those
//                    definitions. The official catalogs, the module fleet,
//                    the release pins.
//
// A slice that edits source files AND republishes is `migration` when
// republishing is its purpose.
//
// Implementation lands first. `task plans:vet` enforces that as an edge
// rule — no implementation slice may depend on a migration slice — rather
// than as a blanket barrier, so unrelated implementation work does not
// needlessly gate a migration whose real dependencies are already done.
#SlicePhase: "implementation" | "migration"

// A decision reference — always fully qualified as "NNNN:D34", because a
// plan may implement several enhancements and a bare "D34" would be
// ambiguous. Numbers are immutable, so a reference resolves for the life of
// the repo even after the decision is compacted.
#DecisionRefStr: =~"^[0-9]{4}:D[0-9]+$"

// An Open Question reference — "NNNN:OQ9", same qualification rule. Used by
// a slice's `resolves` to claim an OQ the enhancement explicitly deferred to
// implementation (`Status: deferred-to-implementation`). `task plans:deferred`
// reports deferred OQs no slice claims.
#OQRefStr: =~"^[0-9]{4}:OQ[0-9]+$"

// One line — what this slice is *about*, not how it's built.
//
// The 240-rune cap is the "a slice is thin" rule made mechanical. It is
// deliberately tight: prose growing past one line is the signal that detail
// belongs in the target repo's OpenSpec change instead.
//
// Decision citations DO NOT belong here — they go in `decisions`. Measured
// 2026-08-05, before that field existed: the median concern sat at 205 of
// 240 runes with up to 41 spent on an inline citation tail. That pressure
// was one-directional, since a slice's citation list only accretes, so the
// cap tightened over time through no authorial fault. Splitting them frees
// the prose budget and makes the citations checkable.
#SliceConcernStr: string & strings.MinRunes(1) & strings.MaxRunes(240)

#Slice: {
	id!: #SliceIDStr

	// Must be a member of some implemented entry's config.yaml `affects`.
	// Checked by `task plans:vet`, not expressible here.
	repo!: #Area

	// See #SlicePhase. Required, so the classification is a deliberate act
	// rather than a default — and not derivable from `repo`, since a
	// catalog slice can legitimately be either.
	phase!: #SlicePhase

	concern!: #SliceConcernStr

	depends_on!: [...#SliceRefStr]

	// Which decisions this slice implements, fully qualified. Structured
	// rather than written into `concern`, so `task plans:vet` can check
	// every reference resolves and `task plans:uncovered` can report the
	// inverse — a decision no slice carries.
	//
	// Optional: a slice may legitimately implement no numbered decision
	// (a release cut, a mechanical retarget). Absent and empty mean the
	// same thing, and neither is flagged — what `plans:uncovered` reports
	// is decisions with no slice, not slices with no decision.
	decisions?: [...#DecisionRefStr]

	// Open Questions this slice resolves — the plan-side half of the
	// deferral register. An enhancement marks an implementation-level OQ
	// `Status: deferred-to-implementation` with context attached and never
	// names its inheritor; the slice that picks it up claims it here.
	resolves?: [...#OQRefStr]

	status!: #SliceStatus

	// Set once the real per-repo change exists. Conventionally
	// "<repo>/<openspec-slug>".
	openspec_ref?: string & strings.MinRunes(1)

	// `cancelled` keeps the id — never reused, other slices' depends_on may
	// already cite it — but must record why, mirroring the tombstone
	// convention for a vacated DN/OQN.
	if status == "cancelled" {
		cancelled_reason!: string & strings.MinRunes(1)
	}
}

#DeliveryPlan: {
	title?: #TitleStr

	// The enhancement entries this plan delivers. One is the common case; a
	// plan coordinating several tightly-coupled entries lists them all.
	implements!: [_, ...#IDStr]

	slices!: [...#Slice]

	// Decisions this plan deliberately implements in no slice, each with the
	// reason. Keys are qualified decision refs, values are why.
	//
	// This exists so `task plans:uncovered` has a way to be quiet about a
	// decision that genuinely needs no work — one that only DELETES
	// something, one whose whole content is a documentation holding, one
	// superseded before any slice carried it. Without it the report cries
	// wolf and stops being read, which is the failure mode of every
	// coverage check.
	//
	// It is not a suppression list. An entry here is a claim on the record
	// that the decision needs no code, and it is reviewed like any other
	// line in this file. Tombstoned numbers (`### DN: (merged into DM, …)`)
	// do not need an entry — those are excluded automatically, since the
	// number is retired rather than unimplemented.
	unsliced?: [#DecisionRefStr]: string & strings.MinRunes(1)
}
