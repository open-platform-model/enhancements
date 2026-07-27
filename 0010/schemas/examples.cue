// Worked before/after values for review. These are illustrative, not the
// normative contract — target.cue holds that. They exist so the shape of an
// authored module and an authored catalog can be read directly rather than
// reconstructed from a decision log.
//
// Everything here vets, so a mistake in an example is a build failure rather
// than a documentation bug.
package schema

// ─────────────────────────────────────────────────────────────────────────────
// 1. #Module — what an author commits
// ─────────────────────────────────────────────────────────────────────────────

// BEFORE. Four separately-maintained statements of one identity. The declared
// version drifts from the tag (measured: jellyfin v2.0.1 and v2.0.2 both ship
// metadata.version "2.0.0"), and modulePath is a prefix that must be
// recombined with a name to produce an address.
_moduleBefore: {
	moduleCue: metadata: {
		name:       "jellyfin"
		modulePath: "opmodel.dev/modules" // prefix only
		version:    "2.0.0"               // authored; drifts from the tag
	}
	cueMod: module: "opmodel.dev/modules/jellyfin@v2"
	versionsYml: jellyfin: version: "v2.1.0" // a third answer
	derived: {
		fqn:         "opmodel.dev/modules/jellyfin:2.0.0" // version inside identity
		publishedAs: "v2.0.2"                             // a fourth
	}
}

