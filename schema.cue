// Schema for enhancements/NNNN/config.yaml.
//
// Repo-internal — NOT part of opmodel.dev/core@v0. Lives at the workspace
// root so the contract sits next to the data it validates. Use
//   cue vet -d '#EnhancementConfig' enhancements/schema.cue <config.yaml>
// to validate a single file, or (once the workspace Taskfile lands)
// `task enhancements:vet` for the full sweep.
package enhancements

import "strings"

#DateStr: =~"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

// Enhancement id — four-digit, zero-padded. Reserves 0000 for the canonical
// template. Workspace-root enhancements use 0001+; the legacy three-digit
// library entries are addressed via #CrossRefStr's `legacy:NNN` form so a
// new enhancement can point at a frozen library predecessor without claiming
// it as a workspace-root id.
#IDStr:  =~"^[0-9]{4}$"
#LegacyIDStr: =~"^legacy:[0-9]{3}$"
#CrossRefStr: #IDStr | #LegacyIDStr

#SlugStr: =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

// Title bounded for one-line display in `task enhancements:list`.
// Slug captures the long form; README/01/02/… docs carry full prose.
#TitleStr: string & strings.MinRunes(1) & strings.MaxRunes(80)

#Status:       "draft" | "accepted" | "implemented" | "superseded"
#ImplStatus:   "not-started" | "in-progress" | "partial" | "complete"
#SemverImpact: "major" | "minor" | "none"

// Controlled vocabulary of OPM areas. `area` names the single primary owner;
// `affects` lists every repo that ships code, schema, or content changes
// driven by this enhancement. Both validated against the workspace directory
// map in `/CLAUDE.md`. Add a value here when a new primary repo joins the
// workspace; do not allow free-text.
#Area: "core" | "library" | "catalog" | "cli" | "opm-operator" | "opmodel.dev" |
	"orca" | "modules" | "cross-cutting"

// History event — append-only timeline of milestones. The `event` string is
// free-form prose ("Drafted", "Accepted", "Slice <id> archived", etc.);
// `slice` and `semver` are optional structured fields for events that carry
// machine-readable detail.
//
// This list is the repo's *only* strictly append-only structure. Never delete
// or reorder past events; a reversal is a new event, not an edit. Everything
// else in an entry — decision bodies, Open Question prose, the narrative
// documents — is mutable and compactable under the `enhancement-compaction`
// protocol, because git already holds that provenance and duplicating it
// in-band is what made these documents unreadable. What stays immutable
// outside this list is the *numbering*: `DN` and `OQN` are never reused and
// never renumbered, so citations from other repos keep resolving.
#HistoryEvent: {
	date!:   #DateStr
	event!:  string & strings.MinRunes(1)
	slice?:  string
	semver?: #SemverImpact
}

