// Case (iv): a copy of the hello module living as a plain package INSIDE the
// instance package's own CUE module. No dependency on the published module,
// no cue.mod/local-module.cue, so the CLI's provenance check sees nothing
// local; metadata still claims the published coordinate.
package hello

import (
	m "opmodel.dev/core@v2"
)

m.#Module

metadata: {
	name:        "hello"
	modulePath:  "testing.opmodel.dev/modules/experiments/handoff-src/hello@v0"
	version:     "0.1.0"
	description: "Minimal test module — renders a single ConfigMap"
}

#config: {
	message: string | *"hello from opm"
}

debugValues: {
	message: "hello from opm (debug)"
}
