package instance

import (
	core "opmodel.dev/core@v2"
	opmModule "testing.opmodel.dev/modules/experiments/handoff-src/hello@v0"
)

core.#ModuleInstance

metadata: {
	name:      "hello-x3"
	namespace: "default"
}

#module: opmModule
