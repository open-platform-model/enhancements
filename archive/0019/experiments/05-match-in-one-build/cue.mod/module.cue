// Pinned to the exact published builds experiments 01 and 02 used, and the
// same catalog build library/modules/opm_platform subscribes (2.0.0-alpha.3),
// so the CUE-side pairs are compared against kernel output produced from the
// same bytes. Both are immutable registry artifacts.
module: "experiments.opmodel.dev/0019/match-in-one-build@v0"
language: {
	version: "v0.17.0"
}
deps: {
	"opmodel.dev/core@v2": {
		v: "v2.0.0-alpha.4"
	}
	"opmodel.dev/catalogs/opm@v2": {
		v: "v2.0.0-alpha.3"
	}
}
