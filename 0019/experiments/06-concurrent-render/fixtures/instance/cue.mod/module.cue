// The instance module. Stands in for what synth.Instance stages today: an
// on-disk package carrying one #ModuleInstance, with the module it names
// reachable from the same tree.
//
// N copies of this module are materialized per run, differing only in
// metadata.name, so no two renders in an arm are the same value and CUE
// cannot answer the second one from the first.
module: "experiments.opmodel.dev/0019/render-build-cost/instance@v0"
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
