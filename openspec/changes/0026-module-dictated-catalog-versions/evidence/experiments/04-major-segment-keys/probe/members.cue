package core

// Major-in-key, path-segment spelling: keyPrefix = RegistryPath/<Major>/<kind>
// (identity_package.cue patched). A member set is built from an identity
// package, so keys derive from identity exactly as a catalog leaf authors them.

#mikCat: {
	#id: #IdentityPackage

	// #flat: true reproduces today's (legacy) key shape for an already-published major.
	#flat: *false | true
	let P = [if #flat {#id.kindPrefix}, #id.keyPrefix][0]

	container: #Resource & {
		metadata: {
			name:       "container"
			apiVersion: "v1beta1"
			fqn:        "\(P.resources)/container@v1beta1"
		}
		matchLabels: "opm.opmodel.dev/workload-type": "stateless"
		spec: container: image: string
	}
	backup: #Trait & {
		metadata: {
			name:       "backup"
			apiVersion: "v1alpha1"
			fqn:        "\(P.traits)/backup@v1alpha1"
		}
		appliesTo: [container]
		fulfilment: "provider"
		optional:   bool | *false
		spec: backup: schedule: string
	}
	stateless: #Blueprint & {
		metadata: {
			name:       "stateless-workload"
			apiVersion: "v1beta1"
			fqn:        "\(P.blueprints)/stateless-workload@v1beta1"
		}
		composedResources: [container]
		spec: statelessWorkload: replicas: int
	}
	deployment: #ComponentTransformer & {
		metadata: {
			name:        "deployment-transformer"
			fqn:         "\(P.transformers)/deployment-transformer@\(#id.Version)"
			description: "probe"
		}
		requiredLabels: "opm.opmodel.dev/workload-type": "stateless"
		requiredResources: (container.metadata.fqn):     container
		#transform: output: {}
	}
	catalog: #Catalog & {
		metadata: {
			modulePath: #id.ModulePath
			version:    #id.Version
		}
		#resources: (container.metadata.fqn):     container
		#traits: (backup.metadata.fqn):           backup
		#blueprints: (stateless.metadata.fqn):    stateless
		#transformers: (deployment.metadata.fqn): deployment
	}
}

// A provider catalog: one transformer per definer major it is built against.
#mikProvider: {
	#id: #IdentityPackage
	#against: [...{backup: _, ...}]
	catalog: #Catalog & {
		metadata: {
			modulePath: #id.ModulePath
			version:    #id.Version
		}
		#transformers: {
			for i, d in #against {
				let F = "\(#id.keyPrefix.transformers)/schedule-\(i)@\(#id.Version)"
				(F): #ComponentTransformer & {
					metadata: {
						name:        "schedule-\(i)"
						fqn:         F
						description: "probe"
					}
					requiredTraits: (d.backup.metadata.fqn): d.backup
					#transform: output: {}
				}
			}
		}
	}
}

_id4: #IdentityPackage & {ModulePath: "opmodel.dev/catalogs/opm@v4", Version: "4.4.1"}
_id5: #IdentityPackage & {ModulePath: "opmodel.dev/catalogs/opm@v5", Version: "5.0.0"}
_id5b: #IdentityPackage & {ModulePath: "opmodel.dev/catalogs/opm@v5", Version: "5.3.1"}
_id6: #IdentityPackage & {ModulePath: "opmodel.dev/catalogs/opm@v6", Version: "6.0.0"}

_opm4flat: #mikCat & {#id: _id4, #flat: true} // legacy: v4 stays flat, never republished
_opm5: #mikCat & {#id: _id5}
_opm5b: #mikCat & {#id: _id5b}
_opm6: #mikCat & {#id: _id6}

keys: {
	v4flat_container:   _opm4flat.container.metadata.fqn
	v5_container:       _opm5.container.metadata.fqn
	v5_1_container:     _opm5b.container.metadata.fqn
	v5_modulePath:      _opm5.catalog.#resources[_opm5.container.metadata.fqn].metadata.modulePath
	v5_transformer:     _opm5.deployment.metadata.fqn
	v5_1_transformer:   _opm5b.deployment.metadata.fqn
	key_survives_minor: _opm5.container.metadata.fqn == _opm5b.container.metadata.fqn
	implType:           #ImplFQNType & _opm5.deployment.metadata.fqn
	contractType:       #ContractFQNType & _opm5.backup.metadata.fqn
}
