// Target schema for enhancement 0004 — Automated CUE Dependency Updates via Dagger.
//
// This is not an OPM runtime schema. It models the CI contract for a
// path-driven Dagger function that walks a directory for CUE modules and bumps
// their dependencies. The function is the single compute layer, invoked
// identically in local use (`dagger call update --source=.`) and in CI (a
// scheduled workflow). Authoring the CI wiring in CUE and exporting it to YAML
// keeps the one piece of real config — registry auth — under `cue vet`, the
// same CUE-as-source-of-truth pattern the superseded Renovate design used for
// its preset (now pointed at the workflow instead).
//
// As decisions land in ../03-decisions.md, tighten the fields marked with
// `// OQN:` comments.
package schema

// #UpdateFn is the Dagger function signature every consumer depends on. It is
// path-driven: point `source` at a directory, the function walks it for
// cue.mod/module.cue (and the CLI's module.cue.tmpl templates), and for each
// runs `cue mod get <dep>@v<major>` + `cue mod tidy`, returning the mutated
// tree plus an old→new summary. Because the major is carried in each deps key
// (@vN), `cue mod get` never crosses a major — the pin is enforced by CUE
// itself, not by extra config (D8). And because `cue` reads CUE_REGISTRY
// directly, there is no route table to mirror (D7 — eliminates OQ1) and no
// version-rewrite regex (D7 — eliminates OQ2).
#UpdateFn: {
	// Module ref: a subpath in the org daggerverse monorepo, independently
	// versioned via subpath-prefixed tags (cue-deps/vX.Y.Z) per the daggerverse
	// convention (D12). E.g. "github.com/open-platform-model/daggerverse/cue-deps".
	module!: string
	name:    "update"
	params: {
		source!:      string // directory to walk; "." both locally and in CI
		cueRegistry!: string // CUE_REGISTRY value, consumed by `cue` natively
		ghcrToken!:   string // secret ref: read:packages on ghcr.io for internal modules
	}
	returns: "Directory"
}

// #RegistryAuth records which backing OCI registry needs credentials for `cue`
// to resolve a module population. This is the ONLY registry config the design
// still carries — and unlike the superseded route table it does NOT duplicate
// CUE_REGISTRY's host→registry mapping (`cue` reads that itself); it only names
// auth needs.
#RegistryAuth: {
	registry!:  string
	needsAuth!: bool
	scope?:     string
}

// Derived from the workspace registry configuration: internal opmodel.dev/*
// modules live on ghcr.io (private, token-gated); external cue.dev/* modules
// resolve through the public registry.cue.works.
#auth: [...#RegistryAuth] & [
	{registry: "ghcr.io", needsAuth: true, scope: "read:packages"},
	{registry: "registry.cue.works", needsAuth: false},
]

// #PRConfig — one grouped PR per repo per run on a fixed branch, refreshed
// daily; the fixed branch makes create-pull-request update the open PR in place
// rather than stacking new ones (D10 — resolves OQ3 + OQ6).
#PRConfig: {
	branch:   "chore/cue-deps"
	grouped:  true
	schedule: "daily"
}

// The exported contract (D12). The Dagger module lives in the org daggerverse
// monorepo; the reusable workflow_call lives in the org .github repo. Each
// consumer repo commits a ~10-line caller that triggers on schedule and `uses:`
// the reusable workflow, which in turn invokes the module.
config: {
	fn: #UpdateFn & {
		module: "github.com/open-platform-model/daggerverse/cue-deps"
		params: {
			source:      "."
			cueRegistry: "$CUE_REGISTRY"
			ghcrToken:   "secrets.GITHUB_TOKEN"
		}
	}
	// Reusable workflow_call each consumer repo's caller points at.
	reusableWorkflow: "open-platform-model/.github/.github/workflows/cue-deps.yml"
	auth:             #auth
	pr:               #PRConfig
}
