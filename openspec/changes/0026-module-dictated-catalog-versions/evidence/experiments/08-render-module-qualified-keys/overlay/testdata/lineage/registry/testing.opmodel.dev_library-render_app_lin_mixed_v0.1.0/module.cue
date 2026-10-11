package app_lin_mixed

import (
	c "opmodel.dev/core@v2"
	l0 "testing.opmodel.dev/library-render/lin@v0"
	l1 "testing.opmodel.dev/library-render/lin@v1"
)

c.#Module
metadata: {name: "app_lin_mixed", modulePath: "testing.opmodel.dev/library-render/app_lin_mixed@v0", version: "0.1.0", description: "probe"}
#config: {}
#components: web: {
	#resources: (l1.#ContainerResource.metadata.fqn): l1.#ContainerResource
	#traits: (l0.#ExposeTrait.metadata.fqn): l0.#ExposeTrait
	spec: {container: image: "nginx:1", expose: port: 80}
}
