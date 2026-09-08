// Concrete example instances for the target.cue delta — the test.
//
// Unification against concrete values is what validates the delta; a
// definitions-only file passes `cue vet ./...` no matter what it says.
// Must-fail cases are commented out with the error observed, so a reviewer
// can re-run them by hand.
package schema

// A platform admitting two static lineages and bounding one provider
// lineage. The provider entry is optional (D6); it is present here to
// exercise the override shape.
exSpec: #PlatformSpec & {
	metadata: name: "cluster"
	type: "kubernetes"
	catalogs: {
		"opmodel.dev/catalogs/opm@v4": {
			floor:   "4.0.0"
			ceiling: "4.6.0"
		}
		"opmodel.dev/catalogs/k8s@v1": floor: "1.0.0-alpha.2" // no ceiling: any v1 release at or above
		"opmodel.dev/catalogs/k8up@v1": {
			floor:   "1.4.0"
			ceiling: "1.9.0" // wider than the provider's declared 1.8.0: accepted with a warning (D6)
		}
	}
}

// The key binds into the entry's path.
_assertPathBound: exSpec.catalogs["opmodel.dev/catalogs/opm@v4"].path & "opmodel.dev/catalogs/opm@v4"

// Enable defaults on.
_assertEnableDefault: exSpec.catalogs["opmodel.dev/catalogs/k8s@v1"].enable & true

// A disabled lineage stays in the spec but admits nothing.
exDisabled: #Subscription & {
	path:   "opmodel.dev/catalogs/experimental@v0"
	enable: false
	floor:  "0.3.0"
}

// A registry override, an OCI repository beside the path identity (OQ6).
exRegistryOverride: #Subscription & {
	path:     "opmodel.dev/catalogs/opm@v4"
	registry: "ghcr.io/open-platform-model/catalogs/opm"
	floor:    "4.2.0"
}

// Must-fail: floor is required (D2).
//
// exNoFloor: #Subscription & {path: "opmodel.dev/catalogs/opm@v4"}
// -> exNoFloor.floor: field is required but not present

// Must-fail: a version on a different major than the path.
//
// exMajorMismatch: #Subscription & {path: "opmodel.dev/catalogs/opm@v4", floor: "3.9.0"}
// -> exMajorMismatch._floorMajor: conflicting values "4" and "3"

// Must-fail: a ceiling on a different major than the path.
//
// exCeilingMajor: #Subscription & {path: "opmodel.dev/catalogs/opm@v4", floor: "4.0.0", ceiling: "5.0.0"}
// -> exCeilingMajor._ceilingMajor: conflicting values "4" and "5"

// Must-fail: key and path disagree.
//
// exKeyDrift: #PlatformSpec & {metadata: name: "x", type: "kubernetes", catalogs: "opmodel.dev/catalogs/opm@v4": {path: "opmodel.dev/catalogs/k8s@v1", floor: "1.0.0"}}
// -> conflicting values "opmodel.dev/catalogs/opm@v4" and "opmodel.dev/catalogs/k8s@v1"
