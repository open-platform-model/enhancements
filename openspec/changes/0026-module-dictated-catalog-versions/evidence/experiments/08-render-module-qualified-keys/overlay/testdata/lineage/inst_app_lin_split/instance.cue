package instance

import (
	c "opmodel.dev/core@v2"
	m "testing.opmodel.dev/library-render/app_lin_split@v0"
)

c.#ModuleInstance
metadata: {name: "probe-split", namespace: "default"}
#module: m
values: {}
