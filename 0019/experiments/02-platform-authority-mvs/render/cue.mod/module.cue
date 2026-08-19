// The RENDER module. Stands in for what the kernel would generate per render:
// a main module, never published, whose job is to bring the instance, the
// consumer module and the platform into ONE build.
//
// THIS FILE IS THE EXPERIMENT'S VARIABLE. cue/load resolves an import by first
// consulting the main module's own dependency list (modpkgload/import.go:96,
// RootSelected), falling back to the full module graph and its
// maximum-version selection only for paths this file does not list
// (import.go:98, mg.Selected). So whether the kernel writes the catalog pin
// here decides whether the platform or a consumer module wins. run.sh builds
// both variants.
//
// The consumer and platform entries carry a placeholder version because
// neither is published; they exist only to be directory-replaced by
// cue.mod/local-module.cue, which run.sh generates with `cue mod edit
// --replace`. `replaceWith` is refused in a published module
// (mod/modfile/schema.cue #Strict) and refused in module.cue itself
// (cue/load/config.go:573). It belongs in local-module.cue, which is precisely
// what makes it a legitimate kernel-owned, build-local override.

module: "experiments.opmodel.dev/0019/authority/render@v0"
language: {
	version: "v0.17.0"
}
deps: {
	// Listed because a DEFAULT MAJOR is only honoured for a path that is a
	// root dependency of the main module. The catalog imports
	// "cue.dev/x/k8s.io/..." with no major suffix and marks the default in its
	// OWN cue.mod, which is consulted only while the catalog is itself a root.
	// Drop the catalog from the roots (the `unpinned` mode) and this entry is
	// what keeps the k8s import resolvable, so the mode isolates the version
	// question instead of failing for an unrelated reason.
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
	"experiments.opmodel.dev/0019/authority/consumer@v0": {
		// Placeholder. Inert: the module is directory-replaced, so Fetch
		// never consults a registry (modpkgload/replace.go:88). `v: null` is
		// what the schema documents for a replace-only entry, but v0.17.1
		// fails to decode it ("cannot use value null (type null) as string").
		v: "v0.0.1"
	}
	"experiments.opmodel.dev/0019/authority/platform@v0": {
		v: "v0.0.1"
	}
}
