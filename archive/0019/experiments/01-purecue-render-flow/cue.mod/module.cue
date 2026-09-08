// Pinned to the exact published builds the library flow tests use, so this
// experiment evaluates the same bytes the kernel does. Both are immutable
// registry artifacts, not workspace references.
module: "experiments.opmodel.dev/0019/purecue-render-flow@v0"
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
