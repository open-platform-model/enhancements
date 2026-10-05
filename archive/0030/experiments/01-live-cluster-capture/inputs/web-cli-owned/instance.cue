package instance

import (
	core "opmodel.dev/core@v2"
	opmModule "opmodel.dev/modules/web_app@v1"
)

core.#ModuleInstance

metadata: {
	name:      "web"
	namespace: "web"
}

#module: opmModule
