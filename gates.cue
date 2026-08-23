// Admission rubric for enhancement entries.
//
// Sits beside schema.cue (validates config.yaml) and plans/schema.cue
// (validates plan.yaml): contracts as data, next to the data they govern.
//
// WHY DATA AND NOT PROSE. These rules are judgment calls — "is this a
// feature or a chore?", "is this contract or mechanism?" — that no regex
// decides. They are enforced by an agent reading them, which only works if
// the agent reads a fixed enumerated list with an explicit evidence
// requirement per rule. Reconstructing rules from narrative paragraphs
// produces a rubber stamp; six numbered questions each demanding a quote
// does not. Keeping them here also means `task vet` validates the rubric
// itself, and `task gate` can render and run it.
//
// WHERE THEY CAME FROM. Most of this was already repo law, scattered:
// `feature` and `contract` were the unwritten test for what deserved an
// entry; `durability` is why the implementation axis was removed; `rewrite`
// is CLAUDE.md's prescriptive-mechanism rule; `prior-art` is what archive/
// exists for. Collecting them makes them checkable.
package enhancements

#GateID: "feature" | "contract" | "durability" | "rewrite" | "single-question" | "prior-art"

#Gate: {
	id!:    #GateID
	title!: string

	// When this gate is asked. `creation` runs before `task new` scaffolds
	// anything — the cheapest possible place to say no. `promotion` runs at
	// draft → accepted, where `task promote` refuses on a failure.
	applies_to!: [...("creation" | "promotion")]

	// The exact question the evaluator answers. Phrased so the honest
	// answer for a non-enhancement is "no".
	question!: string

	// What failure looks like, concretely. A vague failure condition is
	// how a verdict hides behind "seems fine".
	fails_when!: string

	// Where the rejected content goes instead. A gate with no destination
	// gets ignored the first time it is inconvenient, so every rule owes
	// one.
	redirect!: string

	// What the verdict MUST quote to be valid. A verdict with no evidence
	// is not a verdict.
	evidence!: string

	// Optional deterministic pre-filter. Regex catches the tells; the
	// question catches the category errors. Never write an AI gate for
	// what grep does better — `task gate` runs these first and hands the
	// hits to the evaluator as candidate evidence, which makes the quote
	// requirement cheap to satisfy honestly and awkward to fabricate.
	probe?: #Probe
}

#Probe: {
	// Extended regex, applied per line (grep -nE).
	pattern!: string

	// Lines matching this are dropped BEFORE matching. Evidential citation
	// is the desired state, not a smell: a path in a Source line or a dated
	// measurement is provenance the repo wants kept, and counting it would
	// reward deleting exactly what the rule protects.
	exclude?: string

	// Glob, relative to the entry directory.
	files!: string

	// One line: what a hit means. Printed beside each hit.
	hint!: string

	// `blocking` fails `task check`; `advisory` only surfaces as candidate
	// evidence for the walk. A hit is a smell, not proof.
	severity!: "blocking" | "advisory"
}

