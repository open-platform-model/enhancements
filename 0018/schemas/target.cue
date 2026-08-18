// Target schema for enhancement 0018 (Documentation Architecture).
//
// Four shapes: the section taxonomy keyed by what a reader is holding when
// they arrive, the enforcement badge vocabulary, the provenance
// classification for a reference entry's fields, and the doc-comment
// obligation a catalog member satisfies to pass the CI gate.
//
// Stating these in CUE rather than in prose makes the taxonomy testable
// before any page exists, and gives the generator a contract to emit
// against. Unresolved fields carry an OQ# comment pointing at
// ../03-decisions.md.
package schema

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

// The genre governing how pages in a section are written. Genre does not
// govern navigation (see 02-design.md), but it does govern voice, length and
// whether a page may assume prior reading.
#Genre: "tutorial" | "guide" | "reference" | "explanation"

#Section: {
	id!:       #SectionID
	title!:    string
	arriving!: #ReaderState
	genre!:    #Genre

	// Sections a reader is assumed to have read. Kept explicit so a guide
	// that silently restates a concept instead of linking it is visible.
	assumes?: [...#SectionID]

	// True when the section's pages are emitted by the generator rather than
	// authored. Only `reference` is generated wholesale; other sections may
	// still embed generated blocks.
	generated: bool | *false
}

#Sections: [...#Section]

// The taxonomy as decided. Each entry pairs a section with the single reader
// state it answers; no two sections answer the same state.
sections: #Sections & [
	{id: "start", title: "Start here", arriving: "nothing", genre: "tutorial"},
	{id: "concepts", title: "Concepts", arriving: "a question about why", genre: "explanation"},
	{id: "authoring", title: "Authoring modules", arriving: "a blank module file", genre: "guide", assumes: ["concepts"]},
	{id: "operating", title: "Deploying and operating", arriving: "a cluster", genre: "guide", assumes: ["concepts"]},
	{id: "extending", title: "Extending OPM", arriving: "a vocabulary gap", genre: "guide", assumes: ["concepts", "authoring"]},
	{id: "embedding", title: "Embedding the kernel", arriving: "a Go program", genre: "guide", assumes: ["concepts"]},
	{id: "reference", title: "Reference", arriving: "a field name", genre: "reference", generated: true},
	{id: "diagnostics", title: "Diagnostics", arriving: "an error message", genre: "reference"},
]

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

		// Authored: none of these is expressible in the CUE. Which blueprint
		// to start from is implied only by a transformer's requiredLabels, and
		// appliesTo is uniformly [#ContainerResource] on 26 of 27 traits and
		// therefore says nothing about what is legal where.
		{name: "whenToUse", provenance: "authored"},
		{name: "interactions", provenance: "authored"},
		{name: "familyGuidance", provenance: "authored"},

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
