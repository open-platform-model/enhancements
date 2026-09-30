package core

// A provider catalog per declaring major. Each imports the backup trait
// from the opm major it was built against, as a published member carries
// it: stamped with that major's catalogVersion (#Catalog's #traits stamp).
_backupKey: "opmodel.dev/catalogs/opm/traits/backup@v1alpha1"

#k8up: {
	#cv:      string
	#mp:      string
	#against: _
	schedule: #ComponentTransformer & {
		metadata: {
			name:        "schedule-transformer"
			fqn:         "opmodel.dev/catalogs/k8up/transformers/schedule-transformer@\(#cv)"
			description: "probe"
		}
		requiredTraits: (_backupKey): #against.catalog.#traits[_backupKey]
		#transform: output: {}
	}
	catalog: #Catalog & {
		metadata: {
			modulePath: #mp
			version:    #cv
		}
		#transformers: (schedule.metadata.fqn): schedule
	}
}

_k8upV2: #k8up & {#cv: "2.0.0", #mp: "opmodel.dev/catalogs/k8up@v2", #against: _v4} // built on opm@v4
_k8upV3: #k8up & {#cv: "3.0.0", #mp: "opmodel.dev/catalogs/k8up@v3", #against: _v5} // built on opm@v5

// What a component on each major carries for the trait: the stamped value.
v4ComponentBackup: _v4.catalog.#traits[_backupKey]
v5ComponentBackup: _v5.catalog.#traits[_backupKey]

// Rung 2 of the match (0019 D10) is plain unification of the component's
// value with the transformer's requirement. Same major: unifies.
matchSameMajor: _k8upV2.schedule.requiredTraits[_backupKey] & v4ComponentBackup

// Both providers counted against one platform holding the v4 declaring
// catalog: the count every registry entry contributes to today.
bothProvidersOneBuild: #Platform & {
	metadata: name: "both-providers"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4":  #catalog: _v4.catalog
		"opmodel.dev/catalogs/k8up@v2": #catalog: _k8upV2.catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: _k8upV3.catalog
	}
}

// One resolution per declaring major, each holding only the provider built
// against the major it holds.
resolutionV4: #Platform & {
	metadata: name: "resolution-v4"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4":  #catalog: _v4.catalog
		"opmodel.dev/catalogs/k8up@v2": #catalog: _k8upV2.catalog
	}
}
resolutionV5: #Platform & {
	metadata: name: "resolution-v5"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5":  #catalog: _v5.catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: _k8upV3.catalog
	}
}
