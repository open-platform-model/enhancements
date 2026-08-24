// Schemas for enhancements/NNNN/config.yaml and NNNN/delivery.yaml.
//
// Repo-internal — NOT part of opmodel.dev/core@v0. Lives at the repo root so
// the contracts sit next to the data they validate. Use
//   cue vet -d '#EnhancementConfig' enhancements/schema.cue <config.yaml>
//   cue vet -d '#Delivery'          enhancements/schema.cue <delivery.yaml>
// to validate a single file, or `task vet` for the full sweep.
// #ChangeDeclaration validates the optional enhancement.yaml a target repo's
// OpenSpec change carries (read by `task delivery:log` / `delivery:reconcile`).
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

// Design lifecycle. There is no `implemented` state here and no stored
// implementation flag: delivery state is DERIVED (`task delivery`) from the
// entry's own append-only delivery log (NNNN/delivery.yaml, see #Delivery
// below): `implemented` means every live decision is covered by a logged
// change or excused in `no_work`, computed, never asserted. `accepted` is
// the resting state; `rejected` and `superseded` are the two terminal ones,
// and a terminal entry ALWAYS lives in archive/NNNN/ (`task reject` /
// `task supersede` do the move; `task vet` enforces the placement in both
// directions).
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
// validate, never written in new events: what landed where belongs in the
// entry's delivery log (NNNN/delivery.yaml), not in history prose.
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
	// recorded structurally in the entry's delivery log (delivery.yaml)
	// and derived from there. `task check` greps new events for
	// delivery verbs.
	//
	// The cap is the "an event is one line" rule made mechanical, the
	// same device as #LogEntry's 240-rune summary. Prose growing past it
	// is the signal that the content belongs in a document, a decision,
	// or git — not in structured metadata.
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

	// Why this idea was not accepted. Required at `rejected`: the id is
	// kept forever, so the record has to say why it stopped.
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


// ─── Delivery log ───────────────────────────────────────────────────────────
//
// NNNN/delivery.yaml is the entry's implementation LOG: an append-only record
// of changes that have LANDED (an OpenSpec change archived, a PR merged, a
// commit pushed), each carrying the decision numbers it implemented. It is a
// log of facts, never a forecast: no slices, no phases, no dependency graph,
// and nothing is written before the work lands. The plans/ forecast tree was
// retired in favor of this file (2026-08-24); a forecast has to be right
// about the future, a log only has to be true about the past.
//
// Delivery state is DERIVED from this file by `task delivery`:
//
//   implemented  every live DN in 03-decisions.md (tombstones excluded) is
//                carried by a log entry's `decisions` or excused in `no_work`
//   in-progress  the log is non-empty but coverage is incomplete
//   not-started  no delivery.yaml, or an empty log
//
// The failure direction is safe by construction: a forgotten log entry
// under-reports (the entry stays in-progress) and can never produce a false
// `implemented`. `task delivery:reconcile` detects archived OpenSpec changes
// that declared this entry (enhancement.yaml) but were never logged.
//
// The file is deliberately NOT part of the gate-verdict content hash
// (scripts/entry_hash.sh covers *.md/*.cue only): appending to the log must
// not void a walked gate, because the log records execution, not design.
//
// Cross-entry carriage: when one change implements decisions of two entries,
// log the same change ref in BOTH entries' delivery.yaml, each with its own
// local `decisions` list.

// A decision / Open Question reference, LOCAL to the entry that owns the
// delivery.yaml. No "NNNN:" qualifier (unlike the retired plans/ tree), since
// the file lives inside the entry it describes. Numbers are immutable, so a
// reference resolves for the life of the repo. Resolution against
// 03-decisions.md / 07-questions.md is checked by `task vet` (bash), not
// expressible here.
#DNumStr:  =~"^D[0-9]+$"
#OQNumStr: =~"^OQ[0-9]+$"

// A stable, structured reference to the change that landed. Never a path and
// never a URL: paths break when an OpenSpec change is archived (the directory
// moves), URLs rot. The (repo, key) pair is permanent:
//
//   openspec  repo + change slug (WITHOUT the archive date prefix; the slug
//             survives the changes/ to changes/archive/YYYY-MM-DD-<slug>
//             move and is unique per repo)
//   pr        repo + PR number, for repos without an OpenSpec workspace
//   commit    repo + sha, for work that landed without a PR (log only after
//             merge; rebases invalidate pre-merge shas)
#ChangeRef: {
	kind!:   "openspec"
	repo!:   #Area
	change!: #SlugStr
} | {
	kind!:   "pr"
	repo!:   #Area
	number!: int & >0
} | {
	kind!: "commit"
	repo!: #Area
	sha!:  =~"^[0-9a-f]{7,40}$"
} | {
	// Pre-tracking landing: work that shipped before delivery tracking
	// existed (before plans/, before this log), where per-change
	// archaeology would invent precision the record never had. `repo` is
	// the primary area; `note` says what landed and why no resolvable ref
	// exists. NOT for new work: every change landing today has an OpenSpec
	// change, a PR, or a commit to cite.
	kind!: "retrospective"
	repo!: #Area
	note!: string & strings.MinRunes(1)
}

// One landed change. Appended when the work lands, not when it starts: a
// logged-but-unfinished change would count its decisions as covered
// prematurely and corrupt the derivation.
#LogEntry: {
	date!: #DateStr

	// What landed, one line. The 240-rune cap is the "a log line is one
	// line" rule made mechanical (same device as the history-event cap).
	// Decision citations go in `decisions`, not here.
	summary!: string & strings.MinRunes(1) & strings.MaxRunes(240)

	change!: #ChangeRef

	// Which of this entry's decisions the change carried. Optional: a
	// change may legitimately implement no numbered decision (a mechanical
	// retarget, a release cut). What `task delivery:uncovered` reports is
	// decisions with no change, not changes with no decision.
	decisions?: [...#DNumStr]

	// Open Questions this change resolves; claims an OQ the entry closed
	// as `Status: deferred-to-implementation`. `task delivery:deferred`
	// reports deferred OQs no log entry claims.
	resolves?: [...#OQNumStr]
}

#Delivery: {
	log!: [...#LogEntry]

	// Decisions that genuinely need no change, each with the reason: one
	// that only DELETES something, one whose whole content is a
	// documentation holding, one superseded before any work carried it.
	// Exists so `task delivery:uncovered` can be quiet about them without
	// going silent in general (a coverage check that cries wolf stops
	// being read). Not a suppression list: an entry here is a claim on the
	// record, reviewed like any other line. Tombstoned numbers need no
	// entry; they are excluded from coverage automatically.
	no_work?: [#DNumStr]: string & strings.MinRunes(1)
}

// ─── Change declaration (lives in the TARGET repo, not here) ────────────────
//
// <repo>/openspec/changes/<slug>/enhancement.yaml, written when the change is
// CREATED, while the enhancement is in context, so that logging at archive
// time is mechanical. The archive guidance in each repo's openspec
// config.yaml points the archiving agent at `task delivery:log FROM=<dir>`,
// which reads this file; `task delivery:reconcile` scans all repos for these
// files and reports archived-but-unlogged changes.
//
// The file rides along on archive (the whole change directory is moved) and
// is invisible to the openspec CLI. It is a claim, not proof; review of the
// resulting log line is what checks it.
#ChangeImplements: {
	enhancement!: #IDStr
	decisions?: [...#DNumStr]
	resolves?: [...#OQNumStr]
}

#ChangeDeclaration: {
	implements!: [#ChangeImplements, ...#ChangeImplements]
}
