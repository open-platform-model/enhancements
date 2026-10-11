// Concrete example instances for the target.cue delta: the test.
//
// One worked cast: a module called payments carries three aspects, two of
// them rendered and one read-only, and two instances of it prove the
// per-instance name derivation. Hidden assertion fields pin every derived
// value so a behaviour change breaks `cue vet ./...`.
//
// The fixtures are the test's own, not catalog deliverables: this entry
// publishes no module trait and no module transformer (D15). They carry an
// example.com path for that reason.
package schema

// ─── Fixtures: three module traits and one module transformer ───────────────
//
// Stood up here as definitions, the way a catalog would ship them, so the
// delta can be exercised. Two are rendered; the third is read by other tools
// and handled by no transformer, which is the case OQ13 is about.

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

// A declaration-only module trait: no matchLabels, so no transformer ever
// matches it. What such a trait states for `fulfilment` is OQ13.
#OwnershipTrait: #ModuleTrait & {
	metadata: {
		name:           "ownership"
		modulePath:     "example.com/catalogs/demo/module-traits/v1alpha1"
		apiVersion:     "v1alpha1"
		catalogVersion: "1.0.0"
		fqn:            "example.com/catalogs/demo/module-traits/ownership@v1alpha1"
	}
	optional: bool | *true
	spec: ownership: team!: string
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

// ─── The module: it describes itself through aspects (D11) ──────────────────

paymentsModule: #Module & {
	metadata: {
		name:         "payments"
		modulePath:   "example.com/modules/payments@v1"
		version:      "1.4.2"
		registryPath: "example.com/modules/payments"
	}
	#config: {
		replicas:     int & >=1 | *1
		memoryBudget: string | *"32Gi"
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
			spec: resourceBudget: {cpu: "8", memory: #config.memoryBudget}
		}
		// Read by other tools, rendered by nothing.
		owner: {
			#traits: (#OwnershipTrait.metadata.fqn): #OwnershipTrait
			spec: ownership: team: "checkout"
		}
	}
}

// Aspect identity: name from the key, the label stamp, no self-contributed
// matchLabels key, exactly one key per trait, and none at all for a
// declaration-only trait.
_assertAspectName:  paymentsModule.#aspects.isolation.metadata.name & "isolation"
_assertAspectLabel: paymentsModule.#aspects.budget.metadata.labels["aspect.opmodel.dev/name"] & "budget"
_assertAspectMatch: paymentsModule.#aspects.isolation.matchLabels & {"opm.opmodel.dev/network-isolation": "true"}
_assertMatchCount:  len(paymentsModule.#aspects.budget.matchLabels) & 1
_assertNoMatch:     len(paymentsModule.#aspects.owner.matchLabels) & 0

// The attachment site narrowed the catalog's posture (D12, the #Trait rule).
_assertNarrowed: paymentsModule.#aspects.budget.#traits[#ResourceBudgetTrait.metadata.fqn].optional & false

// ─── Two instances: the aspect's name is instance-qualified (D11) ───────────
//
// A #ModuleInstance is what supplies the identity an aspect reads through
// #ctx. Two of them, so the derivation is proved per instance rather than
// once.

prodInstance: #ModuleInstance & {
	metadata: {name: "payments-prod", namespace: "team-checkout"}
	#module: paymentsModule
	values: {replicas: 3, memoryBudget: "64Gi"}
}

stagingInstance: #ModuleInstance & {
	metadata: {name: "payments-staging", namespace: "team-checkout-staging"}
	#module: paymentsModule
	values: {}
}

_assertDefaultReplicas: stagingInstance._configCheck.replicas & 1
_assertBoundReplicas:   prodInstance._configCheck.replicas & 3

_assertAspectResourceName: prodInstance.#module.#aspects.isolation.#names.resourceName & "payments-prod-isolation"
_assertStagingBudgetName:  stagingInstance.#module.#aspects.budget.#names.resourceName & "payments-staging-budget"
_assertAspectInstance:     prodInstance.#module.#aspects.owner.#instance.namespace & "team-checkout"

// The declaration is readable off the module without anything rendering it.
_assertDeclaredTeam: paymentsModule.#aspects.owner.spec.ownership.team & "checkout"

// ─── A module transformer renders one aspect (D13) ──────────────────────────

paymentsNetworkPolicy: (#NetworkPolicyTransformer.#transform & {
	#moduleInstance: prodInstance
	#aspect:         prodInstance.#module.#aspects.isolation
}).output

_assertNPName:      paymentsNetworkPolicy.metadata.name & "payments-prod-isolation"
_assertNPNamespace: paymentsNetworkPolicy.metadata.namespace & "team-checkout"
_assertNPSelector:  paymentsNetworkPolicy.spec.podSelector.matchLabels["module-instance.opmodel.dev/name"] & "payments-prod"
_assertNPLabel:     paymentsNetworkPolicy.metadata.labels["aspect.opmodel.dev/name"] & "isolation"
// The one field read from #config, through the aspect spec and the default.
_assertNPCIDR:      paymentsNetworkPolicy.spec.ingress[0].from[0].ipBlock.cidr & "10.0.0.0/8"

// 5. An aspect with no trait is refused (D11).
//
//    badEmpty: #Module & {
//        metadata: paymentsModule.metadata
//        #config: paymentsModule.#config
//        #aspects: empty: spec: {}
//    }
//    // badEmpty.#aspects.empty._hasTraits: conflicting values false and true
//
// 6. An aspect contributing a matchLabels key of its own is refused (D11,
//    the #Component derivation rule).
//
//    badKey: #Module & {
//        metadata: paymentsModule.metadata
//        #config: paymentsModule.#config
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
//        metadata: paymentsModule.metadata
//        #config: paymentsModule.#config
//        #aspects: isolation: {
//            #traits: (#NetworkIsolationTrait.metadata.fqn): #NetworkIsolationTrait
//            spec: {networkIsolation: allowedCIDRs: [], resourceBudget: {}}
//        }
//    }
//    // badSpec.#aspects.isolation.spec.resourceBudget: field not allowed
