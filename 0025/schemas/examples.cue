// Concrete example instances for the target.cue delta: the test.
//
// One worked cast: a platform team offers example.com/modules/postgres on
// its v1 line as PostgresDatabase.platform.example.com, binding the storage
// class; team-orders creates one. Hidden assertion fields pin every derived
// value so a behaviour change breaks `cue vet ./...`.
package schema

// ─── Catalog fixtures: three module traits and one module transformer ───────
//
// Catalog content, stood up here as definitions (as a catalog ships them)
// so the delta can be exercised. The first
// two are the rendered instances D15 ships; the third is the declaration
// D5 lets a module make about itself.

#NetworkIsolationTrait: #ModuleTrait & {
	metadata: {
		name:           "network-isolation"
		modulePath:     "opmodel.dev/catalogs/opm/module-traits/v1alpha1"
		apiVersion:     "v1alpha1"
		catalogVersion: "2.3.0"
		fqn:            "opmodel.dev/catalogs/opm/module-traits/network-isolation@v1alpha1"
	}
	matchLabels: "opm.opmodel.dev/network-isolation": "true"
	optional: bool | *false
	spec: networkIsolation: {
		defaultDeny: bool | *true
		allowedCIDRs: [...string]
	}
}

#ResourceBudgetTrait: #ModuleTrait & {
	metadata: {
		name:           "resource-budget"
		modulePath:     "opmodel.dev/catalogs/opm/module-traits/v1alpha1"
		apiVersion:     "v1alpha1"
		catalogVersion: "2.3.0"
		fqn:            "opmodel.dev/catalogs/opm/module-traits/resource-budget@v1alpha1"
	}
	matchLabels: "opm.opmodel.dev/resource-budget": "true"
	optional: bool | *true
	spec: resourceBudget: {
		cpu!:    string
		memory!: string
	}
}

// The offering declaration (D5): what the module says it is when offered.
// The platform still writes the binding; this is its input.
#OfferingTrait: #ModuleTrait & {
	metadata: {
		name:           "offering"
		modulePath:     "opmodel.dev/catalogs/opm/module-traits/v1alpha1"
		apiVersion:     "v1alpha1"
		catalogVersion: "2.3.0"
		fqn:            "opmodel.dev/catalogs/opm/module-traits/offering@v1alpha1"
	}
	optional: bool | *true
	spec: offering: {
		api:          #OfferingAPI
		updatePolicy: #UpdatePolicy
		// OQ5: the module-declared status schema, if any, lives here.
		status?: {...}
	}
}

#NetworkPolicyTransformer: #ModuleTransformer & {
	metadata: {
		modulePath:     "opmodel.dev/catalogs/opm/module-transformers"
		name:           "network-policy"
		catalogVersion: "2.3.0"
		fqn:            "opmodel.dev/catalogs/opm/module-transformers/network-policy@2.3.0"
		description:    "Renders one default-deny NetworkPolicy per network-isolation aspect"
	}
	requiredTraits: (#NetworkIsolationTrait.metadata.fqn): #NetworkIsolationTrait
	producesKinds: ["NetworkPolicy"]

	#transform: {
		#moduleInstance: _
		#aspect:         _

		#context: _ // restated so the references below resolve in this scope
		output: {
			apiVersion: "networking.k8s.io/v1"
			kind:       "NetworkPolicy"
			metadata: {
				name:      #aspect.#names.resourceName
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
			}
			spec: {
				// Every component of the module is selected: whole-module
				// facts come through the instance, never a second input.
				podSelector: matchLabels: "module-instance.opmodel.dev/name": #context.#moduleInstanceMetadata.name
				policyTypes: ["Ingress"]
				if #aspect.spec.networkIsolation.defaultDeny {
					ingress: [{from: [for c in #aspect.spec.networkIsolation.allowedCIDRs {ipBlock: cidr: c}]}]
				}
			}
		}
	}
}

// ─── The offered module: it describes itself through aspects (D11) ──────────

postgresModule: #Module & {
	metadata: {
		name:         "postgres"
		modulePath:   "example.com/modules/postgres@v1"
		version:      "1.4.2"
		registryPath: "example.com/modules/postgres"
	}
	#config: {
		storage!:      string
		replicas:      int & >=1 | *1
		storageClass!: string
		allowedCIDRs: [...string] | *["10.0.0.0/8"]
	}

	#aspects: {
		// Two rendered aspects: the key defaults the name, the spec reads #config.
		isolation: {
			#traits: (#NetworkIsolationTrait.metadata.fqn): #NetworkIsolationTrait
			spec: networkIsolation: allowedCIDRs: #config.allowedCIDRs
		}
		budget: {
			#traits: (#ResourceBudgetTrait.metadata.fqn): #ResourceBudgetTrait & {optional: false}
			spec: resourceBudget: {cpu: "8", memory: "32Gi"}
		}
		// The declaration: what this module is when a platform offers it.
		self: {
			#traits: (#OfferingTrait.metadata.fqn): #OfferingTrait
			spec: offering: {
				api: {group: "platform.example.com", kind: "PostgresDatabase"}
				updatePolicy: "manual"
			}
		}
	}
}

