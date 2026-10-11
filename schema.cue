// Schema for openspec/changes/<id>-<slug>/config.yaml (and the same file after
// archive): the facts of one enhancement entry.
//
// Repo-internal. NOT part of opmodel.dev/core@v2. Lives at the repo root so the
// contract sits next to the data it validates. Use
//   cue vet -d '#EntryConfig' schema.cue <config.yaml>
// to validate a single file, `task vet` for the full sweep, or
// tests/schema/run.sh for the valid and invalid fixtures.
package enhancements

import (
	"list"
	"strings"
)

#DateStr: =~"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

// Enhancement id: four digits, zero-padded.
#IDStr: =~"^[0-9]{4}$"

#SlugStr: =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

// Title bounded for one-line display in `task list`. The slug captures the
// long form; the entry's documents carry the full prose.
#TitleStr: string & strings.MinRunes(1) & strings.MaxRunes(80)

// Controlled vocabulary of work types. `category` names the ONE dominant type
// of work an enhancement is: the contract itself (schema), how a module is
// executed (runtime), how artifacts move from author to platform
// (distribution), generators/CI/test infrastructure (tooling), or none of
// those (misc). Single-valued and closed: `task index` partitions GRAPH.md by
// it, one diagram per value in this order, so an entry must live in exactly
// one. It is browse metadata, not design. `misc` must not become a place for
// half the entries; `task new` requires CATEGORY= so no value is the path of
// least resistance.
#Category: "schema" | "runtime" | "distribution" | "tooling" | "misc"

// A config.yaml holds facts only: no `updated` (docs-kit derives the date from
// git), no `depends_on`, `amends`, `supersedes` or `history` (history is
// `git log`, the edges are derived from the delta specs). `after` is a soft
// hint for the graph.

// Lifecycle of an entry (T2.2 section 4): draft and accepted live in
// openspec/changes/; the other four are archived endings.
#EntryStatus: "draft" | "accepted" | "delivered" | "rejected" | "superseded" | "withdrawn"

// Closed list of repos an entry may affect: the directory names of the
// workspace AGENTS.md "Repos" table, so `catalog_opm`, not `catalog`. It lists
// `opm-controller` beside `opm-operator`. Add a value here when a repo joins
// the workspace; do not allow free text.
#EntryRepo: "core" | "library" | "catalog_opm" | "cli" | "opm-operator" |
	"opm-controller" | "opm-portal" | "opm" | "opmodel.dev" | "docs-kit" |
	"enhancements" | "modules" | "opm-suite-installer" | ".github"

// Ids the allocator never hands out and no entry may carry. Regular fields,
// so `cue export -e reservedIds schema.cue` reads them.
//
// reservedIds: 0000 was the template folder and is never reused; 0028 and 0029
// are held for entries parked elsewhere.
// blockedIds: 0030 and 0031 stay out of use until the last phase has stripped
// every `0030:` citation from the other repos. That commit empties this list,
// and the next two entries then take 0030 and 0031. An archived id is never
// handed out either; that check reads the folders, not this file.
reservedIds: ["0000", "0028", "0029"]
blockedIds: ["0030", "0031"]

// `accepted` is "<date> <commit>": the date and the `main` commit the accept
// PR started from, whose specs/ the checks read.
#AcceptedStr: =~"^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9a-f]{7,40}$"

// The record of a rejection or a withdrawal.
#EntryEnding: {
	date!:   #DateStr
	reason!: string & strings.MinRunes(1)
}

// The record of a supersession: the successor ids, at least one.
#EntrySuperseded: {
	date!: #DateStr
	ids!: [#IDStr, ...#IDStr] & list.UniqueItems()
	reason!: string & strings.MinRunes(1)
}

#EntryConfig: {
	// "NNNN", equal to the folder prefix (the checker compares them). A
	// reserved or blocked id is refused here.
	id!: #IDStr
	for r in list.Concat([reservedIds, blockedIds]) {
		id: !=r
	}

	// Kebab-case. The folder is <id>-<slug>.
	slug!: #SlugStr

	// At most 80 characters, one line.
	title!: #TitleStr & !~"\n"

	// One line, at most 200 characters: the capability OPM gains.
	summary!: string & strings.MinRunes(1) & strings.MaxRunes(200) & !~"\n"

	// Stored, because the docs site reads this one file. The checker also
	// refuses a value that disagrees with the markers or the folder.
	status!: #EntryStatus

	category!: #Category

	// Does the entry break a published contract? May be unset in a draft;
	// required once the entry is accepted (see the guards below). A version
	// bump stays each repo's own rule.
	breaking?: bool

	// At least one repo, no repeats. The first element is typed too: the
	// form `[_, ...T]` leaves it unchecked.
	affects!: [#EntryRepo, ...#EntryRepo] & list.UniqueItems()

	authors!: [string, ...string]

	// The date the entry was created. A new-layout entry has no `updated`.
	created!: #DateStr

	// Soft hint for the graph: entries this one follows. It blocks nothing.
	// The checker refuses an id that does not exist and a cycle.
	after?: [...#IDStr] & list.UniqueItems()

	// The record that belongs to a status. A record that does not belong to
	// the status is not allowed (a draft and a rejected entry were never
	// accepted, so they carry no `accepted`), and a record the status needs is
	// required.
	if status == "accepted" || status == "delivered" {
		accepted!: #AcceptedStr
		breaking!: bool
	}
	if status == "superseded" {
		accepted?:      #AcceptedStr
		superseded_by!: #EntrySuperseded
	}
	if status == "withdrawn" {
		accepted?:  #AcceptedStr
		withdrawn!: #EntryEnding
	}
	if status == "rejected" {
		rejected!: #EntryEnding
	}
}
