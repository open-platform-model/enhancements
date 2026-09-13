package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	k8spolicyv1 "opmodel.dev/catalogs/opm/schemas/kubernetes/policy/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// WHY: Like #ScalingTrait's `auto` block, #DisruptionBudgetSchema has existed since
// the catalog was written with nothing emitting it.
//
// Unlike the HPA this requires its own trait, so it only matches components that
// actually asked for a budget — no conditional-emission guard is needed. The
// trait is not composed by any blueprint, so it must be attached explicitly.
//
// The selector deliberately uses #context.componentLabels — the same value the
// workload transformers put in `spec.selector.matchLabels` — so the budget
// always covers exactly the workload's pods.

// PDBTransformer realizes #DisruptionBudgetTrait as a PodDisruptionBudget.
#PDBTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "pdb-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/pdb-transformer@\(id.Version)"
		description:    "Converts a workload's disruption budget to a Kubernetes PodDisruptionBudget"

		labels: {
			"core.opmodel.dev/resource-type": "poddisruptionbudget"
		}
	}

	requiredResources: {
		(res.#ContainerResource.metadata.fqn): res.#ContainerResource
	}

	requiredTraits: {
		(tr.#DisruptionBudgetTrait.metadata.fqn): tr.#DisruptionBudgetTrait
	}

	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext

		_budget: #component.spec.disruptionBudget

		output: k8spolicyv1.#PodDisruptionBudget & {
			apiVersion: "policy/v1"
			kind:       "PodDisruptionBudget"
			metadata: {
				name:      #component.#names.resourceName
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
				if len(#context.componentAnnotations) > 0 {
					annotations: #context.componentAnnotations
				}
			}
			spec: {
				// #DisruptionBudgetSchema is a disjunction, so exactly one of
				// these is ever present.
				if _budget.minAvailable != _|_ {
					minAvailable: _budget.minAvailable
				}
				if _budget.maxUnavailable != _|_ {
					maxUnavailable: _budget.maxUnavailable
				}
				selector: matchLabels: #context.componentLabels
			}
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

_testPDBComponent: {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#DisruptionBudget

	metadata: {
		name:         "istiod"
		resourceName: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: {
			name: "discovery"
			image: {
				repository: "docker.io/istio/pilot"
				tag:        "1.30.3-distroless"
				digest:     ""
			}
		}
		disruptionBudget: minAvailable: 1
	}
}

_testPDBContext: {
	#moduleInstanceMetadata: {
		name:      "istio"
		namespace: "istio-system"
		fqn:       "opmodel.dev/catalogs/opm/istio@0.1.0"
		version:   "0.1.0"
		uuid:      "00000000-0000-0000-0000-000000000000"
	}
	#componentMetadata: name: "istiod"
	#runtimeName: "opm-test"
	componentAnnotations: {}
}

_testPDBTransformer: (#PDBTransformer.#transform & {
	#component: _testPDBComponent
	#context:   _testPDBContext
}).output

_testPDBName: "\(_testPDBTransformer.metadata.name)" & "istiod"
// Two guards, because one cannot do the job: the empty-comprehension form
// catches the field being DROPPED (an absent optional is merely incomplete,
// which plain `cue vet` accepts), and the arithmetic form catches a WRONG
// value non-invertibly. Verified by deleting the minAvailable passthrough and
// by removing matchN from the schema — with only the arithmetic guard, both
// regressions passed silently.
_testPDBMinAvailablePresent: [
	if _testPDBTransformer.spec.minAvailable != _|_ {"present"},
] & ["present"]

_testPDBMinAvailableValue: (_testPDBTransformer.spec.minAvailable + 0) & 1

// The disjunction means exactly one of the two fields is ever emitted; a
// transformer that stamped both would produce an object the API server rejects.
_testPDBNoMaxUnavailable: [
	if _testPDBTransformer.spec.maxUnavailable != _|_ {"leaked"},
] & []

// The budget must select exactly the workload's pods, so its selector has to be
// the same value the Deployment transformer used. Compared by length
// (non-invertible) plus a per-key presence check.
_testPDBSelectorSize: (len(_testPDBTransformer.spec.selector.matchLabels) + 0) & 2

_testPDBSelectorMatchesDeployment: [
	for k, v in (#DeploymentTransformer.#transform & {
		#component: _testPDBComponent
		#context:   _testPDBContext
	}).output.spec.selector.matchLabels if _testPDBTransformer.spec.selector.matchLabels[k] == v {k},
] & [_, _]

// Default naming: no metadata.resourceName, so the budget carries the component's
// instance-scoped resourceName, byte-identical to the Deployment's name.
_testPDBDefaultNameComponent: {
	res.#Container
	tr.#DisruptionBudget

	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: {
			name: "discovery"
			image: {
				repository: "docker.io/istio/pilot"
				tag:        "1.30.3-distroless"
				digest:     ""
			}
		}
		disruptionBudget: minAvailable: 1
	}
}

_testPDBDefaultNameTransformer: (#PDBTransformer.#transform & {
	#component: _testPDBDefaultNameComponent
	#context:   _testPDBContext
}).output

_testPDBDefaultNameResolves: "\(_testPDBDefaultNameTransformer.metadata.name)" & "istio-istiod"

// Cross-transformer consistency: the PDB's name must equal the name the
// Deployment transformer rendered for the SAME component (same shape as
// _testHPATargetMatchesDeployment).
_testPDBNameMatchesDeployment: "\(_testPDBDefaultNameTransformer.metadata.name)" &
	"\((#DeploymentTransformer.#transform & {
		#component: _testPDBDefaultNameComponent
		#context:   _testPDBContext
	}).output.metadata.name)"
