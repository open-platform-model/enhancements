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
// version drifts from the tag (measured on the live fleet — see 01-problem.md),
// and modulePath is a prefix that must be recombined with a name to produce an
// address.
_moduleBefore: {
	moduleCue: metadata: {
		name:       "postgres"
		modulePath: "opmodel.dev/modules" // prefix only
		version:    "2.0.0"               // authored; drifts from the tag
	}
	cueMod: module: "opmodel.dev/modules/postgres@v2"
	versionsYml: postgres: version: "v2.1.0" // a third answer
	derived: {
		fqn:         "opmodel.dev/modules/postgres:2.0.0" // version inside identity
		publishedAs: "v2.0.2"                             // a fourth
	}
}

// AFTER (D1, D5, D8, D38, D40, D41). One identity statement, in a committed
// SUBPACKAGE that OPM writes into.
//
// Note this is NOT the shape D7/D23 first specified — those put a module's
// identity in a root-package file writing `metadata:` directly, on the premise
// that a module declared no version and so had nothing to decide. D38 restored
// the version and reversed the premise; a module now carries a catalog-style
// identity/ subpackage. D7's MEASUREMENT still stands and is why: a top-level
// field beside the embedded #Module in the ROOT package fails at re-unification
// into the closed #ModuleInstance.#module slot with `field not allowed`, vetting
// clean standalone. A separate package is never unified into #Module.
_moduleAfter: {
	// identity/identity.cue — an importable package, two authored values.
	identityCue: {
		ModulePath: "opmodel.dev/modules/postgres@v2"
		Version:    "2.4.1"

		// Derived, never authored (D40), and asserted equal to the path's major.
		VersionMajor: "v2"
	}

	// module.cue — the author writes a name, and wires the two derivations that
	// `opm module init` templates. CUE enforces the wiring for free while it is
	// written; an author who REPLACES a derivation with a literal is caught by
	// 0011 D12's publish check.
	moduleCue: metadata: {
		name:       "postgres"
		modulePath: "id.ModulePath"
		version:    "id.Version"
	}

	cueMod: module: "opmodel.dev/modules/postgres@v2" // the same string

	derived: {
		fqn: "opmodel.dev/modules/postgres@v2" // == modulePath (D1)

		// registryPath: the major-free lineage identity (D41).
		registryPath: "opmodel.dev/modules/postgres"

		// uuid: SHA1(OPMNamespace, fqn) — ARTIFACT identity. Stable across every
		// 2.x release, and it MOVES at v3, because @v2 and @v3 are distinct
		// modules.
		//
		// instanceFqn: SHA1 input for OWNERSHIP identity, derived from
		// registryPath — so it survives the v3 bump the line above does not
		// (D41). This is the value the owner label carries and prune.go reads.
		instanceFqn: "opmodel.dev/modules/postgres:postgres-prod:prod"
	}

	// The tag, asserted equal to identity Version at publish (0011 D12) and
	// re-checked against it at acquire (D9), which is what lets the
	// module.opmodel.dev/version label come from the declared value.
	publishedAs: "v2.4.1"
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

// AFTER (D1, D3, D5, D4, D25). The version stays and is committed rather than
// stamped — which is the whole fix, because the local checkout and the
// published artifact now interpolate the SAME value everywhere it appears.
// Under D4 that value keys the catalog's TRANSFORMERS and stamps every
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
// release on independent cadences. Under D4 they still meet, because the key
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

	// UNDER THE BUILD-KEYED CONTRACTS D4 REPLACED, for contrast: the module
	// demanded ...backup@1.3.0 and the provider supplied ...backup@1.0.0, so the
	// keys never met and the demand missed — regardless of whether the shapes
	// were compatible. Coverage was the set of catalog_opm builds the provider's
	// release history happened to pin, one per provider build.
	underBuildKeyedContracts: {
		moduleDemanded:   "opmodel.dev/catalogs/opm/resources/backup@1.3.0"
		providerSupplied: "opmodel.dev/catalogs/opm/resources/backup@1.0.0"
		result:           "no matching transformer"
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// 3b. What the matcher says when a demand misses (D4, D28)
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