#EnhancementConfig: {
	id!:      #IDStr
	slug!:    #SlugStr
	title!:   #TitleStr
	status!:  #Status
	area!:    #Area
	affects!: [...#Area]
	created!: #DateStr
	// ISO 8601 strings sort lexicographically — `>=created` enforces monotonic time.
	updated!:        #DateStr & >=created
	authors!:        [_, ...string]
	implementation!: #ImplementationStatus
	history!:        [...#HistoryEvent]
	related!:        [...#CrossRefStr]
	supersedes!:     [...#CrossRefStr]
	superseded_by!:  null | #CrossRefStr

	// Optional metadata. Status-conditional constraints below tighten them.
	semver?: #SemverImpact

	// Cross-field rules. status (design lifecycle) and implementation.status
	// (code lifecycle) are independent axes; these constraints couple them
	// only where the combination would be incoherent.

	// semver becomes required once design impact is known (anything past draft).
	if status != "draft" {
		semver!: #SemverImpact
	}

	// accepted = design frozen, code in flight. Cannot be `complete` (that's
	// what `implemented` is for).
	if status == "accepted" {
		implementation: status: "not-started" | "in-progress" | "partial"
	}

	// implemented = all design intent shipped. `partial`/`in-progress` here
	// would mean we lied about the status; carve remaining work into a new
	// enhancement instead.
	if status == "implemented" {
		implementation: status: "complete"
	}

	// Tighten the null|#CrossRefStr to non-null when the entry is actually
	// superseded.
	if status == "superseded" {
		superseded_by: #CrossRefStr
	}
}

#ImplementationStatus: {
	status!: #ImplStatus
	notes?:  string

	// `date` is the canonical completion date. It is only meaningful — and
	// only allowed — when status reaches `complete`. Snapshot dates on
	// `partial`/`in-progress`/`not-started` go stale immediately and just
	// add noise; keep them out of structured metadata. Even at `complete`,
	// `date` is optional: some enhancements (especially umbrellas) reach
	// completion through a sequence of separate landings and the meaningful
	// date lives in the history list and the impl-status quote block in
	// README.md.
	if status == "complete" {
		date!: #DateStr
	}
	if status != "complete" {
		// Forbid `date` by constraining the optional field to bottom — if
		// the field is present, validation fails.
		date?: _|_
	}
}

// --- Slice plan ----------------------------------------------------------
//
// Schema for the optional enhancements/NNNN/plan.yaml. Validated the same
// way as config.yaml:
//   cue vet -d '#SlicePlan' enhancements/schema.cue enhancements/NNNN/plan.yaml
//
// A slice plan is the structured layer between a design (this entry) and
// its execution (one OpenSpec change per slice, in the target repo). It
// exists only when useful — most enhancements ship as one slice in one
// repo and never need this file. Scaffold with `task new:plan ID=NNNN`
// once `affects` spans more than one repo, or a single repo's work is
// large enough to benefit from an explicit landing order.
//
// A slice is deliberately thin: which repo, which phase, a one-line
// concern, what it depends on, and its status. Implementation detail
// belongs in that slice's own OpenSpec change, not here — this file is a
// table of contents for execution, not the execution itself.
//
// `related`/`supersedes`-style cross-referential integrity (id uniqueness,
// depends_on resolution, repo ∈ affects, cycle freedom, phase ordering) is
// enforced by `task vet` / `task vet:one`, not by this schema — the same
// split already used for config.yaml's `related`/`supersedes` dangling-ref
// checks, since CUE is a poor fit for graph validation.

// Same shape as #SlugStr — a slice id is a short kebab-case slug, unique
// within one entry's plan.yaml.
#SliceIDStr: #SlugStr

// A depends_on entry is either a local slice id (resolved within this same
// plan.yaml) or a cross-enhancement reference "NNNN:slice-id" pointing at
// a slice declared in another entry's plan.yaml — e.g. 0006's `cli`
// slice depending on enhancement 0001's `library` slice.
#SliceRefStr: #SliceIDStr | =~"^[0-9]{4}:[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

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
// republishing is its purpose — 0010's catalogs-identity-republish commits
// identity/identity.cue and is still migration.
//
// NOT the `enhancements` workflow's numbered Phase 1-5 (Create / Iterate /
// Promote / Implement / Supersede). Those describe the ENTRY's lifecycle;
// this describes one SLICE's kind.
//
// Implementation lands first. `task vet` enforces that as an edge rule —
// no implementation slice may depend on a migration slice — rather than as
// a blanket barrier, so unrelated implementation work does not needlessly
// gate a migration whose real dependencies are already done.
#SlicePhase: "implementation" | "migration"

// One line — what this slice is *about*, not how it's built.
#SliceConcernStr: string & strings.MinRunes(1) & strings.MaxRunes(240)

#Slice: {
	id!: #SliceIDStr

	// Must be a member of this entry's config.yaml `affects`. Checked by
	// `task vet`, not expressible here (schema.cue validates plan.yaml and
	// config.yaml as independent files).
	repo!: #Area

	// See #SlicePhase. Required, so the classification is a deliberate act
	// rather than a default — and not derivable from `repo`, since a
	// catalog slice can legitimately be either.
	phase!: #SlicePhase

	concern!: #SliceConcernStr

	depends_on!: [...#SliceRefStr]

	status!: #SliceStatus

	// Set once the real per-repo change exists. Conventionally
	// "<repo>/<openspec-slug>" — the same free-form shape already used in
	// config.yaml's history[].slice, so the two cross-reference cleanly.
	openspec_ref?: string & strings.MinRunes(1)

	// `cancelled` keeps the id — never reused, other slices' depends_on may
	// already cite it — but must record why, mirroring the tombstone
	// convention for a vacated DN/OQN.
	if status == "cancelled" {
		cancelled_reason!: string & strings.MinRunes(1)
	}
}

#SlicePlan: {
	slices!: [...#Slice]
}