// AFTER (D1, D2, D5, D8). One identity statement, in a committed file OPM
// writes into. No version anywhere in source.
_moduleAfter: {
	// identity.cue — sets metadata directly, declares no top-level field (D7).
	identityCue: metadata: modulePath: "opmodel.dev/m/acme/jellyfin@v2"

	// module.cue — the author writes a name and nothing else about identity.
	moduleCue: metadata: name: "jellyfin"

	cueMod: module: "opmodel.dev/m/acme/jellyfin@v2" // the same string

	derived: {
		fqn: "opmodel.dev/m/acme/jellyfin@v2" // == modulePath (D1)

		// uuid: SHA1(OPMNamespace, fqn) — stable across every 2.x release,
		// distinct from any v3.
	}
	publishedAs: "v2.1.0" // the tag, and the only version that exists
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. #Catalog — what an author commits
// ─────────────────────────────────────────────────────────────────────────────

// BEFORE. The version is a sentinel in source, replaced at publish by a file
// generated into a copy of the tree — so a local checkout and the published
// artifact disagree about every FQN the catalog ships, and both vet clean.
_catalogBefore: {
	identityPkg: {
		ModulePath: "opmodel.dev/catalogs/opm"
		Version:    "0.0.0-dev" // sentinel; real value written at publish
	}
	generatedAtPublish: "identity/version_override.cue" // in the artifact, not in git
	derived: {
		catalogFQN:     "opmodel.dev/catalogs/opm@1.0.0-alpha.2"
		transformerFQN: "opmodel.dev/catalogs/opm/transformers/deployment@1.0.0-alpha.2"
		sameFromLocal:  "opmodel.dev/catalogs/opm/transformers/deployment@0.0.0-dev" // diverges
	}
}

// AFTER (D1, D3, D5, D13). The version stays and is committed rather than
// stamped — which is the whole fix, because the local checkout and the
// published artifact now interpolate the SAME value into every FQN. The keys
// still carry the full SemVer (D13), so a key names the exact bytes it came
// from; what changed versus BEFORE is that the value is honest, not that it
// left the key.
_catalogAfter: {
	identityPkg: {
		ModulePath: "opmodel.dev/catalogs/opm@v1" // full path, major included
		Version:    "1.2.0"                       // committed concrete (D6 also permits `string`)
	}
	generatedAtPublish: "nothing"
	derived: {
		catalogFQN:     "opmodel.dev/catalogs/opm@v1"                            // an ADDRESS: @vN
		transformerFQN: "opmodel.dev/catalogs/opm/transformers/deployment@1.2.0" // a KEY: @SemVer
		resourceFQN:    "opmodel.dev/catalogs/opm/resources/config-maps@1.2.0"
		sameFromLocal:  "opmodel.dev/catalogs/opm/transformers/deployment@1.2.0" // identical — D5/D6
	}
	// Whether this survives as a separate required field is OQ6: under D13 it
	// is derivable from the FQN that interpolates it.
	stampedOnEachPrimitive: version: "1.2.0"
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. The payoff — cross-minor installs, which do not work today
// ─────────────────────────────────────────────────────────────────────────────

// Two modules authored against different minors of one catalog, installed on a
// platform subscribed to the v1 major. Under D13 the platform materializes
// EVERY published v1 build (D14), so its key space is the union of theirs and
// each module matches the exact build it was authored against.
//
// The mechanism is subscription breadth, not key collapse — which is why
// publishing 1.2.0 does not change what moduleA renders.
_crossMinor: {
	platform: {
		subscribedTo: "opmodel.dev/catalogs/opm@v1"
		// D14: the whole major, not `highestStable()`.
		materializedBuilds: ["1.0.0", "1.1.0", "1.2.0"]
	}

	moduleA: demands: "opmodel.dev/catalogs/opm/resources/config-maps@1.0.0"
	moduleB: demands: "opmodel.dev/catalogs/opm/resources/config-maps@1.1.0"

	// The composed transformer map carries one key set per materialized build.
	// Distinct versions produce distinct keys, so the builds never collide —
	// the invariant library/opm/materialize/index.go:57-64 already documents.
	platformSupplies: [
		"opmodel.dev/catalogs/opm/resources/config-maps@1.0.0",
		"opmodel.dev/catalogs/opm/resources/config-maps@1.1.0",
		"opmodel.dev/catalogs/opm/resources/config-maps@1.2.0",
	]

	moduleAOK: #PrimitiveDemand & {demanded: moduleA.demands, supplied: platformSupplies}
	moduleBOK: #PrimitiveDemand & {demanded: moduleB.demands, supplied: platformSupplies}

	// TODAY both fail, and the cause is the SUBSCRIPTION rather than the key:
	// an unfiltered subscription resolves one build (filter.go:43-47), so the
	// platform supplies only ...@1.2.0 and every older module misses with
	// `no matching transformer`, which names neither the build nor the gap.
	todaysDefaultSupply: ["opmodel.dev/catalogs/opm/resources/config-maps@1.2.0"]
}

// ─────────────────────────────────────────────────────────────────────────────
// 3b. What the matcher says when a demand misses (D13)
// ─────────────────────────────────────────────────────────────────────────────

// Under exact-key matching there is one failure, not D12's two, and it is
// diagnosable without deriving an owning catalog: strip the version off the
// demanded FQN, collect every supplied key sharing that path-and-name, and
// report the difference. Checked live in target.cue's commented MUST-FAIL
// cases; here they are the messages a user actually reads.
_matcherDiagnostics: {
	// The primitive exists, but not at the build this module was authored
	// against — the platform's subscription does not cover it.
	uncoveredBuild: {
		demanded: "opmodel.dev/catalogs/opm/resources/config-maps@1.3.0"
		platformCarries: ["1.0.0", "1.1.0", "1.2.0"]
		message: "component \"web\" demands opmodel.dev/catalogs/opm/resources/config-maps@1.3.0; this platform materialized 1.0.0, 1.1.0, 1.2.0 for that primitive — widen the subscription to opmodel.dev/catalogs/opm@v1"
		today:   "no matching transformer"
	}

	// No build of the platform's supplies that primitive at all: a catalog
	// that never shipped it, a typo, or an unsubscribed catalog. The empty
	// available set is what distinguishes this from the case above.
	absentPrimitive: {
		demanded: "opmodel.dev/catalogs/opm/resources/nonexistent@1.2.0"
		platformCarries: []
		message: "component \"web\" demands opmodel.dev/catalogs/opm/resources/nonexistent@1.2.0; this platform supplies no build of opmodel.dev/catalogs/opm/resources/nonexistent"
		today:   "no matching transformer"
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. The unfilled state (D6)
// ─────────────────────────────────────────────────────────────────────────────

// What a working tree looks like before a version has been decided, and what
// each mechanism does with it. Recorded as strings because the point is the
// behaviour, not the value.
_unfilled: {
	// D6: an open field. `cue vet -c` names the file and line; nothing renders.
	open: {
		declared: "Version: string @opm(identity, owner=publish)"
		vetC:     "Version: incomplete value string  ./identity/identity.cue:7:10"
		renders:  false
		// ModulePath stays concrete, so every FQN still evaluates and the match
		// key space is intact. Only the compatibility signal is missing.
		fqnsStillEvaluate: true
	}

	// The rejected alternative: a sentinel is a VALUE. It evaluates, it renders,
	// it flows into FQNs and labels, and both trees vet clean — so only a
	// cross-tree comparison reveals that they disagree.
	sentinel: {
		declared:                 "Version: string | *\"0.0.0-dev\""
		vetC:                     "passes"
		renders:                  true
		fqnsStillEvaluate:        true
		butDivergesFromPublished: true
	}
}
