// instance — a hand-authored #ModuleInstance package, the file-door artifact
// the CLI loads from disk. Values live in the sibling values.cue, exactly the
// split LoadInstancePackage documents (instance.cue + values.cue in one
// package) — so the deployer's statement is baked into the loaded package,
// which is the hard case OQ2 names.
package instance

import (
	core "opmodel.dev/core@v2"
	md "testing.opmodel.dev/exp0013/secretmod"
)

core.#ModuleInstance

metadata: {
	name:      "myapp"
	namespace: "prod"
}

#module: md
