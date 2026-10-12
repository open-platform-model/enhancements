package core

// Scoped matching: contract keys stay shared across opm@v4 and opm@v5; the
// scope is the primitive's derived metadata.catalog (resource.cue, trait.cue
// and blueprint.cue patched), and #contracts is keyed by (key, scope)
// (platform.cue patched).

#sMember: {
	#cv: string
	container: #Resource & {
		metadata: {
			name:           "container"
			modulePath:     "opmodel.dev/catalogs/opm/resources/v1beta1"
			apiVersion:     "v1beta1"
			catalogVersion: #cv
			fqn:            "opmodel.dev/catalogs/opm/resources/container@v1beta1"
		}
		matchLabels: "opm.opmodel.dev/workload-type": "stateless"
		spec: container: image: string
	}
	backup: #Trait & {
		metadata: {
			name:           "backup"
			modulePath:     "opmodel.dev/catalogs/opm/traits/v1alpha1"
			apiVersion:     "v1alpha1"
			catalogVersion: #cv
			fqn:            "opmodel.dev/catalogs/opm/traits/backup@v1alpha1"
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
		requiredResources: (container.metadata.fqn):     container
		#transform: output: {}
	}
	#extraTransformers: {...}
	catalog: #Catalog & {
		metadata: {
			modulePath: string
			version:    #cv
		}
		#resources: (container.metadata.fqn): container
		#traits: (backup.metadata.fqn):       backup
		#transformers: {
			(deployment.metadata.fqn): deployment
			#extraTransformers
		}
	}
}

_v4: #sMember & {#cv: "4.2.0", catalog: metadata: modulePath: "opmodel.dev/catalogs/opm@v4"}
_v5: #sMember & {#cv: "5.0.0", catalog: metadata: modulePath: "opmodel.dev/catalogs/opm@v5"}

// derived scope values
scopeV4: _v4.container.metadata.catalog
scopeV5: _v5.backup.metadata.catalog
scopeDev: (#sMember & {#cv: "5.0.0-dev.3"}).container.metadata.catalog

#provider: {
	#path: string
	#ver:  string
	#against: [...#Trait]
	_tx: {
		for i, t in #against {
			"opmodel.dev/catalogs/k8up/transformers/schedule-\(i)@\(#ver)": #ComponentTransformer & {
				metadata: {name: "schedule-\(i)", fqn: "opmodel.dev/catalogs/k8up/transformers/schedule-\(i)@\(#ver)", description: "probe"}
				requiredTraits: (t.metadata.fqn): t
				#transform: output: {}
			}
		}
	}
	catalog: #Catalog & {
		metadata: {modulePath: #path, version: #ver}
		#transformers: _tx
	}
}
