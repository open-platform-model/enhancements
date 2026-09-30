package app_majk1

import (
	c "opmodel.dev/core@v2"
	cat "testing.opmodel.dev/library-render/majk@v1"
)

c.#Module
metadata: {name: "app_majk1", modulePath: "testing.opmodel.dev/library-render/app_majk1@v0", version: "0.1.0", description: "probe"}
#config: {}
#components: {
	web: {
		#resources: (cat.#ContainerResource.metadata.fqn): cat.#ContainerResource
		#traits: (cat.#ExposeTrait.metadata.fqn):          cat.#ExposeTrait
		spec: {container: image: "nginx:1", expose: port: 80}
	}
	web2: {
		#resources: (cat.#ContainerV2Resource.metadata.fqn): cat.#ContainerV2Resource
		spec: container: image: "nginx:2"
	}
}
