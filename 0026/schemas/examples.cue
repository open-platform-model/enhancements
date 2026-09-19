// Concrete example instances for the target.cue delta — the test.
//
// Unification against concrete values is what validates the delta; a
// definitions-only file passes `cue vet ./...` no matter what it says.
// Must-fail cases are commented out with the error observed, so a reviewer
// can re-run them by hand.
package schema

// The authored platform: two static lineages, one bounded provider lineage
// (its entry is optional, D6, present here to exercise the override), one
// lineage that admits prereleases, and one kept on record but disabled.
exPlatform: #Platform & {
	metadata: name: "cluster"
	type: "kubernetes"
	catalogs: {
		"opmodel.dev/catalogs/opm@v4": {
			floor:   "4.0.0"
			ceiling: "4.6.0" // validated up to here
		}
		"opmodel.dev/catalogs/k8s@v1": floor: "1.0.0" // open ceiling: any GA v1 release at or above
		"opmodel.dev/catalogs/k8up@v1": {
			floor:   "1.4.0"
			ceiling: "1.9.0" // wider than the provider's declared 1.8.0: accepted with a warning (D6)
		}
		"opmodel.dev/catalogs/experimental@v0": {
			floor:       "0.3.0"
			prereleases: true // -dev and -rc tags inside the range render
		}
		"opmodel.dev/catalogs/legacy@v3": {
			enable: false // kept on record, admits nothing
			floor:  "3.9.0"
		}
	}
}

// The key binds into the entry's path.
_assertPathBound: exPlatform.catalogs["opmodel.dev/catalogs/opm@v4"].path & "opmodel.dev/catalogs/opm@v4"

// Enable defaults on.
_assertEnableDefault: exPlatform.catalogs["opmodel.dev/catalogs/k8s@v1"].enable & true

// Prereleases default off: GA releases only.
_assertPrereleasesDefault: exPlatform.catalogs["opmodel.dev/catalogs/opm@v4"].prereleases & false

// A registry override, an OCI repository beside the path identity (OQ6).
exRegistryOverride: #CatalogAdmission & {
	path:     "opmodel.dev/catalogs/opm@v4"
	registry: "ghcr.io/open-platform-model/catalogs/opm"
	floor:    "4.2.0"
}

// A prerelease bound is admissible once prereleases are on.
exPrereleaseCeiling: #CatalogAdmission & {
	path:        "opmodel.dev/catalogs/opm@v4"
	prereleases: true
	floor:       "4.0.0"
	ceiling:     "4.7.0-rc.1"
}

// The resolved platform the kernel generates for a render of a module that
// pins opm at 4.3.0 on the platform above, with an accepted k8up
// registration at 1.6.0. k8s@v1 is admitted but absent: the module never
// imported it and no registration supplied it (D4). Nobody authors this
// value; it is shown to fix what the generated form carries.
exResolved: #ResolvedPlatform & {
	metadata: name: "cluster"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": version:  "4.3.0" // the module's pin (D1)
		"opmodel.dev/catalogs/k8up@v1": version: "1.6.0" // the registration's version (D5)
	}
}

// Must-fail: floor is required (D2).
//
// exNoFloor: #CatalogAdmission & {path: "opmodel.dev/catalogs/opm@v4"}
// -> (cue vet -c) exNoFloor.floor: incomplete value =~"^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$" & =~"^[0-9]+\\.[0-9]+\\.[0-9]+$"

// Must-fail: a version on a different major than the path.
//
// exMajorMismatch: #CatalogAdmission & {path: "opmodel.dev/catalogs/opm@v4", floor: "3.9.0"}
// -> exMajorMismatch._floorMajor: conflicting values "4" and "3"

// Must-fail: a ceiling on a different major than the path.
//
// exCeilingMajor: #CatalogAdmission & {path: "opmodel.dev/catalogs/opm@v4", floor: "4.0.0", ceiling: "5.0.0"}
// -> exCeilingMajor._ceilingMajor: conflicting values "4" and "5"

// Must-fail: a prerelease bound with prereleases off (the default).
//
// exPrereleaseFloorOff: #CatalogAdmission & {path: "opmodel.dev/catalogs/k8s@v1", floor: "1.0.0-alpha.2"}
// -> exPrereleaseFloorOff.floor: invalid value "1.0.0-alpha.2" (out of bound =~"^[0-9]+\\.[0-9]+\\.[0-9]+$")

// Must-fail: key and path disagree.
//
// exKeyDrift: #Platform & {metadata: name: "x", type: "kubernetes", catalogs: "opmodel.dev/catalogs/opm@v4": {path: "opmodel.dev/catalogs/k8s@v1", floor: "1.0.0"}}
// -> conflicting values "opmodel.dev/catalogs/opm@v4" and "opmodel.dev/catalogs/k8s@v1"
