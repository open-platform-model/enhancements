module: "instance.local/opm-operator@v0"
language: {
	version: "v0.17.0"
}
deps: {
	"cue.dev/x/k8s.io@v0": {
		v: "v0.12.0"
	}
	"opmodel.dev/catalogs/opm@v4": {
		v: "v4.5.2"
	}
	"opmodel.dev/core@v2": {
		v: "v2.0.0-beta.2"
	}
	"testing.opmodel.dev/modules/experiments/opm-operator-bootstrap/opm_operator@v0": {
		v: "v0.2.0"
	}
}
