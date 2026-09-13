// Package identity is the single source of the catalog's module path and
// version. It sits at the bottom of the catalog's import graph (it imports
// nothing within the module) so transformer/resource/trait/blueprint
// subpackages can source `ModulePath`/`Version` without a circular import,
// and the root `catalog.cue` can stamp transformer metadata in lockstep.
//
// Committed with the REAL values (enhancement 0010 D5): a checkout and a
// published artifact compute the same FQNs. The only writer is `opm catalog
// version set` (enhancement 0011 D3/D15): release.yml runs it on the release
// PR with the version release-please decided, and branch-publish.yml stamps a
// `-dev.*` version into CI's working tree — never a commit — before
// `opm catalog publish`. Never hand-edit the value.
package identity

// ModulePath is the catalog's complete CUE module path, major suffix included
// — byte-identical to cue.mod's `module:` field (enhancement 0010 D1).
ModulePath: "opmodel.dev/catalogs/opm@v4"

// Version is the catalog's bare SemVer — the build every implementation key
// interpolates. A plain literal, written only by opm catalog version set; the major
// MUST agree with ModulePath's (asserted by core's #IdentityPackage at
// publish, enhancement 0011 refusal 10).
Version: "4.0.1"

// RegistryPath is the major-free OCI repository path.
RegistryPath: "opmodel.dev/catalogs/opm"

// WHY: Every member's metadata.modulePath carries the versioned path; authored
// fqns still derive from the base prefix, so the key space stays flat.

// kindPrefix mirrors core's #IdentityPackage.kindPrefix — one BASE prefix per
// kind (enhancement 0010 D42 as amended by D49). Contract members file exactly
// one segment beneath it, under their own apiVersion — a segment derived from
// the member's key, so filing and key cannot drift — while transformers file
// at the prefix itself.
kindPrefix: {
	resources:    RegistryPath + "/resources"
	traits:       RegistryPath + "/traits"
	blueprints:   RegistryPath + "/blueprints"
	transformers: RegistryPath + "/transformers"
}
