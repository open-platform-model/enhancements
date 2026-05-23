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
	"orca" | "modules" | "releases" | "cross-cutting"

// History event — append-only timeline of milestones. The `event` string is
// free-form prose ("Drafted", "Accepted", "Slice <id> archived", etc.);
// `slice` and `semver` are optional structured fields for events that carry
// machine-readable detail. `vet` enforces append-only via git diff against
// HEAD~1 (see Taskfile, future).
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