gates: [...#Gate] & [
	{
		id:    "feature"
		title: "Names a capability, not a chore"
		applies_to: ["creation", "promotion"]
		question:   "Does this name a capability OPM will have and does not have today, or a rework of one it has?"
		fails_when: "The subject is a bug fix, a cleanup, a dependency bump, a docs pass, a rename with no contract change, a process change, or a note-to-self."
		redirect:   "An OpenSpec change in the owning repo. A half-formed idea with no capability yet goes in IDEAS.md, not an entry."
		evidence:   "config.yaml.summary quoted, plus the sentence in 01-problem.md naming what cannot be done today."
	},
	{
		id:    "contract"
		title: "Changes something a consumer can rely on"
		applies_to: ["creation", "promotion"]
		question:   "Does this change what a consumer can observe or rely on — core schema, kernel behaviour, CLI surface, catalog contract, operator behaviour?"
		fails_when: "Nothing observable changes: the work is internal restructuring, or it only affects how a repo builds or tests itself."
		redirect:   "An OpenSpec change in the owning repo."
		evidence:   "The specific surface named, quoted from 02-design.md's Affected Surfaces. Spanning several repos is a symptom, not the test — a single-repo core reshape passes this gate and a five-repo refactor fails it. When config.yaml.affects has exactly one element, the verdict must additionally state what the entry records that the owning repo's OpenSpec change could not durably hold — a contract a consumer or another repo relies on, design intent that must outlive the change, or a seam with an actor outside the repo — quoting the sentence that carries it. An entry with no such sentence is that OpenSpec change, padded."
	},
	{
		id:    "durability"
		title: "Still true in a year"
		applies_to: ["promotion"]
		question:   "Is every sentence in 01..07 still true and useful a year after this ships, with no dates and no progress state?"
		fails_when: "Prose narrates what happened when, reports what is currently in flight, or records that a position changed rather than what the position now is."
		redirect:   "Delivery state belongs in plans/<slug>/plan.yaml, where it is expected to churn. Provenance belongs in git and in config.yaml.history."
		evidence:   "Three quoted sentences that read as a logbook, or an explicit statement that the probe returned no hits and a read of 01..07 found none."
		probe: {
			pattern:  #"\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b|\b(landed|shipped|in progress|currently|as of|next up)\b"#
			exclude:  #"^\*\*(Source|Revised):|[Mm]easured|verified|read (from|the same day)"#
			files:    "0[1-7]-*.md"
			hint:     "date or progress state in durable prose"
			severity: "advisory"
		}
	},
	{
		id:    "rewrite"
		title: "Binds a from-scratch rewrite"
		applies_to: ["promotion"]
		question:   "If every affected repo were rewritten from scratch, would this content still bind the result?"
		fails_when: "A document tells a repo how to name a file, spell an identifier, lay out a directory, or structure its code. The test between prescription and provenance: would deleting the named path change what an implementer is OBLIGED to do, or only what a reader can VERIFY? Obliged is prescription; verify is evidence and stays. Measuring how a mechanism behaves is evidence for a contract; prescribing which function in which file is instruction."
		redirect:   "The implementing slice's OpenSpec change in the target repo, which decides it with the current code in front of it."
		evidence:   "Per probe hit: either the rewrite that turned it into a contract statement, or the destination it moved to."
		probe: {
			pattern:  #"\.(go|cue|md|ya?ml|sh):[0-9]+|\b[a-zA-Z_][a-zA-Z0-9_]+\(\)"#
			exclude:  #"^\*\*(Source|Revised):|[Mm]easured|read (from|the same day)|verified"#
			files:    "0[1-7]-*.md"
			hint:     "file:line or function() token in durable prose"
			severity: "advisory"
		}
	},
	{
		id:    "single-question"
		title: "One design question at its heart"
		applies_to: ["creation", "promotion"]
		question:   "Is there one design question at the heart of this, or several unrelated ones bundled under a convenient title?"
		fails_when: "The decision log splits into groups that share no premise, and resolving one group would not change the answer to another."
		redirect:   "Split it. Two entries that cite each other in `related` read better than one that answers two questions badly."
		evidence:   "The decision headings grouped by premise, or 02-design.md's Goals quoted to show they share one."
	},
	{
		id:    "prior-art"
		title: "Not already rejected"
		applies_to: ["creation"]
		question:   "Has this idea, or its core claim, already been rejected? Compare against `task archive:data`."
		fails_when: "An archived entry states the same capability and this entry neither cites it in `revives` nor says what changed since it was killed."
		redirect:   "Set revives: [\"NNNN\"] and state in 01-problem.md what changed, or drop the idea. A rejected idea legitimately returns when circumstances change; what is not legitimate is re-proposing it silently."
		evidence:   "The archive ids compared, and the closest match's summary quoted beside this entry's."
	},
]
