package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	"list"
	k8sappsv1 "opmodel.dev/catalogs/opm/schemas/kubernetes/apps/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// DeploymentTransformer converts stateless workload components to Kubernetes Deployments
#DeploymentTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "deployment-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/deployment-transformer@\(id.Version)"
		description:    "Converts stateless workload components with Container resource to Kubernetes Deployments"

		labels: {
			"core.opmodel.dev/workload-type": "stateless"
			"core.opmodel.dev/resource-type": "deployment"
		}
	}

	// Required label to match stateless workloads
	requiredLabels: {
		"core.opmodel.dev/workload-type": "stateless"
	}

	// Required resources - Container MUST be present
	requiredResources: {
		(res.#ContainerResource.metadata.fqn): res.#ContainerResource
	}

	// Optional resources
	optionalResources: {
		(res.#VolumesResource.metadata.fqn): res.#VolumesResource
	}

	// No required traits
	requiredTraits: {}

	// Optional traits that enhance deployment behavior
	optionalTraits: {
		(tr.#ScalingTrait.metadata.fqn):           tr.#ScalingTrait
		(tr.#RestartPolicyTrait.metadata.fqn):     tr.#RestartPolicyTrait
		(tr.#UpdateStrategyTrait.metadata.fqn):    tr.#UpdateStrategyTrait
		(tr.#SidecarContainersTrait.metadata.fqn): tr.#SidecarContainersTrait
		(tr.#InitContainersTrait.metadata.fqn):    tr.#InitContainersTrait
		(tr.#SecurityContextTrait.metadata.fqn):   tr.#SecurityContextTrait
		(tr.#RuntimeClassTrait.metadata.fqn):      tr.#RuntimeClassTrait
		(tr.#WorkloadIdentityTrait.metadata.fqn):  tr.#WorkloadIdentityTrait
		(tr.#ImagePullSecretsTrait.metadata.fqn):  tr.#ImagePullSecretsTrait
		(tr.#HostPIDTrait.metadata.fqn):           tr.#HostPIDTrait
		(tr.#HostIPCTrait.metadata.fqn):           tr.#HostIPCTrait
		(tr.#GracefulShutdownTrait.metadata.fqn):  tr.#GracefulShutdownTrait
		(tr.#PodSchedulingTrait.metadata.fqn):     tr.#PodSchedulingTrait
		(tr.#PodMetadataTrait.metadata.fqn):       tr.#PodMetadataTrait
		(tr.#NetworkPolicyTrait.metadata.fqn):     tr.#NetworkPolicyTrait
	}

	// Transform function
	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext

		// Extract required Container resource
		_container: #component.spec.container

		// Apply defaults for optional traits (defaults inlined post-014; #defaults
		// field on Trait was a v1alpha1 idiom, retired in v1alpha2).
		// When `auto` is set the HPA owns the replica count. Emitting
		// `replicas` too would put this transformer and the autoscaler in a
		// permanent server-side-apply tug-of-war on every reconcile, so the
		// field is omitted entirely (see _hasAuto below).
		_hasAuto: #component.spec.scaling != _|_ && #component.spec.scaling.auto != _|_

		_scalingCount: int | *1
		if #component.spec.scaling != _|_ if #component.spec.scaling.auto == _|_ {
			_scalingCount: #component.spec.scaling.count
		}

		_restartPolicy: string | *"Always"
		if #component.spec.restartPolicy != _|_ {
			_restartPolicy: #component.spec.restartPolicy
		}

		// WHY: ⚠ THE GUARD MUST BE A SEPARATE ASSIGNMENT, not an `if` nested inside
		// the second disjunct. This was written as
		//
		//     _updateStrategy: *null | {
		//         if #component.spec.updateStrategy != _|_ { type: ... }
		//     }
		//
		// which silently resolved to `null` for EVERY component, so `strategy`
		// was never emitted on any Deployment no matter what the module asked
		// for. Nothing forces the struct arm there, and a marked default wins
		// over a non-default arm — the same trap `name_helpers.cue` documents
		// for `#comp.spec.resourceName | *"..."`. It went unnoticed because
		// every module declared RollingUpdate, which is also the Kubernetes
		// default; the modules asking for Recreate were the ones it broke.
		//
		// The form below is the idiom used by _restartPolicy and _scalingCount
		// above: declare the default, then override in a guarded assignment at
		// the same scope, where unification collapses the disjunction.
		// The rollingUpdate reference carries its own existence conjunct:
		// #UpdateStrategySchema leaves the substruct optional under
		// RollingUpdate, and an unguarded dereference of the omitted field
		// fails the whole guarded struct — a schema-legal component must
		// render, with Kubernetes applying its own surge/unavailable
		// defaults.

		// Extract update strategy with defaults.
		_updateStrategy: *null | {...}
		if #component.spec.updateStrategy != _|_ {
			_updateStrategy: {
				type: #component.spec.updateStrategy.type
				if #component.spec.updateStrategy.type == "RollingUpdate" &&
					#component.spec.updateStrategy.rollingUpdate != _|_ {
					rollingUpdate: #component.spec.updateStrategy.rollingUpdate
				}
			}
		}

		// Build main container: base conversion via helper, unified with trait fields
		_mainContainer: (#ToK8sContainer & {"in": _container}).out

		// Build container list (main container + optional sidecars)
		_sidecarContainers: [...] | *[]
		if #component.spec.sidecarContainers != _|_ {
			_sidecarContainers: #component.spec.sidecarContainers
		}

		// Extract init containers with defaults
		_initContainers: [...] | *[]
		if #component.spec.initContainers != _|_ {
			_initContainers: #component.spec.initContainers
		}

		// Build Deployment resource
		output: k8sappsv1.#Deployment & {
			apiVersion: "apps/v1"
			kind:       "Deployment"
			metadata: {
				name:      #component.#names.resourceName
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
				// Include component annotations if present
				if len(#context.componentAnnotations) > 0 {
					annotations: #context.componentAnnotations
				}
			}
			spec: {
				if !_hasAuto {
					replicas: _scalingCount
				}
				selector: matchLabels: #context.componentLabels
				template: {
					metadata: (#PodTemplateMetadata & {
						#comp:   #component
						#labels: #context.componentLabels
					}).out
					spec: {
						(#PodSchedulingFields & {#comp: #component}).out

						_convertedSidecars: (#ToK8sContainers & {"in": _sidecarContainers}).out
						containers: list.Concat([[_mainContainer], _convertedSidecars])

						if len(_initContainers) > 0 {
							initContainers: (#ToK8sContainers & {"in": _initContainers}).out
						}

						restartPolicy: _restartPolicy

						// The named RuntimeClass must already exist in the cluster;
						// this only references it.
						if #component.spec.runtimeClass != _|_ {
							runtimeClassName: #component.spec.runtimeClass
						}

						if #component.spec.hostPid != _|_ {
							hostPID: #component.spec.hostPid
						}

						if #component.spec.hostIpc != _|_ {
							hostIPC: #component.spec.hostIpc
						}

						// SecurityContext: pod-level fields
						if #component.spec.securityContext != _|_ {
							let _sc = #component.spec.securityContext
							if _sc.runAsNonRoot != _|_ || _sc.runAsUser != _|_ || _sc.runAsGroup != _|_ || _sc.fsGroup != _|_ || _sc.supplementalGroups != _|_ {
								securityContext: {
									if _sc.runAsNonRoot != _|_ {
										runAsNonRoot: _sc.runAsNonRoot
									}
									if _sc.runAsUser != _|_ {
										runAsUser: _sc.runAsUser
									}
									if _sc.runAsGroup != _|_ {
										runAsGroup: _sc.runAsGroup
									}
									if _sc.fsGroup != _|_ {
										fsGroup: _sc.fsGroup
									}
									if _sc.supplementalGroups != _|_ {
										supplementalGroups: _sc.supplementalGroups
									}
								}
							}
						}

						// ServiceAccount reference
						if #component.spec.workloadIdentity != _|_ {
							serviceAccountName: #component.spec.workloadIdentity.name
						}

						// Image pull secrets: pod-level registry credentials
						if #component.spec.imagePullSecrets != _|_ {
							imagePullSecrets: #component.spec.imagePullSecrets
						}

						// Volumes: convert OPM volume specs to Kubernetes volume specs
						if #component.spec.volumes != _|_ {
							volumes: (#ToK8sVolumes & {"in": #component.spec.volumes, #instancePrefix: "\(#context.#moduleInstanceMetadata.name)-\(#context.#componentMetadata.name)"}).out
						}

						// Graceful shutdown: pod-level termination grace period
						if #component.spec.gracefulShutdown != _|_ {
							terminationGracePeriodSeconds: #component.spec.gracefulShutdown.terminationGracePeriodSeconds
						}
					}
				}

				if _updateStrategy != null {
					strategy: _updateStrategy
				}
			}
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
////
//// Guard idioms, and why they are not plain goldens:
////   - wrong VALUE  -> force resolution with string interpolation or
////     arithmetic. `"\(x)" & "want"` is non-invertible, so it cannot repair
////     the value it is checking. A bare golden `name: "want"` WOULD repair a
////     regression to `x | *y` and pass against broken code.
////   - ABSENT field -> empty comprehension against a one-element list. An
////     unset optional is merely incomplete, which plain `cue vet` accepts;
////     a list-length conflict fails at every vet level.
////   - LEAKED field -> empty comprehension against an empty list.
/////////////////////////////////////////////////////////////////

// Shared stub context. componentLabels resolves to exactly two entries:
// app.kubernetes.io/name=istiod and module-instance.opmodel.dev/name=istio.
_testDeployContext: {
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

_testDeployContainer: {
	name: "discovery"
	image: {
		repository: "docker.io/istio/pilot"
		tag:        "1.30.3-distroless"
		digest:     ""
	}
}

// ---- Default naming: no metadata.resourceName -> instance-scoped -------------
_testDeployDefaultNameComponent: {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container

	metadata: {
		name: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: container: _testDeployContainer
}

_testDeployDefaultNameTransformer: (#DeploymentTransformer.#transform & {
	#component: _testDeployDefaultNameComponent
	#context:   _testDeployContext
}).output

_testDeployDefaultNameResolves: "\(_testDeployDefaultNameTransformer.metadata.name)" & "istio-istiod"

// A component with none of the three new traits must not grow any of their
// output. These are the guards that catch an unguarded passthrough.
_testDeployNoPodAnnotations: [
	if _testDeployDefaultNameTransformer.spec.template.metadata.annotations != _|_ {"leaked"},
] & []

_testDeployNoNodeSelector: [
	if _testDeployDefaultNameTransformer.spec.template.spec.nodeSelector != _|_ {"leaked"},
] & []

_testDeployNoTolerations: [
	if _testDeployDefaultNameTransformer.spec.template.spec.tolerations != _|_ {"leaked"},
] & []

_testDeployNoPriorityClass: [
	if _testDeployDefaultNameTransformer.spec.template.spec.priorityClassName != _|_ {"leaked"},
] & []

// ---- Exact name + pod metadata + scheduling ---------------------------------
// Mirrors the live istiod Deployment on an ambient mesh: the workload renders
// unprefixed, `istio.io/dataplane-mode: none` is a POD label (it must never
// reach the immutable selector), and the prometheus annotations are pod-only.
_testDeployExactComponent: {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#PodMetadata
	tr.#PodScheduling

	metadata: {
		name:         "istiod"
		resourceName: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: _testDeployContainer
		podMetadata: {
			labels: {
				"sidecar.istio.io/inject": "false"
				"istio.io/dataplane-mode": "none"
			}
			annotations: {
				"prometheus.io/scrape": "true"
				"prometheus.io/port":   "15014"
			}
		}
		podScheduling: {
			nodeSelector: "kubernetes.io/os": "linux"
			tolerations: [{key: "cni.istio.io/not-ready", operator: "Exists"}]
			priorityClassName: "system-node-critical"
		}
	}
}

_testDeployExactTransformer: (#DeploymentTransformer.#transform & {
	#component: _testDeployExactComponent
	#context:   _testDeployContext
}).output

_testDeployExactNameResolves: "\(_testDeployExactTransformer.metadata.name)" & "istiod"

// The whole point of #PodMetadata: pod labels grow, the SELECTOR does not.
// Arithmetic on the lengths is non-invertible, so a leak into the selector
// cannot be repaired by the assertion.
_testDeploySelectorStaysTwo: (len(_testDeployExactTransformer.spec.selector.matchLabels) + 0) & 2
_testDeployPodLabelsAreFour: (len(_testDeployExactTransformer.spec.template.metadata.labels) + 0) & 4

_testDeployPodLabelPresent: [
	if _testDeployExactTransformer.spec.template.metadata.labels["istio.io/dataplane-mode"] != _|_ {
		_testDeployExactTransformer.spec.template.metadata.labels["istio.io/dataplane-mode"]
	},
] & ["none"]

// ...and that label must NOT have reached the selector.
_testDeploySelectorUnpolluted: [
	if _testDeployExactTransformer.spec.selector.matchLabels["istio.io/dataplane-mode"] != _|_ {"leaked"},
] & []

_testDeployPodAnnotationPresent: [
	if _testDeployExactTransformer.spec.template.metadata.annotations["prometheus.io/port"] != _|_ {
		_testDeployExactTransformer.spec.template.metadata.annotations["prometheus.io/port"]
	},
] & ["15014"]

_testDeployNodeSelectorPresent: [
	if _testDeployExactTransformer.spec.template.spec.nodeSelector["kubernetes.io/os"] != _|_ {
		_testDeployExactTransformer.spec.template.spec.nodeSelector["kubernetes.io/os"]
	},
] & ["linux"]

_testDeployTolerationPresent: [
	if _testDeployExactTransformer.spec.template.spec.tolerations != _|_ {
		_testDeployExactTransformer.spec.template.spec.tolerations[0].key
	},
] & ["cni.istio.io/not-ready"]

_testDeployPriorityClassPresent: [
	if _testDeployExactTransformer.spec.template.spec.priorityClassName != _|_ {
		_testDeployExactTransformer.spec.template.spec.priorityClassName
	},
] & ["system-node-critical"]

// ---- Update strategy: declared value must reach spec.strategy ---------------
//
// Regression guard for a bug that shipped silently through alpha.8: the
// extraction was spelled `_updateStrategy: *null | { if ... }`, whose marked
// default always won, so `strategy` was omitted from EVERY Deployment. No test
// caught it because every module in the fleet declared RollingUpdate, which is
// also the Kubernetes default — the omission was invisible until a module asked
// for Recreate and silently got a rolling update instead.
//
// Recreate rather than RollingUpdate on purpose: it is the value that differs
// from the Kubernetes default, so this fails if the field is dropped again.
_testDeployRecreateComponent: {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#UpdateStrategy

	metadata: {
		name: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: _testDeployContainer
		updateStrategy: type: "Recreate"
	}
}

_testDeployRecreateTransformer: (#DeploymentTransformer.#transform & {
	#component: _testDeployRecreateComponent
	#context:   _testDeployContext
}).output

// ABSENT-field guard, NOT the interpolation idiom. The failure mode being
// guarded is an omitted `strategy`, and `"\(...spec.strategy.type)" & "Recreate"`
// does NOT catch that: with the field absent the interpolation is merely
// incomplete, which plain `cue vet` accepts — verified by reintroducing the bug
// and watching vet still exit 0. The one-element-list form conflicts on length
// instead, which fails at every vet level (see the idiom notes above).
//
// This doubles as the wrong-value guard: a strategy that renders with the wrong
// type produces ["RollingUpdate"], which also conflicts.
_testDeployRecreatePresent: [
	if _testDeployRecreateTransformer.spec.strategy != _|_ {
		_testDeployRecreateTransformer.spec.strategy.type
	},
] & ["Recreate"]

// ABSENT-field guard: Recreate must not carry a rollingUpdate block.
_testDeployRecreateHasNoRollingUpdate: [
	if _testDeployRecreateTransformer.spec.strategy.rollingUpdate != _|_ {"leaked"},
] & []

// ...and a component that declares no strategy must not grow one.
_testDeployNoStrategyLeak: [
	if _testDeployDefaultNameTransformer.spec.strategy != _|_ {"leaked"},
] & []

// ---- Update strategy: omitted rollingUpdate params must not fail ------------
//
// Regression guard for the sibling of the alpha.8 bug above: the extraction
// dereferenced `spec.updateStrategy.rollingUpdate` unguarded whenever type was
// RollingUpdate, but #UpdateStrategySchema leaves the substruct optional — so
// a schema-legal `updateStrategy: type: "RollingUpdate"` with no parameters
// failed the whole transform with an empty disjunction (first hit by the
// library's web_app flow fixture during the core-v2 retarget).
_testDeployRollingDefaultsComponent: {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#UpdateStrategy

	metadata: {
		name: "web"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: _testDeployContainer
		updateStrategy: type: "RollingUpdate"
	}
}

_testDeployRollingDefaultsTransformer: (#DeploymentTransformer.#transform & {
	#component: _testDeployRollingDefaultsComponent
	#context:   _testDeployContext
}).output

// The strategy is emitted with its type...
_testDeployRollingDefaultsPresent: [
	if _testDeployRollingDefaultsTransformer.spec.strategy != _|_ {
		_testDeployRollingDefaultsTransformer.spec.strategy.type
	},
] & ["RollingUpdate"]

// ...and no rollingUpdate block is invented for the omitted substruct —
// Kubernetes applies its own maxSurge/maxUnavailable defaults.
_testDeployRollingDefaultsNoParams: [
	if _testDeployRollingDefaultsTransformer.spec.strategy.rollingUpdate != _|_ {"leaked"},
] & []
