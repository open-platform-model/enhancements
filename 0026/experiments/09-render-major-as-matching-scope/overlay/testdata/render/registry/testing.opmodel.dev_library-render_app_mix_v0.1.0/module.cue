package app_mix

import (
	c "opmodel.dev/core@v2"
	cat0 "testing.opmodel.dev/library-render/maj"
	cat1 "testing.opmodel.dev/library-render/maj@v1"
)

c.#Module
metadata: {name: "app_mix", modulePath: "testing.opmodel.dev/library-render/app_mix@v0", version: "0.1.0", description: "probe"}
#config: {}
#components: {
	old: {
		#resources: (cat0.#ContainerResource.metadata.fqn): cat0.#ContainerResource
		#traits: (cat0.#ExposeTrait.metadata.fqn):          cat0.#ExposeTrait
		spec: {container: image: "nginx:0", expose: port: 80}
	}
	new: {
		#resources: (cat1.#ContainerResource.metadata.fqn): cat1.#ContainerResource
		#traits: (cat1.#ExposeTrait.metadata.fqn):          cat1.#ExposeTrait
		spec: {container: image: "nginx:1", expose: port: 80}
	}
}
