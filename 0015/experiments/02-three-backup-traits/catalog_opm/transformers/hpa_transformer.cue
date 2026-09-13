package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	k8sautoscalingv2 "opmodel.dev/catalogs/opm/schemas/kubernetes/autoscaling/v2"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// WHY: The schema (#AutoscalingSpec: min/max/metrics/behavior) has existed since the
// catalog was written and was only ever read as a replica count by the
// Deployment and StatefulSet transformers. This emits the object it always
// described.
//
// Matching is deliberately broad — Container + Scaling, which is every stateless
// and stateful workload in every module (both blueprints compose #ScalingTrait,
// daemon/task/scheduled-task do not). Emitting nothing unless `auto` is set is
// therefore not an optimisation, it is the correctness condition: `output` is a
// list with a comprehension guard, and an empty list yields zero resources.

// HPATransformer realizes #ScalingTrait's `auto` block as a HorizontalPodAutoscaler.
#HPATransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "hpa-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/hpa-transformer@\(id.Version)"
		description:    "Converts a workload's autoscaling spec to a Kubernetes HorizontalPodAutoscaler"

		labels: {
			"core.opmodel.dev/resource-type": "horizontalpodautoscaler"
		}
	}

	// No requiredLabels: this matches both stateless and stateful workloads,
	// which carry different workload-type labels.
	requiredResources: {
		(res.#ContainerResource.metadata.fqn): res.#ContainerResource
	}

	requiredTraits: {
		(tr.#ScalingTrait.metadata.fqn): tr.#ScalingTrait
	}

	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext

		// The scaled object's kind follows the workload type. Read from the
		// component rather than #context.componentLabels so it does not depend
		// on which labels the context happens to project.
		_workloadType: #component.metadata.labels["core.opmodel.dev/workload-type"]

		_kind: [
			if _workloadType == "stateful" {"StatefulSet"},
			"Deployment",
		][0]

		// MUST be byte-identical to the name the Deployment/StatefulSet
		// transformer rendered, or the HPA silently targets nothing.
		_targetName: #component.#names.resourceName

		output: [
			if #component.spec.scaling != _|_ if #component.spec.scaling.auto != _|_ {
				let _auto = #component.spec.scaling.auto

				k8sautoscalingv2.#HorizontalPodAutoscaler & {
					apiVersion: "autoscaling/v2"
					kind:       "HorizontalPodAutoscaler"
					metadata: {
						name:      _targetName
						namespace: #context.#moduleInstanceMetadata.namespace
						labels:    #context.labels
						if len(#context.componentAnnotations) > 0 {
							annotations: #context.componentAnnotations
						}
					}
					spec: {
						scaleTargetRef: {
							apiVersion: "apps/v1"
							kind:       _kind
							name:       _targetName
						}
						minReplicas: _auto.min
						maxReplicas: _auto.max

						metrics: [for _m in _auto.metrics {
							// "cpu"/"memory" are the two built-in per-pod
							// resource metrics; anything else is a custom
							// per-pod metric addressed by name.
							if _m.type != "custom" {
								type: "Resource"
								resource: {
									name: _m.type
									target: (#ToK8sMetricTarget & {#target: _m.target}).out
								}
							}
							if _m.type == "custom" {
								type: "Pods"
								pods: {
									metric: name: _m.metricName
									target: (#ToK8sMetricTarget & {#target: _m.target}).out
								}
							}
						}]

						if _auto.behavior != _|_ {
							behavior: {
								if _auto.behavior.scaleUp != _|_ {
									scaleUp: _auto.behavior.scaleUp
								}
								if _auto.behavior.scaleDown != _|_ {
									scaleDown: _auto.behavior.scaleDown
								}
							}
						}
					}
				}
			},
		]
	}
}

// #ToK8sMetricTarget maps OPM's #MetricTargetSpec to a Kubernetes MetricTarget.
// The K8s `type` discriminator is implied by which field the author set, so it
// is derived rather than asked for twice.
#ToK8sMetricTarget: {
	#target!: tr.#MetricTargetSpec

	out: {
		if #target.averageUtilization != _|_ {
			type:               "Utilization"
			averageUtilization: #target.averageUtilization
		}
		if #target.averageUtilization == _|_ if #target.averageValue != _|_ {
			type:         "AverageValue"
			averageValue: #target.averageValue
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

