// Target schema for enhancement 0018 (Documentation Architecture).
//
// Six shapes: the section taxonomy keyed by what a reader is holding when
// they arrive, the page contract every page declares (D7), the parts each
// page type carries (D9), the enforcement badge vocabulary, the provenance
// classification for a reference entry's fields, and the doc-comment
// obligation a catalog member satisfies to pass the CI gate.
//
// Stating these in CUE rather than in prose makes the taxonomy testable
// before any page exists, and gives the site engine a contract to validate
// pages against. Unresolved fields carry an OQ# comment pointing at
// ../07-questions.md.
package contracts

// ---------------------------------------------------------------------------
// Section taxonomy
// ---------------------------------------------------------------------------

// The eight top-level sections. Ordering is the reader's likely path on a
// first visit, not an importance ranking: Diagnostics is last in the list and
// is nonetheless an entry point, because readers arrive there from an error
// string rather than from navigation.
#SectionID: "start" | "concepts" | "authoring" | "operating" |
	"extending" | "embedding" | "reference" | "diagnostics"

// What the reader has in hand on arrival. This is the discriminator the
// taxonomy is built on: a section earns its place by being the answer to one
// of these, and a proposed section that answers none of them is a subsection
// of something else.
#ReaderState: "nothing" | "a question about why" | "a blank module file" |
	"a cluster" | "a vocabulary gap" | "a Go program" |
	"a field name" | "an error message"

#Section: {
	id!:       #SectionID
	title!:    string
	arriving!: #ReaderState

	// Sections a reader is assumed to have read. Kept explicit so a guide
	// that silently restates a concept instead of linking it is visible.
	assumes?: [...#SectionID]

	// True when the generator writes pages into the section. Only
	// `reference`, and authored reference pages such as the glossary sit
	// beside the generated ones there. A section holds pages of several
	// types; the type is declared per page, never per section (D7).
	generated: bool | *false
}

#Sections: [...#Section]

// The taxonomy as decided. Each entry pairs a section with the single reader
// state it answers; no two sections answer the same state.
sections: #Sections & [
	{id: "start", title: "Start here", arriving: "nothing"},
	{id: "concepts", title: "Concepts", arriving: "a question about why"},
	{id: "authoring", title: "Authoring modules", arriving: "a blank module file", assumes: ["concepts"]},
	{id: "operating", title: "Deploying and operating", arriving: "a cluster", assumes: ["concepts"]},
	{id: "extending", title: "Extending OPM", arriving: "a vocabulary gap", assumes: ["concepts", "authoring"]},
	{id: "embedding", title: "Embedding the kernel", arriving: "a Go program", assumes: ["concepts"]},
	{id: "reference", title: "Reference", arriving: "a field name", generated: true},
	{id: "diagnostics", title: "Diagnostics", arriving: "an error message"},
]

// ---------------------------------------------------------------------------
// Pages (D7)
// ---------------------------------------------------------------------------

// The four page types. Every page is exactly one; a section holds several.
#PageType: "tutorial" | "how-to" | "explanation" | "reference"

// What an authored page declares, and all it declares. Closed on purpose:
// the section a page belongs to and the address it is linked by come from
// where the page sits, so a page that also declares them fails to unify
// instead of drifting from its location.
#Page: {
	title!: string & !=""

	// One line. It is the page's entry on its section index and its search
	// snippet, so it is always written.
	description!: string & !="" & !~"\n"

	type!: #PageType

	// Order within the page's type group on the section index.
	weight?: int & >=0
}

// The order a generated section index groups its pages in.
indexOrder: [...#PageType] & ["tutorial", "how-to", "explanation", "reference"]

_examplePage: #Page & {
	title:       "Attach a trait to a component"
	description: "Add scaling, health checks or exposure to one component."
	type:        "how-to"
}

// ---------------------------------------------------------------------------
// Page shapes (D9)
// ---------------------------------------------------------------------------

// The parts a page of a type carries, in order, named by role. Exact heading
// wording belongs to the writing guide in the opm repo, not to this contract.
#Shape: [...string]

shapes: [#PageType]: #Shape
shapes: {
	tutorial: ["end result", "prerequisites", "numbered steps, each with expected output", "what was built", "next steps"]
	"how-to": ["what it achieves and when", "starting state", "steps", "how to check it worked", "related reference and concept"]
	explanation: ["how it works", "why it is built this way", "common misreadings", "what enforces it"]
	reference: ["what it lists", "entries ordered by the product's structure", "see also"]
}

// A generated catalog member or schema entry. One order everywhere, so a
// reader who has used one entry can find their way around every other.
generatedEntryShape: #Shape & ["summary", "at a glance", "spec", "example", "notes", "served by", "enforcement"]

// A diagnostics entry is a how-to guide with a fixed shape: its reader is at
// work fixing something, not looking something up.
diagnosticShape: {
	type: #PageType & "how-to"
	parts: #Shape & ["error name as printed", "exact message", "what it means", "causes, each with its fix", "where it is raised"]
}

// ---------------------------------------------------------------------------
// Enforcement badges
// ---------------------------------------------------------------------------

// The layer that refuses a violation. OPM enforces across four of them, and
// the gaps between them are where users are currently hurt: SPEC.md states
// MUSTs that nothing checks (`convention`) beside gates that do check
// (`publish`), without distinguishing them.
#EnforcementLayer: "cue" | "kernel" | "publish" | "convention"

#Enforcement: {
	layer!: #EnforcementLayer

	// Where the violation surfaces, in the reader's terms.
	surfacesAt!: string

	// True when nothing mechanical refuses a violation. Derived rather than
	// authored so the two cannot disagree.
	unchecked: layer == "convention"
}

