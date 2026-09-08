// The CONSUMER MODULE's own resolution. This is the file the matrix varies:
// run.sh rewrites the catalogs/opm pin per case in a scratch copy, never here.
//
// Committed at the same version the platform names, so a bare `cue eval` in
// this directory reproduces case A.
module: "experiments.opmodel.dev/0019/authority/consumer@v0"
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
