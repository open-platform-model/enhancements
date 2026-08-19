// The RENDER module: what the kernel would generate per render. Its job is to
// bring the instance and the platform into ONE build.
//
// This file is the resolution (experiment 02): cue/load answers an import from
// the main module's own dependency list first (modpkgload/import.go:93-98,
// RootSelected) and falls back to the module graph's maximum-version selection
// only for paths this list does not carry. Every OPM path is listed here for
// that reason, and the k8s entry is listed because a DEFAULT MAJOR is honoured
// only for a path that is a root dependency of the main module.
//
// The instance and platform entries carry a placeholder version and are inert:
// both are directory-replaced by cue.mod/local-module.cue, which the harness
// generates with `cue mod edit --replace` during setup. That file is the
// COMPLETE main-module dependency view rather than a patch, which is why it is
// generated rather than hand-written.
module: "experiments.opmodel.dev/0019/render-build-cost/render@v0"
language: {
	version: "v0.17.0"
}
deps: {
	"cue.dev/x/k8s.io@v0": {
		v:       "v0.7.0"
		default: true
	}
	"opmodel.dev/core@v2": {
		v: "v2.0.0-alpha.4"
	}
	"opmodel.dev/catalogs/opm@v2": {
		v: "v2.0.0-alpha.3"
	}
	"experiments.opmodel.dev/0019/render-build-cost/instance@v0": {
		v: "v0.0.1"
	}
	"experiments.opmodel.dev/0019/render-build-cost/platform@v0": {
		v: "v0.0.1"
	}
}
