@if(collision)

package core

// Evaluated only with -t collision (and with -t noban to drop the
// #ArtifactRef ban, which restores the unpatched registryPath rule).

// ── P5: collision hazard in the cutover era: a FLAT-keyed catalog whose
// registryPath ends in /v5 produces opm@v5's major keys ──
_idEvil: #IdentityPackage & {ModulePath: "opmodel.dev/catalogs/opm/v5@v0", Version: "0.1.0"}
_evil: #mikCat & {#id: _idEvil, #flat: true}
P5: #Platform & {
	metadata: name: "collision"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": #catalog:    _opm5.catalog
		"opmodel.dev/catalogs/opm/v5@v0": #catalog: _evil.catalog
	}
}
