package lin

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/library-render/lin/identity"
)

c.#Catalog

metadata: {modulePath: "testing.opmodel.dev/library-render/lin@v1", version: id.Version, description: "lineage probe catalog"}

_v:  id.Version
_kb: "testing.opmodel.dev/library-render/lin@v1"
_tx: "testing.opmodel.dev/library-render/lin/transformers"

#ContainerResource: c.#Resource & {
	metadata: {name: "container", apiVersion: "v1", fqn: "\(_kb)/resources/container@v1", description: "container"}
	matchLabels: "render.test/workload": "stateless"
	spec: container: {image!: string, port: int | *8080}
}
#ExposeTrait: c.#Trait & {
	metadata: {name: "expose", apiVersion: "v1", fqn: "\(_kb)/traits/expose@v1", description: "expose"}
	optional: bool | *true
	spec: expose: port: int | *80
	appliesTo: [#ContainerResource]
}
#BackupTrait: c.#Trait & {
	metadata: {name: "backup", apiVersion: "v1", fqn: "\(_kb)/traits/backup@v1", description: "provider-fulfilled backup"}
	optional:   bool | *false
	fulfilment: "provider"
	spec: backup: schedule?: string
	appliesTo: [#ContainerResource]
}
#resources: (#ContainerResource.metadata.fqn): #ContainerResource
#traits: {
	(#ExposeTrait.metadata.fqn): #ExposeTrait
	(#BackupTrait.metadata.fqn): #BackupTrait
}
#transformers: {
	"\(_tx)/deployment-transformer@\(_v)": {
		metadata: {name: "deployment-transformer", fqn: "\(_tx)/deployment-transformer@\(_v)", description: "deployment"}
		requiredLabels: "render.test/workload": "stateless"
		requiredResources: (#ContainerResource.metadata.fqn): #ContainerResource
		optionalTraits: (#ExposeTrait.metadata.fqn):          #ExposeTrait
		#transform: {#component: _, output: {apiVersion: "apps/v1", kind: "Deployment", metadata: name: #component.#names.resourceName, metadata: annotations: "built-by": "lin-\(_v)"}}
	}
	"\(_tx)/service-transformer@\(_v)": {
		metadata: {name: "service-transformer", fqn: "\(_tx)/service-transformer@\(_v)", description: "service"}
		requiredResources: (#ContainerResource.metadata.fqn): #ContainerResource
		requiredTraits: (#ExposeTrait.metadata.fqn):          #ExposeTrait
		#transform: {#component: _, output: {apiVersion: "v1", kind: "Service", metadata: name: #component.#names.resourceName, metadata: annotations: "built-by": "lin-\(_v)"}}
	}
}
