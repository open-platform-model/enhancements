package instance

import (
	c "opmodel.dev/core@v2"
	m "testing.opmodel.dev/library-render/app_lin1@v0"
)

c.#ModuleInstance
metadata: {name: "probe-lin1", namespace: "default"}
#module: m
values: {}
