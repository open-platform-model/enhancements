// The shared policy schema, as it would ship in a package every repo imports
// (0021 proposes opmodel.dev/core/policy). Copied here, not referenced:
// the experiment demonstrates the shape at one moment.
package policy

import (
	"strings"
	"list"
)

#ArtifactClass: "core-schema" | "catalog-build" | "catalog-contract" | "transformer" | "module" | "cli-template" | "kernel" | "cli" | "operator" | "crd" | "documentation"
#Carrier:       "cue-module-semver" | "api-version-ladder" | "go-module-semver" | "k8s-group-version" | "inherited" | "open"
#PreStable:     "alpha-line" | "zero-major" | "alpha-rung" | "inherited" | "open"
#Level:         "major" | "minor" | "patch" | "none"
#Strength:      "must" | "should" | "may"
#Layer:         "convention" | "claim" | "gate" | "aid"

#BumpTable: {breaking!: #Level, additive!: #Level, fix!: #Level, invisible!: #Level}

// The bump cell is a discriminated union, and each form carries its own
// rendered text, so the renderer never has to inspect which form it got.
#Bump: {
	kind:  "table"
	table: #BumpTable
	text:  "breaking → \(table.breaking), additive → \(table.additive), fix → \(table.fix), invisible → \(table.invisible)"
} | {
	kind: "cite"
	cite: string
	text: "see \(cite)"
} | {
	kind:  "inherits"
	class: #ArtifactClass
	text:  "inherits the \(class) class"
}

// Universal data every policy file imports rather than restates.
stableBump: #BumpTable & {breaking: "major", additive: "minor", fix: "patch", invisible: "none"}
universal: [
	"U1: SemVer 2.0 everywhere; major in the path for CUE modules.",
	"U2: One named surface per class; a release's bump is the maximum change class across it.",
	"U3: Pre-stable means the promise is off, and the line says so.",
	"U4: A version is declared by an author or a release tool, never predicted by publish.",
	"U5: A major is an import rewrite; each class names what survives it.",
	"U6: Publish-side gates where the surface is comparable, convention where it is not; a check command is an aid.",
	"U7: No consumer window; producer-side seasoning where retirement exists.",
]

#Rule: {
	id!:        =~"^R[0-9]+$"
	statement!: string & =~"\\b(MUST|SHOULD|MAY)\\b" // one sentence carrying its own strength word
	strength!:  #Strength
	layer!:     #Layer
	source!:    [_, ...string]
	enforcedBy?: string
	examples?: {pass?: [...string], fail?: [...string]}

	// Invariants the schema carries so vet, not review, catches them.
	// A "gate" rule names what refuses.
	if layer == "gate" {enforcedBy!: string}
	// A "must" that nothing enforces must say why; that is the case where the
	// label overstates the enforcement (the MIGRATIONS.md failure mode).
	if strength == "must" && layer == "convention" {unenforcedBecause!: string}
	// The strength word in the sentence agrees with the field.
	statement: =~"\\b\(strings.ToUpper(strength))\\b"
}

#Policy: {
	class!:     #ArtifactClass
	repo!:      string
	carrier!:   #Carrier
	surface!:   [_, ...string]
	bump!:      #Bump
	prestable!: #PreStable
	rules:      [Id=string]: #Rule & {id: Id}
}

// #Render: the Markdown page for one policy, as a CUE string. No Go.
#Render: {
	#p: #Policy
	let byStrength = {
		for s in ["must", "should", "may"] {
			(s): [for id, r in #p.rules if r.strength == s {r}]
		}
	}
	let sections = [
		for s in ["must", "should", "may"] if len(byStrength[s]) > 0 {
			let rows = [for r in byStrength[s] {
				let enf = [if r.enforcedBy != _|_ {r.enforcedBy}, "n/a"][0]
				let why = [if r.unenforcedBecause != _|_ {" Unenforced because: \(r.unenforcedBecause)"}, ""][0]
				"- **\(r.id)** (\(r.layer); enforced by `\(enf)`): \(r.statement) Source: \(strings.Join(r.source, ", ")).\(why)"
			}]
			"### \(strings.ToUpper(s))\n\n\(strings.Join(rows, "\n"))"
		},
	]
	out: """
		<!-- GENERATED from policy/\(#p.class).cue by `cue eval -e render --out text`. Edit the CUE, regenerate. -->
		# Versioning policy: \(#p.class)

		Repo: `\(#p.repo)`

		| Cell | Value |
		| --- | --- |
		| Carrier | \(#p.carrier) |
		| Surface | \(strings.Join(#p.surface, "; ")) |
		| Bump | \(#p.bump.text) |
		| Pre-stable | \(#p.prestable) |

		## Universal rules

		\(strings.Join([for u in universal {"- \(u)"}], "\n"))

		## Rules

		\(strings.Join(sections, "\n\n"))

		"""
}

// Convenience: every #Policy in the package renders under its class name.
render: {for _, p in policies {(p.class): (#Render & {#p: p}).out}}
policies: [string]: #Policy
_ok: list.UniqueItems([for _, p in policies {p.class}])
_ok: true
