// Worked before/after examples for review (D13–D20). These are illustrative
// values, not the normative schema — target.cue holds the contract. They exist
// so the shape of an authored module and an authored catalog can be read
// directly rather than reconstructed from a decision log.
//
// Everything here vets, so a mistake in an example is a build failure rather
// than a doc bug. Cases that MUST fail are commented, with the error they
// produce recorded next to them.
package contracts

// ─────────────────────────────────────────────────────────────────────────────
// 1. #Module — what an author writes
// ─────────────────────────────────────────────────────────────────────────────

// BEFORE. Three separately-maintained statements of the same identity, plus a
// fourth in modules/versions.yml. metadata.version is authored and drifts from
// the tag (measured: jellyfin v2.0.1 and v2.0.2 both ship metadata.version
// "2.0.0"); modulePath is a bare prefix that must be recombined with the name
// to produce an address.
_moduleBefore: {
	source: {
		metadata: {
			name:       "jellyfin"
			modulePath: "opmodel.dev/modules" // prefix only
			version:    "2.0.0"               // authored, drifts
		}
	}
	cueMod: module: "opmodel.dev/modules/jellyfin@v2"
	versionsYml: jellyfin: version: "v2.1.0" // third source of truth
	derived: {
		fqn:         "opmodel.dev/modules/jellyfin:2.0.0" // version in identity
		publishedAs: "v2.1.0"                             // ≠ the version inside
	}
}

// AFTER (D13 + D16). One authored identity statement. No version anywhere in
// source; the version is the tag, and nothing in the module claims one.
_moduleAfter: {
	source: {
		metadata: {
			name: "jellyfin"
			// modulePath: see _modulePathOpen below — authored or derived is
			// the one thing still undecided.
			modulePath: "opmodel.dev/m/acme/jellyfin@v2"
			// version: REMOVED (D13).
		}
	}
	cueMod: module: "opmodel.dev/m/acme/jellyfin@v2" // same string
	derived: {
		fqn: "opmodel.dev/m/acme/jellyfin@v2" // == modulePath (D16)
		// uuid: SHA1(OPMNamespace, fqn) — formula unchanged, stable across
		// every 2.x release because no minor/patch appears in fqn.
	}
	publishedAs: "v2.1.0" // the tag, and the only version that exists
}

