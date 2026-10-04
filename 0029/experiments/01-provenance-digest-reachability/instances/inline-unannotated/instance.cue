package instance

import (
	core "opmodel.dev/core@v2"
	opmModule "instance.local/hello-iv/hello"
)

core.#ModuleInstance

metadata: {
	name:      "hello-iv"
	namespace: "default"
}

#module: opmModule
