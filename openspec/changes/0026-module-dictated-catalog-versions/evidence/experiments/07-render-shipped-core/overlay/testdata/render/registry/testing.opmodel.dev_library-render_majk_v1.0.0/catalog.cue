package majk

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/library-render/majk/identity"
)

c.#Catalog

metadata: {
	modulePath:  "testing.opmodel.dev/library-render/majk@v1"
	version:     "1.0.0"
	description: "two-majors probe catalog"
}

_version: id.Version
_res:     "testing.opmodel.dev/library-render/majk/v1/resources"
_resmp:   "testing.opmodel.dev/library-render/majk/resources"
_traits:  "testing.opmodel.dev/library-render/majk/v1/traits"
_trmp:    "testing.opmodel.dev/library-render/majk/traits"
_tx:      "testing.opmodel.dev/library-render/majk/transformers"

#ContainerResource: c.#Resource & {
	metadata: {
		name: "container", modulePath: "\(_resmp)/v1", apiVersion: "v1", catalogVersion: _version
		fqn: "\(_res)/container@v1", description: "container"
	}
	matchLabels: "render.test/workload": "stateless"
	spec: container: {image!: string, port: int | *8080}
}
#ExposeTrait: c.#Trait & {
	metadata: {
		name: "expose", modulePath: "\(_trmp)/v1", apiVersion: "v1", catalogVersion: _version
		fqn: "\(_traits)/expose@v1", description: "expose"
	}
	optional: bool | *true
	spec: expose: port: int | *80
	appliesTo: [#ContainerResource]
}
#BackupTrait: c.#Trait & {
	metadata: {
		name: "backup", modulePath: "\(_trmp)/v1", apiVersion: "v1", catalogVersion: _version
		fqn: "\(_traits)/backup@v1", description: "provider-fulfilled backup"
	}
	optional:   bool | *false
	fulfilment: "provider"
	spec: backup: schedule?: string
	appliesTo: [#ContainerResource]
}

#ContainerV2Resource: c.#Resource & {
	metadata: {
		name: "container", modulePath: "\(_resmp)/v2", apiVersion: "v2", catalogVersion: _version
		fqn: "\(_res)/container@v2", description: "container, next contract level"
	}
	matchLabels: "render.test/workload": "stateless"
	spec: container: {image!: string, port: int | *8080, probe?: string}
}

#resources: {
	(#ContainerResource.metadata.fqn): #ContainerResource
	(#ContainerV2Resource.metadata.fqn): #ContainerV2Resource
}
#traits: {
	(#ExposeTrait.metadata.fqn): #ExposeTrait
	(#BackupTrait.metadata.fqn): #BackupTrait
}

#transformers: {
	"\(_tx)/deployment-transformer@\(_version)": {
		metadata: {name: "deployment-transformer", fqn: "\(_tx)/deployment-transformer@\(_version)", description: "deployment"}
		requiredLabels: "render.test/workload": "stateless"
		requiredResources: (#ContainerResource.metadata.fqn): #ContainerResource
		optionalTraits: (#ExposeTrait.metadata.fqn):          #ExposeTrait
		#transform: {#component: _, output: {apiVersion: "apps/v1", kind: "Deployment", metadata: name: #component.#names.resourceName, metadata: annotations: "built-by": "\(_version)"}}
	}
	"\(_tx)/service-transformer@\(_version)": {
		metadata: {name: "service-transformer", fqn: "\(_tx)/service-transformer@\(_version)", description: "service"}
		requiredResources: (#ContainerResource.metadata.fqn): #ContainerResource
		requiredTraits: (#ExposeTrait.metadata.fqn):          #ExposeTrait
		#transform: {#component: _, output: {apiVersion: "v1", kind: "Service", metadata: name: #component.#names.resourceName, metadata: annotations: "built-by": "\(_version)"}}
	}

	"\(_tx)/deployment-v2-transformer@\(_version)": {
		metadata: {name: "deployment-v2-transformer", fqn: "\(_tx)/deployment-v2-transformer@\(_version)", description: "v2 deployment"}
		requiredLabels: "render.test/workload": "stateless"
		requiredResources: (#ContainerV2Resource.metadata.fqn): #ContainerV2Resource
		#transform: {#component: _, output: {apiVersion: "apps/v1", kind: "Deployment", metadata: name: #component.#names.resourceName, metadata: annotations: "built-by": "\(_version)"}}
	}
}