_testHPAContext: {
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

_testHPAContainer: {
	name: "discovery"
	image: {
		repository: "docker.io/istio/pilot"
		tag:        "1.30.3-distroless"
		digest:     ""
	}
}

// ---- No `auto`: the transformer MUST emit nothing -----------------------
// This is the load-bearing test. #StatelessWorkload composes #ScalingTrait, so
// this transformer matches every stateless workload in every module —
// cert-manager, jellyfin, all of them. If it emitted an HPA whenever it
// matched, every one of them would grow a spurious autoscaler.
_testHPACountOnlyComponent: {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#Scaling

	metadata: {
		name: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: _testHPAContainer
		scaling: count: 3
	}
}

_testHPACountOnlyTransformer: (#HPATransformer.#transform & {
	#component: _testHPACountOnlyComponent
	#context:   _testHPAContext
}).output

_testHPAEmitsNothing: (len(_testHPACountOnlyTransformer) + 0) & 0

// ...and the Deployment keeps its explicit replica count in that case.
_testHPADeployKeepsReplicas: [
	if (#DeploymentTransformer.#transform & {
		#component: _testHPACountOnlyComponent
		#context:   _testHPAContext
	}).output.spec.replicas != _|_ {
		(#DeploymentTransformer.#transform & {
			#component: _testHPACountOnlyComponent
			#context:   _testHPAContext
		}).output.spec.replicas
	},
] & [3]

// ---- With `auto`: one HPA, targeting the workload's exact name -------------
_testHPAAutoComponent: {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#Scaling

	metadata: {
		name:         "istiod"
		resourceName: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: _testHPAContainer
		scaling: {
			count: 1
			auto: {
				min: 1
				max: 5
				metrics: [{
					type: "cpu"
					target: averageUtilization: 80
				}]
			}
		}
	}
}

_testHPAAutoTransformer: (#HPATransformer.#transform & {
	#component: _testHPAAutoComponent
	#context:   _testHPAContext
}).output

_testHPAEmitsOne: (len(_testHPAAutoTransformer) + 0) & 1

// Presence guard first (catches a dropped field, which arithmetic alone
// cannot), then the value guard (catches a wrong one, non-invertibly).
_testHPAMinPresent: [
	if _testHPAAutoTransformer[0].spec.minReplicas != _|_ {"present"},
] & ["present"]

_testHPAMin: (_testHPAAutoTransformer[0].spec.minReplicas + 0) & 1
_testHPAMax: (_testHPAAutoTransformer[0].spec.maxReplicas + 0) & 5

_testHPAMetricsPresent: (len(_testHPAAutoTransformer[0].spec.metrics) + 0) & 1

_testHPAMetricType:  "\(_testHPAAutoTransformer[0].spec.metrics[0].type)" & "Resource"
_testHPAMetricName:  "\(_testHPAAutoTransformer[0].spec.metrics[0].resource.name)" & "cpu"
_testHPATargetType:  "\(_testHPAAutoTransformer[0].spec.metrics[0].resource.target.type)" & "Utilization"
_testHPATargetValue: (_testHPAAutoTransformer[0].spec.metrics[0].resource.target.averageUtilization + 0) & 80

_testHPAScaleKind: "\(_testHPAAutoTransformer[0].spec.scaleTargetRef.kind)" & "Deployment"

// Cross-transformer consistency: the HPA's target name must equal the name the
// Deployment transformer actually rendered for the SAME component. One
// expression, so the two can never drift apart silently.
_testHPATargetMatchesDeployment: "\(_testHPAAutoTransformer[0].spec.scaleTargetRef.name)" &
	"\((#DeploymentTransformer.#transform & {
		#component: _testHPAAutoComponent
		#context:   _testHPAContext
	}).output.metadata.name)"

// ...and the Deployment must NOT emit replicas when the HPA owns them.
// Absent-field territory: a golden cannot express this.
_testHPADeployOmitsReplicas: [
	if (#DeploymentTransformer.#transform & {
		#component: _testHPAAutoComponent
		#context:   _testHPAContext
	}).output.spec.replicas != _|_ {"leaked"},
] & []

// Default naming: no metadata.resourceName, so the target is the component's
// instance-scoped resourceName, the same name the Deployment renders.
_testHPADefaultNameComponent: {
	res.#Container
	tr.#Scaling

	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: _testHPAContainer
		scaling: {
			count: 1
			auto: {
				min: 1
				max: 5
				metrics: [{
					type: "cpu"
					target: averageUtilization: 80
				}]
			}
		}
	}
}

_testHPADefaultNameTransformer: (#HPATransformer.#transform & {
	#component: _testHPADefaultNameComponent
	#context:   _testHPAContext
}).output

_testHPADefaultNameResolves:   "\(_testHPADefaultNameTransformer[0].metadata.name)" & "istio-istiod"
_testHPADefaultTargetResolves: "\(_testHPADefaultNameTransformer[0].spec.scaleTargetRef.name)" & "istio-istiod"