// STILL OPEN — is modulePath authored, or derived from cue.mod/module.cue?
// Both produce the identical value locally and published, because both read
// the same file (cue.mod/module.cue ships inside the artifact zip — verified).
// The choice is ergonomics, not correctness.
_modulePathOpen: {
	authored: note:   "D16 as recorded. One line duplicated with cue.mod, checked at publish and acquire."
	derivedByEmbed: note: "@extern(embed) + @embed(file=\"cue.mod/module.cue\", type=text) + regexp. Verified working; never hand-written; untested through library's overlay load path."
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. #Catalog — what an author writes
// ─────────────────────────────────────────────────────────────────────────────

// BEFORE. The version is a sentinel in source, overwritten at publish by a
// generated file that exists only in the artifact — so a local checkout and the
// published artifact disagree about every FQN the catalog ships (experiment 01).
_catalogBefore: {
	identityPkg: {
		ModulePath: "opmodel.dev/catalogs/opm"
		Version:    "0.0.0-dev" // sentinel; real value stamped at publish
	}
	generatedAtPublish: "identity/version_override.cue" // in artifact, not in git
	derived: {
		catalogFQN:     "opmodel.dev/catalogs/opm@1.0.0-alpha.2"
		transformerFQN: "opmodel.dev/catalogs/opm/transformers/deployment@1.0.0-alpha.2"
		localFQN:       "opmodel.dev/catalogs/opm/transformers/deployment@0.0.0-dev" // diverges
	}
}

// AFTER (D16 + D18 + D19). The version stays — it is the compatibility signal —
// but it is committed concretely rather than stamped, and it is no longer in
// any FQN. FQNs carry the major only, so they are stable across the 1.x series.
_catalogAfter: {
	identityPkg: {
		ModulePath: "opmodel.dev/catalogs/opm@v1" // full path, major included
		Version:    "1.2.0"                       // committed concrete (exp 02 variant B)
	}
	generatedAtPublish: "nothing" // artifact bytes == source bytes (D4)
	derived: {
		catalogFQN:     "opmodel.dev/catalogs/opm@v1"                          // == ModulePath
		transformerFQN: "opmodel.dev/catalogs/opm/transformers/deployment@v1"  // major-keyed (D18)
		resourceFQN:    "opmodel.dev/catalogs/opm/resources/config-maps@v1"    // same rule
		localFQN:       "opmodel.dev/catalogs/opm/transformers/deployment@v1"  // identical — no divergence
	}
	// Every primitive still carries the full version as metadata, stamped by
	// #Catalog's pattern constraint. It is the compat signal, not the key.
	stampedOnEachPrimitive: version: "1.2.0"
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. The payoff — cross-minor installs, which do not work today
// ─────────────────────────────────────────────────────────────────────────────

// Two modules authored against different minors of the same catalog, installed
// on one platform that materialized a third. All three agree on every key.
_crossMinor: {
	platform: materializedCatalog: "1.2.0"

	moduleA: {
		builtAgainst: "1.0.0"
		demands:      "opmodel.dev/catalogs/opm/resources/config-maps@v1"
	}
	moduleB: {
		builtAgainst: "1.1.0"
		demands:      "opmodel.dev/catalogs/opm/resources/config-maps@v1"
	}
	platformSupplies: "opmodel.dev/catalogs/opm/resources/config-maps@v1"

	// Both match, because the key carries no minor.
	moduleAMatches: moduleA.demands & platformSupplies
	moduleBMatches: moduleB.demands & platformSupplies

	// And both clear the D19 floor, because the platform is newer than either.
	moduleAOK: #CatalogCompat & {requiredVersion: moduleA.builtAgainst, resolvedVersion: platform.materializedCatalog}
	moduleBOK: #CatalogCompat & {requiredVersion: moduleB.builtAgainst, resolvedVersion: platform.materializedCatalog}

	// TODAY this fails: every FQN embeds the full version, so moduleA demands
	// ...@1.0.0 while the platform supplies ...@1.2.0 — no key matches, and the
	// symptom is `no matching transformer` naming neither catalog nor version.
	todaysBrokenDemand: "opmodel.dev/catalogs/opm/resources/config-maps@1.0.0"
	todaysBrokenSupply: "opmodel.dev/catalogs/opm/resources/config-maps@1.2.0"
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. The failure the compat signal catches (D19)
// ─────────────────────────────────────────────────────────────────────────────

// A module needing a primitive introduced in catalog 1.2.0, on a platform still
// materializing 1.0.0. Under major-only keys this would otherwise surface as a
// missing FQN; the version comparison names the real cause.
//
// MUST FAIL — uncommenting yields:
//   satisfied: conflicting values false and true
//
//  _platformTooOld: #CatalogCompat & {
//   requiredVersion: "1.2.0"
//   resolvedVersion: "1.0.0"
//  }

// ─────────────────────────────────────────────────────────────────────────────
// 5. The dev placeholder (D20) and the question it opens (OQ17)
// ─────────────────────────────────────────────────────────────────────────────

_devPlaceholder: {
	// D20: the major is identity-bearing, so it must be REAL even in a
	// placeholder. Only minor/patch/prerelease are invented.
	correct: "2.0.0-dev" // v2 artifact rendered from a local checkout
	wrong:   "0.0.0-dev" // would change fqn → uuid → every resource label

	// OQ17: under true SemVer a prerelease sorts BELOW its release, so a dev
	// catalog at 1.0.0-dev reads as older than every published 1.x and would
	// fail the D19 floor for any module built against 1.2.0 — breaking the dev
	// loop exactly when someone is working on the catalog.
	oq17: {
		devCatalog:      "1.0.0-dev"
		moduleRequires:  "1.2.0"
		underRealSemver: "FAILS the floor — 1.0.0-dev < 1.2.0"
		underTargetCue:  "PASSES — the illustration ignores prerelease ordering"
		// Candidate fix: make the placeholder sort high, since a dev build is
		// by construction ahead of every release.
	}
}
