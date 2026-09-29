module: "opmodel.dev/catalogs/opm@v4"
language: {
	version: "v0.17.0"
}
source: {
	kind: "self"
}
deps: {
	"cue.dev/x/k8s.io@v0": {
		v:       "v0.10.0"
		default: true
	}
	"opmodel.dev/core@v2": {
		v: "v2.0.0-alpha.6"
	}
}