// Aspect identity: name from the key, the label stamp, no self-contributed
// matchLabels key, exactly one key per trait.
_assertAspectName:  postgresModule.#aspects.isolation.metadata.name & "isolation"
_assertAspectLabel: postgresModule.#aspects.budget.metadata.labels["aspect.opmodel.dev/name"] & "budget"
_assertAspectMatch: postgresModule.#aspects.isolation.matchLabels & {"opm.opmodel.dev/network-isolation": "true"}
_assertMatchCount: len(postgresModule.#aspects.budget.matchLabels) & 1
_assertNoMatch:    len(postgresModule.#aspects.self.matchLabels) & 0

// The attachment site narrowed the catalog's posture (D12, the #Trait rule).
_assertNarrowed: postgresModule.#aspects.budget.#traits[#ResourceBudgetTrait.metadata.fqn].optional & false

// ─── The definition (binding + kind layers) ─────────────────────────────────

postgresOffering: #Offering & {
	metadata: name: "postgres-database"
	spec: {
		module: {
			registryPath: "example.com/modules/postgres"
			major:        1
			version:      "1.4.2"
		}
		values: storageClass: "fast-ssd"
		api: {
			group: "platform.example.com"
			kind:  "PostgresDatabase"
		}
	}
}

// OQ3: the default is the placeholder default until decided.
_assertDefaultPolicy: postgresOffering.spec.updatePolicy & "manual"

// A binding-only definition (no api) is legal (D4).
cacheBinding: #Offering & {
	metadata: name: "redis-cache"
	spec: module: {
		registryPath: "example.com/modules/redis"
		major:        2
		version:      "2.0.1"
	}
}

// ─── The served CRD version derives from the major (D7) ─────────────────────

_assertKindVersion1: (#KindVersion & {#major: 1}).out & "v1"
_assertKindVersion2: (#KindVersion & {#major: 2}).out & "v2"

// ─── A consumer's instance of the served kind ───────────────────────────────

ordersDB: #OfferingInstance & {
	#offering: postgresOffering
	metadata: {
		name:      "orders-db"
		namespace: "team-orders"
	}
	spec: {
		storage:  "20Gi"
		replicas: 2
	}
}

_assertAPIVersion: ordersDB.apiVersion & "platform.example.com/v1"
_assertKind:       ordersDB.kind & "PostgresDatabase"

// ─── The projection (D6): definition + instance + module -> #ModuleInstance ──

ordersProjected: #Project & {
	#offering: postgresOffering
	#instance: ordersDB
	#module:   postgresModule
}

_assertProjectedName:      ordersProjected.out.metadata.name & "orders-db"
_assertProjectedNamespace: ordersProjected.out.metadata.namespace & "team-orders"
_assertProjectedKind:      ordersProjected.out.kind & "ModuleInstance"

// Bound value from the definition, consumer value from the instance, default
// from #config: all three reach the rendered values.
_assertBoundValue:    ordersProjected.out.values.storageClass & "fast-ssd"
_assertConsumerValue: ordersProjected.out.values.storage & "20Gi"
_assertConsumerInt:   ordersProjected.out.values.replicas & 2
_assertModuleVersion: ordersProjected.out.#module.metadata.version & "1.4.2"

// A second instance leaves replicas to the #config default.
billingDB: #OfferingInstance & {
	#offering: postgresOffering
	metadata: {
		name:      "billing-db"
		namespace: "team-billing"
	}
	spec: storage: "50Gi"
}

billingProjected: #Project & {
	#offering: postgresOffering
	#instance: billingDB
	#module:   postgresModule
}

_assertDefaultReplicas: billingProjected.out._configCheck.replicas & 1

// ─── Aspects survive the projection and compute their names (D11) ───────────

