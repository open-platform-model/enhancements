package instance

import (
	core "opmodel.dev/core@v2"
	opmModule "testing.opmodel.dev/modules/experiments/opm-operator-bootstrap/opm_operator@v0"
)

core.#ModuleInstance

metadata: {
	name:      "opm-operator"
	namespace: "opm-operator-system"
}

#module: opmModule
