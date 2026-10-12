package instance

import (
	c "opmodel.dev/core@v2"
	m "testing.opmodel.dev/library-render/app_mix@v0"
)

c.#ModuleInstance
metadata: {name: "probe-mix", namespace: "default"}
#module: m
values: {}
