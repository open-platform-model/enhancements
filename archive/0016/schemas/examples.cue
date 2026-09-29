// Concrete example instances for the target.cue delta — the test.
//
// Two module shapes exercise #ModuleInitSurface: a module whose author has
// adopted the new initValues field, and a pre-existing module that only
// carries debugValues (the published fleet today). Hidden _assert* fields
// pin the values so a change in the delta's behaviour breaks `cue vet`.
package schema

// A module whose author curates a dedicated init template. debugValues
// keeps its debug-only content (throwaway hostname, debug log level);
// initValues carries what a fresh deployment should actually start from.
exampleWithInitValues: #ModuleInitSurface & {
	#config: {
		image:    string
		replicas: int & >=1 | *1
		logLevel: "debug" | "info" | "warn" | *"info"
	}
	debugValues: {
		image:    "quay.io/jetstack/cert-manager-controller:latest"
		replicas: 3
		logLevel: "debug"
	}
	initValues: {
		image:    "quay.io/jetstack/cert-manager-controller:v1.21.0"
		replicas: 1
		logLevel: "info"
	}
}

// initValues is *intended* to satisfy #config; the schema does not assert
// it (D4). For this example the intent is checked explicitly: the
// unification below fails `cue vet` if the example's initValues ever stop
// conforming to its #config.
_assertInitValuesConform: exampleWithInitValues.#config & exampleWithInitValues.initValues

// Pin the author-curated content — init renders initValues, never
// debugValues, when the field is present (D3).
_assertInitImage:    exampleWithInitValues.initValues.image & "quay.io/jetstack/cert-manager-controller:v1.21.0"
_assertInitReplicas: exampleWithInitValues.initValues.replicas & 1
_assertInitLogLevel: exampleWithInitValues.initValues.logLevel & "info"

// A module published before this enhancement: no initValues field at all.
// The delta is additive — the module remains valid unchanged, and its
// debugValues keeps its existing testing/debugging contract (it becomes
// the documented fallback template source for init, D2).
exampleLegacyModule: #ModuleInitSurface & {
	#config: {
		image: string
		securePort: int & >0 & <65536 | *10250
	}
	debugValues: {
		image: "quay.io/jetstack/cert-manager-controller:latest"
		securePort: 10250
	}
}

// Pin the fallback source's content — this is what D2 scaffolds from.
_assertLegacyDebugImage: exampleLegacyModule.debugValues.image & "quay.io/jetstack/cert-manager-controller:latest"
_assertLegacyDebugPort:  exampleLegacyModule.debugValues.securePort & 10250