// Worked examples, one per layer, each drawn from a real constraint.
_badgeExamples: {
	requiredField: #Enforcement & {
		layer:      "cue"
		surfacesAt: "cue vet, before any OPM tool runs"
	}
	unresolvedDemand: #Enforcement & {
		layer:      "kernel"
		surfacesAt: "opm instance vet, build, plan or apply"
	}
	additiveOnlyRule: #Enforcement & {
		layer:      "publish"
		surfacesAt: "opm catalog publish, at beta and GA contract levels"
	}
	layeringContract: #Enforcement & {
		layer:      "convention"
		surfacesAt: "nowhere; stated in core SPEC.md section 6 and enforced socially"
	}
}

// The derivation holds: exactly the convention example is unchecked.
_uncheckedIsDerived: _badgeExamples.layeringContract.unchecked & true
_checkedIsDerived:   _badgeExamples.additiveOnlyRule.unchecked & false

// ---------------------------------------------------------------------------
// Reference entry provenance
// ---------------------------------------------------------------------------

// Whether a field's content is derived from source or written by a human.
// The split is decided by one test: can a rename invalidate it silently?
// Generated content moves with the source; authored content explains a
// relationship and does not decay when a field is renamed.
#Provenance: "generated" | "authored"

#Field: {
	name!:       string
	provenance!: #Provenance

	// For generated fields, the source expression or origin. Required so that
	// "generated" is never a claim without a mechanism behind it.
	source?: string

	if provenance == "generated" {
		source!: string
	}
}

// A catalog member's reference entry. The generated half is emitted from
// evaluated CUE, never scraped from source text: metadata.description is
// populated on all 70 members today while doc-comment coverage is inverted
// against usage, so an evaluator gets 70 of 70 where a scraper gets a
// minority.
#MemberEntry: {
	fields: [...#Field]
}

memberEntry: #MemberEntry & {
	fields: [
		{name: "name", provenance: "generated", source: "metadata.name"},
		{name: "apiVersion", provenance: "generated", source: "metadata.apiVersion"},
		{name: "fqn", provenance: "generated", source: "metadata.fqn"},
		{name: "modulePath", provenance: "generated", source: "metadata.modulePath"},
		{name: "description", provenance: "generated", source: "metadata.description"},
		{name: "category", provenance: "generated", source: "metadata.labels"},
		{name: "specKey", provenance: "generated", source: "spec key derived from metadata.name"},
		{name: "specSchema", provenance: "generated", source: "the member's spec definition"},
		{name: "optionalPosture", provenance: "generated", source: "trait optional default"},
		{name: "appliesTo", provenance: "generated", source: "trait appliesTo"},
		{name: "composedResources", provenance: "generated", source: "blueprint composedResources"},
		{name: "composedTraits", provenance: "generated", source: "blueprint composedTraits"},
		{name: "matchLabels", provenance: "generated", source: "member matchLabels"},
		{name: "servedBy", provenance: "generated", source: "reverse index over transformer required and optional maps"},
		{name: "example", provenance: "generated", source: "the serving transformer's embedded golden test"},

		// Hand-written, but kept in source so a rename carries it along
		// (D10). It is the entry's body; the description is its summary.
		{name: "notes", provenance: "generated", source: "the member's doc comment"},

		// Not on the entry at all: guidance relating members to each other
		// (which blueprint to start from, which traits are legal where, how
		// members interact, when to use the raw family) lives in how-to
		// guides and explanations (D10). None of it is derivable: which
		// blueprint to start from is implied only by a transformer's
		// requiredLabels, and appliesTo is uniformly [#ContainerResource] on
		// 26 of 27 traits.

		// OQ2: whether a generated entry can carry an enforcement badge, or
		// whether badges are authored-only.
		{name: "enforcement", provenance: "authored"},
	]
}

// ---------------------------------------------------------------------------
// Doc-comment obligation
// ---------------------------------------------------------------------------

// The kinds the CI gate covers. The raw passthrough family is excluded from
// the backfill obligation because its coverage is already complete; the gate
// applies to it only to keep it that way.
#GatedKind: "blueprint" | "resource" | "trait"

// What a catalog member must carry to pass the gate. Presence is mechanical;
// usefulness is a review judgement, and the split is stated rather than
// pretended away.
#DocObligation: {
	kind!: #GatedKind

	// metadata.description is required on every member and is already
	// universally populated. The generator reads this, not the doc comment.
	description!: string & !=""

	// A doc comment is required when the member carries meaning a one-line
	// description cannot: a conflict between fields, a non-obvious default, a
	// reason the member exists at all.
	docComment?: string

	// OQ1: precedence when description and docComment disagree, and whether a
	// member may carry a docComment without a description.
}
