package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	k8sapiextv1 "opmodel.dev/catalogs/opm/schemas/kubernetes/apiextensions/v1"
)

// CRDTransformer converts CRDs resources to Kubernetes CustomResourceDefinitions
#CRDTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "crd-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/crd-transformer@\(id.Version)"
		description:    "Converts CRDs resources to Kubernetes CustomResourceDefinitions"

		labels: {
			"core.opmodel.dev/resource-category": "extension"
			"core.opmodel.dev/resource-type":     "crd"
		}
	}

	requiredLabels: {}

	// Required resources - CRDs MUST be present
	requiredResources: {
		(res.#CRDsResource.metadata.fqn): res.#CRDsResource
	}

	optionalResources: {}
	requiredTraits: {}
	optionalTraits: {}

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		_crds: #component.spec.crds

		// Emit one K8s CustomResourceDefinition per entry in the component's
		// crds map. Output is a list of resources; the renderer dispatches
		// on cue.Kind and produces one Compiled per list element.
		output: [
			for crdName, crd in _crds {
				// Plain unification, so a key set on both sides with different
				// values is a hard error rather than a silent win for either.
				let _annotations = {
					if len(#context.componentAnnotations) > 0 {#context.componentAnnotations}
					if crd.annotations != _|_ {crd.annotations}
				}

				k8sapiextv1.#CustomResourceDefinition & {
					apiVersion: "apiextensions.k8s.io/v1"
					kind:       "CustomResourceDefinition"
					metadata: {
						name:   crdName // exact — <plural>.<group> is the CRD identity
						labels: #context.labels
						if len(_annotations) > 0 {
							annotations: _annotations
						}
					}
					spec: {
						group: crd.group
						names: {
							kind:   crd.names.kind
							plural: crd.names.plural
							if crd.names.listKind != _|_ {
								listKind: crd.names.listKind
							}
							if crd.names.singular != _|_ {
								singular: crd.names.singular
							}
							if crd.names.shortNames != _|_ {
								shortNames: crd.names.shortNames
							}
							if crd.names.categories != _|_ {
								categories: crd.names.categories
							}
						}
						scope:    crd.scope
						versions: crd.versions
					}
				}
			},
		]
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
////
//// Golden mirrors a vendored cert-manager CRD: the fields an upstream
//// manifest actually carries, including listKind and the issuerRef
//// selectableFields (a field selector on an undeclared field is
//// rejected by the API server, so dropping them is a behaviour change).
/////////////////////////////////////////////////////////////////

_testCRDComponent: {
	res.#CRDs

	metadata: {
		name: "crds"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: crds: "orders.acme.cert-manager.io": {
		// A protected-group CRD would be REJECTED by the API server without
		// api-approved.kubernetes.io; this mirrors what an upstream Gateway API
		// manifest carries.
		annotations: {
			"api-approved.kubernetes.io":               "https://github.com/kubernetes-sigs/gateway-api/pull/4530"
			"gateway.networking.k8s.io/bundle-version": "v1.5.1"
		}
		group: "acme.cert-manager.io"
		names: {
			kind:     "Order"
			listKind: "OrderList"
			plural:   "orders"
			singular: "order"
			categories: ["cert-manager", "cert-manager-acme"]
		}
		scope: "Namespaced"
		versions: [{
			name:    "v1"
			served:  true
			storage: true
			schema: openAPIV3Schema: type: "object"
			subresources: status: {}
			selectableFields: [
				{jsonPath: ".spec.issuerRef.group"},
				{jsonPath: ".spec.issuerRef.kind"},
				{jsonPath: ".spec.issuerRef.name"},
			]
		}]
	}
}

_testCRDTransformer: (#CRDTransformer.#transform & {
	#component: _testCRDComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "cert-manager"
			namespace: "cert-manager"
			fqn:       "opmodel.dev/catalogs/opm/cert-manager@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "crds"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

_testCRDTransformer: [{
	apiVersion: "apiextensions.k8s.io/v1"
	kind:       "CustomResourceDefinition"
	metadata: name: "orders.acme.cert-manager.io"
	spec: {
		group: "acme.cert-manager.io"
		names: {
			kind:     "Order"
			plural:   "orders"
			singular: "order"
		}
		scope: "Namespaced"
	}
}]

// Presence guards for the two fields this change adds, kept OUT of the golden
// above on purpose: unification ADDS a field the output is missing rather than
// rejecting it, so a golden naming listKind would silently repair a
// transformer that dropped it.
//
// The comprehension form is what makes absence fail: an unset optional field
// is merely incomplete, so `"\(…listKind)" & "OrderList"` passes plain
// `cue vet` (only -c would catch it), whereas an empty list against a
// one-element list is a hard length conflict at every vet level.
_testCRDListKindPresent: [
	if _testCRDTransformer[0].spec.names.listKind != _|_ {_testCRDTransformer[0].spec.names.listKind},
] & ["OrderList"]

_testCRDSelectableFieldsPresent: [
	if _testCRDTransformer[0].spec.versions[0].selectableFields != _|_ {
		len(_testCRDTransformer[0].spec.versions[0].selectableFields)
	},
] & [3]

// Same presence idiom for the CRD's own annotations. Interpolating the value
// (rather than naming it in the golden) forces resolution, so a transformer
// that dropped the key cannot have it handed back by unification.
_testCRDAnnotationsPresent: [
	if _testCRDTransformer[0].metadata.annotations != _|_ {
		"\(_testCRDTransformer[0].metadata.annotations["api-approved.kubernetes.io"])"
	},
] & ["https://github.com/kubernetes-sigs/gateway-api/pull/4530"]

_testCRDAnnotationCount: [
	if _testCRDTransformer[0].metadata.annotations != _|_ {
		len(_testCRDTransformer[0].metadata.annotations)
	},
] & [2]

/////////////////////////////////////////////////////////////////
//// Absence case
////
//// A CRD carrying no annotations, with no componentAnnotations either, must
//// emit NO annotations key at all — an empty map would still be a diff against
//// the vendored source on every server-side apply.
/////////////////////////////////////////////////////////////////

_testCRDBareComponent: {
	res.#CRDs

	metadata: name: "crds"

	spec: crds: "widgets.example.com": {
		group: "example.com"
		names: {
			kind:   "Widget"
			plural: "widgets"
		}
		scope: "Cluster"
		versions: [{
			name:    "v1"
			served:  true
			storage: true
		}]
	}
}

_testCRDBareTransformer: (#CRDTransformer.#transform & {
	#component: _testCRDBareComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "example"
			namespace: "default"
			fqn:       "opmodel.dev/catalogs/opm/example@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "crds"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

_testCRDNoAnnotationLeak: [
	if _testCRDBareTransformer[0].metadata.annotations != _|_ {"leaked"},
] & []
