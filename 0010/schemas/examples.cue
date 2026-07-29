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

// AFTER (D1, D3, D5, D24, D25). The version stays and is committed rather than
// stamped — which is the whole fix, because the local checkout and the
// published artifact now interpolate the SAME value everywhere it appears.
// Under D24 that value keys the catalog's TRANSFORMERS and stamps every
// primitive's catalogVersion; the CONTRACTS key on their own apiVersion and do
// not move when the catalog releases.
_catalogAfter: {
	identityPkg: {
		ModulePath: "opmodel.dev/catalogs/opm@v1" // full path, major included
		Version:    "1.2.0"                       // committed concrete (D6 also permits `string`)
	}
	generatedAtPublish: "nothing"
	derived: {
		catalogFQN:     "opmodel.dev/catalogs/opm@v1"                            // an ADDRESS: @vN
		transformerFQN: "opmodel.dev/catalogs/opm/transformers/deployment@1.2.0" // an IMPL key: @SemVer
		resourceFQN:    "opmodel.dev/catalogs/opm/resources/config-maps@v1"      // a CONTRACT key: @vN
		sameFromLocal:  "opmodel.dev/catalogs/opm/transformers/deployment@1.2.0" // identical — D5/D6
	}
	// Provenance, on every primitive of every kind (D25). Never a contract key;
	// excluded from the match comparison entirely (D26); read by the matcher to
	// say which build each side of a match came from.
	stampedOnEachPrimitive: catalogVersion: "1.2.0"
	// The one value that is NOT derived from identity/identity.cue — an
	// author's judgement about the contract, per primitive (D25).
	authoredPerPrimitive: apiVersion: "v1"
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. The payoff — a contract fulfilled by a catalog that does not define it
// ─────────────────────────────────────────────────────────────────────────────

// catalog_opm defines a generic `backup` resource and ships NO transformer for
// it: the contract is meant to be fulfilled by whatever provider a platform
// installs. A k8up provider catalog ships the transformer that requires it.
//
// The two catalogs are compiled against different builds of catalog_opm and
// release on independent cadences. Under D24 they still meet, because the key
// names the contract rather than either build.
_providerFulfilled: {
	module: {
		builtAgainstCatalogOpm: "1.3.0"
		demands:                "opmodel.dev/catalogs/opm/resources/backup@v1"
	}
	provider: {
		catalog:                "opmodel.dev/catalogs/k8up@v1"
		builtAgainstCatalogOpm: "1.0.0"
		transformerFQN:         "opmodel.dev/catalogs/k8up/transformers/k8up-backup@2.4.0"
		requires:               "opmodel.dev/catalogs/opm/resources/backup@v1"
	}

	// Equal by construction — neither build appears in the key.
	keysMeet: module.demands == provider.requires
	keysMeet: true

	// What the always-unify rung then decides, measured in
	// experiments/02-primitive-closedness-skew (D27):
	outcomes: {
		moduleUsesOnlySharedFields: "renders — the provider is older and it does not matter"
		moduleUsesFieldAddedIn_1_1: "fails: spec.backup.retention: field not allowed"
		providerBuildNarrowedAType: "fails: conflicting values, both arms named"
	}

	// UNDER D13, for contrast: the module demanded ...backup@1.3.0 and the
	// provider supplied ...backup@1.0.0, so the keys never met and the demand
	// missed — regardless of whether the shapes were compatible. Coverage was
	// the set of catalog_opm builds the provider's release history happened to
	// pin, one per provider build.
	underD13: {
		moduleDemanded:   "opmodel.dev/catalogs/opm/resources/backup@1.3.0"
		providerSupplied: "opmodel.dev/catalogs/opm/resources/backup@1.0.0"
		result:           "no matching transformer"
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// 3b. What the matcher says when a demand misses (D24, D28)
// ─────────────────────────────────────────────────────────────────────────────

// Two failures, distinguished by whether ANY apiVersion of the contract is
// implemented — and with the build noise gone, each names the party that can
// fix it. Checked live in target.cue's commented MUST-FAIL cases; here they
// are the messages a user actually reads. Under D28 both fail the render.
_matcherDiagnostics: {
	// Nothing on this platform implements the contract. This is a statement
	// about the PLATFORM: it has no provider for something a module asked for.
	noProvider: {
		demanded: "opmodel.dev/catalogs/opm/resources/backup@v1"
		platformImplements: []
		message: "component \"web\" demands opmodel.dev/catalogs/opm/resources/backup@v1; no catalog subscribed by this platform implements that contract at any API version"
		today:   "no matching transformer — and only if the component matched nothing else at all"
	}

	// Implemented, at an API version this module does not speak. This is a
	// statement about the MODULE: it is on an older contract than the
	// platform's provider.
	wrongAPIVersion: {
		demanded: "opmodel.dev/catalogs/opm/resources/backup@v2"
		platformImplements: ["v1"]
		message: "component \"web\" demands opmodel.dev/catalogs/opm/resources/backup@v2; this platform implements opmodel.dev/catalogs/opm/resources/backup@v1"
		today:   "no matching transformer"
	}

	// Compatible keys, incompatible bodies — the failure that only exists once
	// a key spans several builds (D27, measured in experiments/02).
	providerTooOld: {
		demanded: "opmodel.dev/catalogs/opm/resources/backup@v1"
		platformImplements: ["v1"]
		moduleBuiltOn:   "1.3.0"
		providerBuiltOn: "1.0.0"
		message:         "component \"web\" sets spec.backup.retention, which opmodel.dev/catalogs/opm/resources/backup@v1 as built against catalog_opm 1.0.0 does not declare; this platform's provider predates that field"
		today:           "does not arise — the keys never met"
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
		declared: "Version: string"
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
