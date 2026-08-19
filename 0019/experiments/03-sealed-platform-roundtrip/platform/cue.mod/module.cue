// The PLATFORM's own resolution. Under the proposal, this file is what
// "the platform names its catalog build" means: not a `version` string in a
// data field, but a cue.mod pin plus an import. Enhancement 0010 D14's
// property ("catalog selection is a pure function of committed source")
// survives, because cue.mod is committed source.
//
// Held at 2.0.0-alpha.3 in every case of the matrix. It is the constant the
// consumer's pin is varied against.
module: "experiments.opmodel.dev/0019/authority/platform@v0"
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
