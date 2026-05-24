// Synthetic #composedTransformers map — three SemVer-keyed variants of the
// same primitive (container), simulating what Materialize would produce
// after pulling three OCI tags into the local cache.
package match

composed: #TransformerMap & {
	"opmodel.dev/modules/opm/container@1.0.4": #ComponentTransformer & {
		metadata: {
			name:        "container"
			modulePath:  "opmodel.dev/modules/opm"
			version:     "1.0.4"
			description: "container @1.0.4"
		}
	}
	"opmodel.dev/modules/opm/container@1.1.0": #ComponentTransformer & {
		metadata: {
			name:        "container"
			modulePath:  "opmodel.dev/modules/opm"
			version:     "1.1.0"
			description: "container @1.1.0"
		}
	}
	"opmodel.dev/modules/opm/container@1.4.0": #ComponentTransformer & {
		metadata: {
			name:        "container"
			modulePath:  "opmodel.dev/modules/opm"
			version:     "1.4.0"
			description: "container @1.4.0"
		}
	}
	"opmodel.dev/modules/opm/expose-trait@1.0.0": #ComponentTransformer & {
		metadata: {
			name:        "expose-trait"
			modulePath:  "opmodel.dev/modules/opm"
			version:     "1.0.0"
			description: "expose @1.0.0"
		}
	}
}
