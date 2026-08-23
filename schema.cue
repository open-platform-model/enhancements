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

// Design lifecycle. There is no `implemented` state and no implementation
// axis: whether a design has been delivered is DERIVED from the plans side
// (`task delivery`), never asserted here. An entry that stores delivery
// progress becomes a logbook, which is what this vocabulary exists to
// prevent. `accepted` is the resting state; `rejected` and `superseded`
// are the two terminal ones, and a terminal entry ALWAYS lives in
// archive/NNNN/ (`task reject` / `task supersede` do the move; `task vet`
// enforces the placement in both directions).
#Status:       "draft" | "accepted" | "rejected" | "superseded"
#SemverImpact: "major" | "minor" | "none"

// Cutover for the history-event length cap. Events dated on or before this
// are grandfathered: 319 of the 724 events written before it exceed the cap
// and the longest runs 7619 characters, and `history` is the repo's one
// strictly append-only structure — capping retroactively would mean
// rewriting it. New events are capped instead, which is where the rule can
// actually bind.
#HistoryCapCutover: "2026-08-23"

// Controlled vocabulary of OPM areas. `area` names the single primary owner;
// `affects` lists every repo that ships code, schema, or content changes
// driven by this enhancement. Both validated against the workspace directory
// map in `/CLAUDE.md`. Add a value here when a new primary repo joins the
// workspace; do not allow free-text.
#Area: "core" | "library" | "catalog" | "cli" | "opm-operator" | "opmodel.dev" |
	"orca" | "modules" | "cross-cutting"

// History event — append-only timeline of milestones. The `event` string is
// free-form prose ("Drafted", "Accepted", "Implementation complete", etc.);
// `semver` is an optional structured field for events that carry
// machine-readable detail. `slice` is LEGACY — kept so historical events
// validate, never written in new events: naming a slice or OpenSpec change
// from an enhancement violates the one-way rule (plans cite enhancements;
// enhancements never cite plans — see plans/README.md).
//
// This list is the repo's *only* strictly append-only structure. Never delete
// or reorder past events; a reversal is a new event, not an edit. Everything
// else in an entry — decision bodies, Open Question prose, the narrative
// documents — is mutable, status-gated: revised in place while the entry is
// `draft`, and from `accepted` edited only via the `enhancement-compaction`
// protocol (a post-acceptance change appends a new DN instead). Git already
// holds the prose provenance; duplicating it in-band is what made these
// documents unreadable. What stays immutable outside this list is the
// *numbering*: `DN` and `OQN` are never reused and never renumbered, so
// citations from other repos keep resolving.
#HistoryEvent: {
	date!:   #DateStr
	event!:  string & strings.MinRunes(1)
	slice?:  string
	semver?: #SemverImpact

	// DESIGN milestones only — what happened to the design (drafted,
	// decisions locked, an OQ resolved, scope changed, accepted,
	// rejected, superseded). Never delivery progress: what shipped is
	// derived from the plans side. `task check` greps new events for
	// delivery verbs.
	//
	// The cap is the "an event is one line" rule made mechanical, the
	// same device as plans/schema.cue's 240-rune #SliceConcernStr. Prose
	// growing past it is the signal that the content belongs in a
	// document, a decision, or git — not in structured metadata.
	if date > #HistoryCapCutover {
		event: strings.MaxRunes(200)
	}
}

#EnhancementConfig: {
	id!:    #IDStr
	slug!:  #SlugStr
	title!: #TitleStr

	// One line: the capability OPM will have and does not today, or the
	// rework of one it has. This is the `feature` admission gate's answer
	// made durable (see gates.cue) — `task new` refuses without it.
	//
	// It is also what makes the archive readable: `task archive:list`
	// renders rejected ideas by summary, so a new entry can be checked
	// against prior art without opening eight documents each.
	summary!: string & strings.MinRunes(1) & strings.MaxRunes(200)

	status!:  #Status
	area!:    #Area
	affects!: [...#Area]

	// Declares whether this enhancement adds or changes definitions in the
	// opmodel.dev/core schema. `affects` is deliberately not the trigger —
	// it is a blast-radius field, and listing "core" there does not mean
	// the entry owns schema. This flag gates the NNNN/schemas/ convention:
	// the directory MUST exist iff true (target.cue — the core-schema
	// delta — plus examples.cue and spec.md from the draft → accepted
	// gate), and `affects` must then include "core". Directory presence,
	// the core-membership rule, and the status-gated file requirements are
	// enforced by `task vet` in bash — the same schema/graph split used
	// for `area ∈ affects` and the cross-ref checks.
	core_schema!: bool
	created!: #DateStr
	// ISO 8601 strings sort lexicographically — `>=created` enforces monotonic time.
	updated!:       #DateStr & >=created
	authors!:       [_, ...string]
	history!:       [...#HistoryEvent]
	related!:       [...#CrossRefStr]
	supersedes!:    [...#CrossRefStr]
	superseded_by!: null | #CrossRefStr

	// Archived ids this entry re-opens. A rejected idea legitimately
	// returns when circumstances change; what is not legitimate is
	// re-proposing it silently. Deliberately one-way — the archived entry
	// is frozen and gets no back-link, unlike supersedes/superseded_by.
	revives!: [...#CrossRefStr]

	// Optional metadata. Status-conditional constraints below tighten them.
	semver?: #SemverImpact

	// Why this idea was not accepted. Required at `rejected`, mirroring
	// plans/schema.cue's `cancelled_reason` on a cancelled slice: the id
	// is kept forever, so the record has to say why it stopped.
	rejected_reason?: string & strings.MinRunes(1)

	// Cross-field rules.

	// semver states the design's impact, so it is owed exactly when a
	// design was agreed. A rejected entry owes nothing: it was never
	// accepted, and forcing an impact assessment out of an idea being
	// killed is the kind of friction that stops people killing ideas.
	if status == "accepted" || status == "superseded" {
		semver!: #SemverImpact
	}

	// Tighten the null|#CrossRefStr to non-null when the entry is actually
	// superseded.
	if status == "superseded" {
		superseded_by: #CrossRefStr
	}

	// A killed idea keeps its id forever (citations must keep resolving)
	// and must say why it stopped. `task reject` writes both.
	if status == "rejected" {
		rejected_reason!: string & strings.MinRunes(1)
	}
}

