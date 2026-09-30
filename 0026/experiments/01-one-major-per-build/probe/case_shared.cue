@if(shared)

package core

// Case A: both majors enabled in one build. Evaluated only with -t shared,
// so the other cases stay readable without its errors.
twoMajorsShared: #Platform & {
	metadata: name: "two-majors-shared-keys"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
	}
}
