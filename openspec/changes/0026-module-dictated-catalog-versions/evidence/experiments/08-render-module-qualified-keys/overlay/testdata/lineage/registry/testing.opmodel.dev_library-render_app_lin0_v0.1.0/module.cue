package app_lin0

import (
	c "opmodel.dev/core@v2"
	cat "testing.opmodel.dev/library-render/lin@v0"
)

c.#Module
metadata: {name: "app_lin0", modulePath: "testing.opmodel.dev/library-render/app_lin0@v0", version: "0.1.0", description: "probe"}
#config: {}
#components: web: {
	#resources: (cat.#ContainerResource.metadata.fqn): cat.#ContainerResource
	#traits: {
		(cat.#ExposeTrait.metadata.fqn): cat.#ExposeTrait
		(cat.#BackupTrait.metadata.fqn): cat.#BackupTrait
	}
	spec: {container: image: "nginx:1", expose: port: 80, backup: schedule: "@daily"}
}
