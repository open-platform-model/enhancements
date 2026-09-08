// The MODULES module: it carries every fixture module package, plus the
// generated per-point #ModuleInstance packages under ./i/.
//
// One CUE module rather than four is deliberate. The four fixture variants
// (fleet/complex x blueprint/raw) must resolve the SAME core and catalog
// builds, or a cost difference between them would be attributable to what
// each resolved rather than to what each contains. Naming the versions once,
// here, makes that structural instead of a convention.
module: "experiments.opmodel.dev/0019/concurrent-render-at-scale/mods@v0"
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