// The projected instance's module carries the aspects, and the instance
// identity reached them through #ctx: resourceName is instance-qualified.
_assertProjectedAspect:   ordersProjected.out.#module.#aspects.isolation.#names.resourceName & "orders-db-isolation"
_assertProjectedBudget:   billingProjected.out.#module.#aspects.budget.#names.resourceName & "billing-db-budget"
_assertProjectedInstance: ordersProjected.out.#module.#aspects.self.#instance.namespace & "team-orders"

// The offering declaration is readable off the module (D5): what the CLI
// drafts the definition from, and what the reconciler compares against.
_assertDeclaredKind:   postgresModule.#aspects.self.spec.offering.api.kind & "PostgresDatabase"
_assertDeclaredAgrees: postgresModule.#aspects.self.spec.offering.api.kind & postgresOffering.spec.api.kind

// ─── A module transformer renders one aspect (D13) ──────────────────────────

ordersNetworkPolicy: (#NetworkPolicyTransformer.#transform & {
	#moduleInstance: ordersProjected.out
	#aspect:         ordersProjected.out.#module.#aspects.isolation
}).output

_assertNPName:      ordersNetworkPolicy.metadata.name & "orders-db-isolation"
_assertNPNamespace: ordersNetworkPolicy.metadata.namespace & "team-orders"
_assertNPLabel:     ordersNetworkPolicy.metadata.labels["aspect.opmodel.dev/name"] & "isolation"
_assertNPCIDR:      ordersNetworkPolicy.spec.ingress[0].from[0].ipBlock.cidr & "10.0.0.0/8"
_assertNPSelector:  ordersNetworkPolicy.spec.podSelector.matchLabels["module-instance.opmodel.dev/name"] & "orders-db"

// ─── Must-fail cases (recorded, commented out; re-run by hand) ──────────────
//
// 1. A consumer overriding a bound value is a refusal, not an override (D6).
//
//    badOverride: #Project & {
//        #offering: postgresOffering
//        #instance: #OfferingInstance & {
//            #offering: postgresOffering
//            metadata: {name: "x", namespace: "team-x"}
//            spec: {storage: "1Gi", storageClass: "gp2"}
//        }
//        #module: postgresModule
//    }
//    // conflicting values "fast-ssd" and "gp2"
//
// 2. A bound release outside the bound major is refused (D7).
//
//    badMajor: #Offering & {
//        metadata: name: "postgres-database"
//        spec: module: {registryPath: "example.com/modules/postgres", major: 1, version: "2.0.0"}
//    }
//    // spec.module._agrees: conflicting values true and false
//
// 3. A served-kind instance for a binding-only definition is refused (D4):
//    #OfferingInstance requires spec.api on its definition.
//
//    badInstance: #OfferingInstance & {
//        #offering: cacheBinding
//        metadata: {name: "x", namespace: "team-x"}
//        spec: {}
//    }
//    // #offering.spec.api: field is required but not present
//
// 4. A module whose #config is not structural (a comprehension, an open `_`)
//    is refused at definition acceptance (D2). Not expressible as a CUE
//    constraint in this delta; the encoder is the check.
//
// 5. An aspect with no trait is refused (D11).
//
//    badEmpty: #Module & {
//        metadata: postgresModule.metadata
//        #config: postgresModule.#config
//        #aspects: empty: spec: {}
//    }
//    // badEmpty.#aspects.empty._hasTraits: conflicting values false and true
//
// 6. An aspect contributing a matchLabels key of its own is refused (D11,
//    the #Component derivation rule).
//
//    badKey: #Module & {
//        metadata: postgresModule.metadata
//        #config: postgresModule.#config
//        #aspects: isolation: {
//            #traits: (#NetworkIsolationTrait.metadata.fqn): #NetworkIsolationTrait
//            matchLabels: "mine": "yes"
//            spec: networkIsolation: allowedCIDRs: []
//        }
//    }
//    // badKey.#aspects.isolation._matchLabelsAreDerived: conflicting values false and true
//
// 7. A module trait carrying appliesTo is refused (D12): the field is a
//    component-trait concept and #ModuleTrait is closed.
//
//    badTrait: #NetworkIsolationTrait & {appliesTo: []}
//    // badTrait: field not allowed: appliesTo
//
// 8. A spec key no attached trait declares is refused (D11, closed spec).
//
//    badSpec: #Module & {
//        metadata: postgresModule.metadata
//        #config: postgresModule.#config
//        #aspects: isolation: {
//            #traits: (#NetworkIsolationTrait.metadata.fqn): #NetworkIsolationTrait
//            spec: {networkIsolation: allowedCIDRs: [], resourceBudget: {}}
//        }
//    }
//    // badSpec.#aspects.isolation.spec.resourceBudget: field not allowed
