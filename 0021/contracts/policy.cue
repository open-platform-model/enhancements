// Contracts for enhancement 0021: the OPM versioning policy as data.
//
// Kind of contract: a taxonomy plus the policy matrix from 02-design.md.
// Source of truth: 02-design.md and 03-decisions.md; this file mirrors
// them so that a class with a missing or contradictory cell fails
// `cue vet` instead of a reader. Settled rules are copied verbatim into
// ../policy/ under their source (D3). Unresolved cells carry `// OQN:` markers
// pointing at 07-questions.md.
package contracts

// Every class of artifact a consumer can pin. D1.
#ArtifactClass: "core" | "catalog" | "contract" | "transformer" | "module" | "template" | "kernel" | "cli" | "operator" | "crd" | "documentation"

// How a class carries its version.
#Carrier: "cue-module-semver" | "api-version-ladder" | "go-module-semver" | "k8s-group-version" | "inherited" | "open"

// The change classes U2 ranks. A release's bump is the maximum over its surface.
#ChangeClass: "breaking" | "additive" | "fix" | "invisible"

// SemVer levels, plus "none" for a change that publishes nothing.
#Level: "major" | "minor" | "patch" | "none"

// A bump table maps every change class to the level it demands.
#BumpTable: {
	breaking!:  #Level
	additive!:  #Level
	fix!:       #Level
	invisible!: #Level
}

// The ordinary SemVer mapping, stated once and reused by every SemVer carrier.
stableBump: #BumpTable & {
	breaking:  "major"
	additive:  "minor"
	fix:       "patch"
	invisible: "none"
}

// The enforcement ladder from 02-design.md. A class reaches exactly one
// highest layer; "open" marks a cell an Open Question still decides.
#Layer: "convention" | "claim" | "gate" | "aid" | "open"

// The pre-stable form a class uses, under U3 (promise off pre-stable).
#PreStable: "alpha-line" | "zero-major" | "alpha-rung" | "inherited" | "open"

#Policy: {
	class!:   #ArtifactClass
	carrier!: #Carrier

	// What a consumer can rely on across a version. Prose, one item per
	// surface; a second item means two surfaces (OQ1 for modules).
	surface!: [_, ...string]

	// For SemVer carriers the stable table; ladder carriers cite the ruling.
	bump!: #BumpTable | {cite!: string} | {inherits!: #ArtifactClass}

	prestable!: #PreStable

	// Highest enforcement layer the class's rules reach today.
	enforcement!: #Layer

	// Decisions (this entry's or inherited) that fix the row.
	cites: [...string]

	// Open Questions that still shape the row.
	open: [...string]
}

// The matrix. Keyed by class so a class cannot appear twice or be skipped
// silently: `complete` below asserts every #ArtifactClass has a row.
policies: [Name=#ArtifactClass]: #Policy & {class: Name}

policies: {
	core: {
		carrier: "cue-module-semver"
		surface: ["the published definitions of the core package"]
		bump: stableBump
		prestable:   "alpha-line"
		enforcement: "claim"
		cites: ["U1", "U3", "U5"]
		open: ["OQ6", "OQ13"] // OQ6: gate on definition subsumption; OQ13: major cascade
	}
	catalog: {
		carrier: "cue-module-semver"
		surface: ["the member set at each level, and the transformers keyed by the build"]
		bump: stableBump
		prestable:   "alpha-line"
		enforcement: "gate"
		cites: ["0010 D4", "0010 D44", "0011 D9", "0011 D15", "0011 D23"]
		open: ["OQ7"] // OQ7: how a contract-level event moves the build number
	}
	contract: {
		carrier: "api-version-ladder"
		surface: ["the contract's shape at its apiVersion"]
		bump: cite: "0010 D27 and D34: additive-only inside a beta or GA level; a break is a level bump"
		prestable:   "alpha-rung" // D5: a break at alpha should bump the alpha number; convention only
		enforcement: "aid"
		cites: ["0010 D27", "0010 D34", "0010 D35", "0020 D1", "0020 D6", "D5"]
		open: []
	}
	transformer: {
		carrier: "inherited" // keyed by the catalog build (0010 D44)
		surface: ["required and optional contracts, and the shape rendered for them"]
		bump: inherits: "catalog"
		prestable:   "inherited"
		enforcement: "convention" // D6: one registration per served level, shared body
		cites: ["0010 D44", "D4", "D6"]
		open: []
	}
	module: {
		carrier: "cue-module-semver"
		surface: [
			"the #config schema, compared by subsumption over accepted values", // D2
		]
		// OQ1: a second entry, "stateful identity of rendered resources", if adopted.
		bump: stableBump
		prestable:   "open" // OQ4
		enforcement: "open" // OQ5, OQ6: the gate; today "claim" via authored version + commit type
		cites: ["D2", "0010 D41", "0010 D45", "0011 D15"]
		open: ["OQ1", "OQ2", "OQ3", "OQ4", "OQ5", "OQ6", "OQ12"]
	}
	template: {
		carrier: "cue-module-semver" // rides the CLI's release train
		surface: ["the module surface applied to the scaffold it produces, plus the shortcut name"]
		bump: inherits: "cli"
		prestable:   "inherited"
		enforcement: "gate" // opm module publish at release
		cites: ["D4"]
		open: []
	}
	kernel: {
		carrier: "go-module-semver"
		surface: ["the exported Go API"] // OQ10: promised to whom
		bump: stableBump
		prestable:   "alpha-line"
		enforcement: "claim"
		cites: ["U1", "U3", "U6"]
		open: ["OQ10", "OQ14", "OQ16"] // OQ14: one train; OQ16: what replaces the migration ledger
	}
	cli: {
		carrier: "go-module-semver"
		surface: ["commands, flags, exit codes and declared machine-readable output"] // OQ8
		bump: stableBump
		prestable:   "alpha-line"
		enforcement: "claim"
		cites: ["U1", "U3", "U6"]
		open: ["OQ8", "OQ14"]
	}
	operator: {
		carrier: "go-module-semver"
		surface: ["controller behaviour over the served CRDs"]
		bump: stableBump
		prestable:   "alpha-line"
		enforcement: "claim"
		cites: ["U1", "U3", "U6"]
		open: ["OQ9", "OQ14"]
	}
	documentation: {
		carrier: "open" // OQ15: the tooling train's version, if OQ14 adopts one
		surface: ["the component versions a page describes"]
		bump: cite: "OQ15"
		prestable:   "open"
		enforcement: "open"
		cites: ["D4"]
		open: ["OQ14", "OQ15"]
	}
	crd: {
		carrier: "k8s-group-version"
		surface: ["the served schema of each group version"]
		bump: cite: "Kubernetes API versioning; OQ9 states OPM's position on served-alongside and conversion"
		prestable:   "alpha-rung"
		enforcement: "open" // OQ9
		cites: ["U3"]
		open: ["OQ9"]
	}
}

// Completeness: every artifact class has a row. Unifying the list of
// classes against the map's keys fails vet if one is missing.
complete: {
	for c in ["core", "catalog", "contract", "transformer", "module", "template", "kernel", "cli", "operator", "crd", "documentation"] {
		(c): policies[c].class & c
	}
}

// Every SemVer carrier uses the one stable table (U2), so a class cannot
// quietly invent its own mapping.
oneTable: {
	for name, p in policies if (p.bump & #BumpTable) != _|_ {
		(name): p.bump & stableBump
	}
}
