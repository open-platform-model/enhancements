package instance

import (
	core "opmodel.dev/core@v2"
	opmModule "opmodel.dev/modules/cert_manager@v2"
)

core.#ModuleInstance

metadata: {
	name:      "cert-manager"
	namespace: "cert-manager"
}

#module: opmModule
