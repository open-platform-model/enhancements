package core

// Two majors of one catalog, opm@v4 at 4.2.0 and opm@v5 at 5.0.0, built
// from the same member source. Contract keys carry no catalog major (0010
// D4), so both majors declare the same container and backup keys; only the
// stamped metadata.catalogVersion and the registry key differ.
#probeMember: {
	#cv: string
	#mp: string
	container: #Resource & {
		metadata: {
			name:       "container"
			apiVersion: "v1beta1"
			fqn:        "opmodel.dev/catalogs/opm/resources/container@v1beta1"
		}
		matchLabels: "opm.opmodel.dev/workload-type": "stateless"
		spec: container: image: string
	}
	backup: #Trait & {
		metadata: {
			name:       "backup"
			apiVersion: "v1alpha1"
			fqn:        "opmodel.dev/catalogs/opm/traits/backup@v1alpha1"
		}
		appliesTo: [container]
		fulfilment: "provider"
		spec: backup: schedule: string
	}
	deployment: #ComponentTransformer & {
		metadata: {
			name:        "deployment-transformer"
			fqn:         "opmodel.dev/catalogs/opm/transformers/deployment-transformer@\(#cv)"
			description: "probe"
		}
		requiredLabels: "opm.opmodel.dev/workload-type": "stateless"
		requiredResources: (container.metadata.fqn): container
		#transform: output: {}
	}
	catalog: #Catalog & {
		metadata: {
			modulePath: #mp
			version:    #cv
		}
		#resources: (container.metadata.fqn): container
		#traits: (backup.metadata.fqn):       backup
		#transformers: (deployment.metadata.fqn): deployment
	}
}

_v4: #probeMember & {#cv: "4.2.0", #mp: "opmodel.dev/catalogs/opm@v4"}
_v5: #probeMember & {#cv: "5.0.0", #mp: "opmodel.dev/catalogs/opm@v5"}
