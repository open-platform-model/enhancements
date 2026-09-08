// Core-schema delta for enhancement 0026: Module-Dictated Catalog Versions
// and the Generated Platform.
//
// Delta manifest (vs opmodel.dev/core@v2). The file is standalone rather
// than importing opmodel.dev/core, so the entry vets offline; MIRROR marks
// an unchanged core type restated in reduced form for the delta to reference.
//
//   #PlatformSpec   NEW        the authored platform: pure data, no imports.
//                              Metadata, type, and a path-keyed map of
//                              admitted catalog lineages (D2). Mirrors the
//                              Platform CRD's spec.
//   #Subscription   NEW        one admitted lineage: path with major, enable,
//                              optional registry override, required floor,
//                              optional ceiling (D2). Same major is structural
//                              through the path; ordering is a kernel check.
//   #Platform       UNCHANGED  the render-time value 0019 D5 shipped, now
//                              generated per resolution from #PlatformSpec
//                              plus the module's committed pins (D3). Not
//                              restated: nothing in its shape changes.
//   #CatalogEntry   UNCHANGED  shape unchanged; `version`'s documented
//                              meaning widens to "the version this build
//                              holds" (D1). Not restated.
//   #ModulePathType MIRROR     reduced: module path with a major suffix.
//   #VersionType    MIRROR     reduced: semver with optional prerelease.
//   #NameType       MIRROR     reduced: DNS label.
//
// The registration window (D5, D6) is a catalog_opm contract change on the
// transformer-registration resource, not a core definition, and is
// therefore not part of this delta.
//
// Unresolved fields carry `// OQN:` markers pointing at 07-questions.md.
package schema

import (
	"regexp"
	"strings"
)

// ─── MIRROR: core scalar types (reduced) ────────────────────────────────────

// Kubernetes-style DNS label.
#NameType: =~"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" & strings.MaxRunes(63)

// A CUE module path with its major: the artifact's identity (0010 D1).
#ModulePathType: =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$"

// Semver release, prerelease admitted.
#VersionType: =~"^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

// ─── NEW: #Subscription ─────────────────────────────────────────────────────

// One admitted catalog lineage. Admits and bounds; never loads (D4).
//
// The major is read from the path, so "same major" between the path and
// the range is structural: every version here MUST carry the path's major,
// and that is the one ordering-adjacent fact CUE can check. floor <= ceiling
// and pin-in-range are version orderings CUE cannot express and are kernel
// checks stated as contract in D2.
#Subscription: {
	// Identity of the lineage: module path with major (0010 D1). Bound to
	// the map key by #PlatformSpec.
	path!: #ModulePathType

	enable: bool | *true

	// Where the path resolves, when the ambient registry mapping is not the
	// answer. An OCI repository, never a second identity. // OQ6: whether
	// this field is needed at all, and how it composes with 0023's trust
	// policy.
	registry?: string

	// REQUIRED: the lowest release admitted, and the version the platform's
	// own module-less build imports this catalog at (D2, D4). A pin below it
	// is refused, never promoted.
	floor!: #VersionType

	// OPTIONAL: the highest release admitted. Absent admits every release of
	// the major at or above the floor. For a provider catalog's path, a
	// present range replaces the registration's author window (D6).
	ceiling?: #VersionType

	// Structural major check: the path's major equals the major of every
	// version named here.
	_major: regexp.FindSubmatch("@v([0-9]+)$", path)[1]
	_floorMajor: regexp.FindSubmatch("^([0-9]+)\\.", floor)[1]
	_floorMajor: _major
	if ceiling != _|_ {
		_ceilingMajor: regexp.FindSubmatch("^([0-9]+)\\.", ceiling)[1]
		_ceilingMajor: _major
	}
}

// ─── NEW: #PlatformSpec ─────────────────────────────────────────────────────

// The authored platform. Pure data: no imports, no cue.mod dependencies of
// its own, so it is a Platform CR's spec and an offline CLI file with the
// same fields (D3). The render-time #Platform is generated from this value
// plus the module's committed pins and the accepted registrations.
#PlatformSpec: {
	kind: "PlatformSpec"

	metadata: {
		name!:        #NameType
		description?: string
	}

	// Informational discriminator, carried as on #Platform.
	type!: string

	// Path-keyed: the key is the lineage's module path and is bound into the
	// entry's `path`, so key-versus-field drift is a conflict naming the
	// entry. Exactly one entry per path.
	catalogs: [Path=#ModulePathType]: #Subscription & {path: Path}

	// OQ2: whether a floor or pin for `core` belongs here beside the
	// catalog entries.
}
