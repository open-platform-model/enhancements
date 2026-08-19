// The platform module's own resolution (D5): the catalog build it runs is
// named here, in cue.mod, and nowhere else.
//
// Held constant across every arm. This experiment varies the INSTANCE and the
// reuse strategy, never the platform, so the catalog term is identical in
// every measurement and any difference between arms is attributable to the
// arm rather than to what was resolved.
module: "experiments.opmodel.dev/0019/concurrent-render-at-scale/platform@v0"
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
