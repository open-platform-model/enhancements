@if(legacy)

package core

// Two legacy (registry-scope) majors enabled together: the residual case.
// Evaluated only with -t legacy.

// L4: two LEGACY (registry-scope) majors: the residual case.
lineageL4: #Platform & {
	metadata: name: "l4-two-legacy"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v3": #catalog: _opm3r.catalog
		"opmodel.dev/catalogs/opm@v4": #catalog: _opm4r.catalog
	}
}
