package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	"list"
	k8sappsv1 "opmodel.dev/catalogs/opm/schemas/kubernetes/apps/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// StatefulsetTransformer converts stateful workload components to Kubernetes StatefulSets
#StatefulsetTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "statefulset-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/statefulset-transformer@\(id.Version)"
		description:    "Converts stateful workload components to Kubernetes StatefulSets"

		labels: {
			"core.opmodel.dev/workload-type": "stateful"
			"core.opmodel.dev/resource-type": "statefulset"
		}
	}

	// Required label to match stateful workloads
	requiredLabels: {
		"core.opmodel.dev/workload-type": "stateful"
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

	// Optional traits that enhance statefulset behavior
	optionalTraits: {
		(tr.#ScalingTrait.metadata.fqn):           tr.#ScalingTrait
		(tr.#RestartPolicyTrait.metadata.fqn):     tr.#RestartPolicyTrait
		(tr.#UpdateStrategyTrait.metadata.fqn):    tr.#UpdateStrategyTrait
		(tr.#SidecarContainersTrait.metadata.fqn): tr.#SidecarContainersTrait
		(tr.#InitContainersTrait.metadata.fqn):    tr.#InitContainersTrait
		(tr.#HostNetworkTrait.metadata.fqn):       tr.#HostNetworkTrait
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
		(tr.#ExposeTrait.metadata.fqn):            tr.#ExposeTrait
	}

	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext

		// Extract required Container resource
		_container: #component.spec.container

		// Apply defaults for optional traits (defaults inlined post-014).
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
		// the second disjunct — see the long note on the identical block in
		// deployment_transformer.cue. In short: the nested form resolved to
		// `null` for every component, so `updateStrategy` was never emitted on
		// any StatefulSet, and a module asking for OnDelete or Recreate got a
		// silent RollingUpdate instead.
		// The rollingUpdate reference carries its own existence conjunct:
		// #UpdateStrategySchema leaves the substruct optional under
		// RollingUpdate, and an unguarded dereference of the omitted field
		// fails the whole guarded struct — a schema-legal component must
		// render, with Kubernetes applying its own rolling defaults.

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

		// Build StatefulSet resource
		output: k8sappsv1.#StatefulSet & {
			apiVersion: "apps/v1"
			kind:       "StatefulSet"
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
				// WHY: Deliberately NOT metadata.name. serviceName is a cross-object
				// reference to the governing Service (0019 D22, carve-out 3), whose one
				// authoritative name is expose.name, and an author may set that apart from
				// the workload's resourceName. The read goes through #ServiceName so it
				// stays byte-identical to the Service transformer's, including the fallback
				// for a component compiled against a build whose expose.name was optional.

				// The governing Service's name: #ServiceName when #Expose is
				// attached, else the component's own short DNS name (a
				// default-named headless Service). See docs/name-constraints.md.
				serviceName: [
					if #component.spec.expose != _|_ {(#ServiceName & {#comp: #component}).out},
					#component.#names.dns.short,
				][0]
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

						if #component.spec.hostNetwork != _|_ {
							hostNetwork: #component.spec.hostNetwork
						}

						if #component.spec.hostPid != _|_ {
							hostPID: #component.spec.hostPid
						}

						if #component.spec.hostIpc != _|_ {
							hostIPC: #component.spec.hostIpc
						}

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
					updateStrategy: _updateStrategy
				}
			}
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

_testSTSContext: {
	#moduleInstanceMetadata: {
		name:      "shop"
		namespace: "apps"
		fqn:       "opmodel.dev/catalogs/opm/shop@0.1.0"
		version:   "0.1.0"
		uuid:      "00000000-0000-0000-0000-000000000000"
	}
	#componentMetadata: name: "db"
	#runtimeName: "opm-test"
	componentAnnotations: {}
}

_testSTSContainer: {
	name: "db"
	image: {
		repository: "postgres"
		tag:        "17"
		digest:     ""
	}
}

// Default: no resourceName, no expose.name — both names stay instance-scoped.
_testSTSDefaultComponent: {
	#instance: {name: "shop", namespace: "apps", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#Expose

	metadata: {
		name: "db"
		labels: "core.opmodel.dev/workload-type": "stateful"
	}

	spec: {
		container: _testSTSContainer
		expose: {
			type:      "ClusterIP"
			clusterIP: "None"
			ports: pg: {
				targetPort: 5432
			}
		}
	}
}

_testSTSDefaultTransformer: (#StatefulsetTransformer.#transform & {
	#component: _testSTSDefaultComponent
	#context:   _testSTSContext
}).output

_testSTSDefaultName:        "\(_testSTSDefaultTransformer.metadata.name)" & "shop-db"
_testSTSDefaultServiceName: "\(_testSTSDefaultTransformer.spec.serviceName)" & "shop-db"

// serviceName names the GOVERNING SERVICE, so it follows expose.name through
// #ServiceName, the seam the Service transformer renders through (0019 D22).
//
// resourceName and expose.name are set to DIFFERENT values on purpose.
// metadata.resourceName moves #names.dns.short along with the object name,
// so the Expose wrapper would default the Service to "database" as well; the
// explicit expose.name wins over that default, and the StatefulSet must point
// at the Service that actually renders, not at its own name. If serviceName
// ever collapses onto metadata.name, the second assertion fails.
_testSTSExactComponent: {
	#instance: {name: "shop", namespace: "apps", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#Expose

	metadata: {
		name:         "db"
		resourceName: "database"
		labels: "core.opmodel.dev/workload-type": "stateful"
	}

	spec: {
		container: _testSTSContainer
		expose: {
			type:      "ClusterIP"
			clusterIP: "None"
			name:      "database-headless"
			ports: pg: {
				targetPort: 5432
			}
		}
	}
}

_testSTSExactTransformer: (#StatefulsetTransformer.#transform & {
	#component: _testSTSExactComponent
	#context:   _testSTSContext
}).output

_testSTSExactName:        "\(_testSTSExactTransformer.metadata.name)" & "database"
_testSTSExactServiceName: "\(_testSTSExactTransformer.spec.serviceName)" & "database-headless"

// ---- Update strategy: declared value must reach spec.updateStrategy ---------
//
// Regression guard for the same alpha.8 bug fixed in this file and in
// deployment_transformer.cue: `_updateStrategy: *null | { if ... }` always
// resolved to its marked default, so the field was omitted from every
// StatefulSet. jellystat's bundled Postgres asks for OnDelete-style handling
// via Recreate and had been silently rolling instead.
//
// OnDelete rather than RollingUpdate on purpose: RollingUpdate is also the
// Kubernetes default, so a test using it would pass against the broken code.
_testSTSStrategyComponent: {
	#instance: {name: "shop", namespace: "apps", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#UpdateStrategy

	metadata: {
		name: "db"
		labels: "core.opmodel.dev/workload-type": "stateful"
	}

	spec: {
		container: _testSTSContainer
		updateStrategy: type: "OnDelete"
	}
}

_testSTSStrategyTransformer: (#StatefulsetTransformer.#transform & {
	#component: _testSTSStrategyComponent
	#context:   _testSTSContext
}).output

// One-element-list form, NOT interpolation. The failure mode is an ABSENT
// field, and `"\(x.spec.updateStrategy.type)" & "OnDelete"` does not catch that
// — an absent field is merely incomplete and plain `cue vet` accepts it
// (verified by reintroducing the bug). A list-length conflict fails at every
// vet level.
_testSTSStrategyPresent: [
	if _testSTSStrategyTransformer.spec.updateStrategy != _|_ {
		_testSTSStrategyTransformer.spec.updateStrategy.type
	},
] & ["OnDelete"]

// A component declaring no strategy must not grow one.
_testSTSNoStrategyLeak: [
	if _testSTSExactTransformer.spec.updateStrategy != _|_ {"leaked"},
] & []

// ---- Update strategy: omitted rollingUpdate params must not fail ------------
//
// Same regression family as deployment_transformer.cue: the extraction
// dereferenced `spec.updateStrategy.rollingUpdate` unguarded whenever type was
// RollingUpdate, but #UpdateStrategySchema leaves the substruct optional — a
// schema-legal `updateStrategy: type: "RollingUpdate"` with no partition/surge
// parameters failed the whole transform with an empty disjunction.
_testSTSRollingDefaultsComponent: {
	#instance: {name: "shop", namespace: "apps", uuid: "00000000-0000-0000-0000-000000000000"}

	res.#Container
	tr.#UpdateStrategy

	metadata: {
		name: "db"
		labels: "core.opmodel.dev/workload-type": "stateful"
	}

	spec: {
		container: _testSTSContainer
		updateStrategy: type: "RollingUpdate"
	}
}

_testSTSRollingDefaultsTransformer: (#StatefulsetTransformer.#transform & {
	#component: _testSTSRollingDefaultsComponent
	#context:   _testSTSContext
}).output

// The strategy is emitted with its type...
_testSTSRollingDefaultsPresent: [
	if _testSTSRollingDefaultsTransformer.spec.updateStrategy != _|_ {
		_testSTSRollingDefaultsTransformer.spec.updateStrategy.type
	},
] & ["RollingUpdate"]

// ...and no rollingUpdate block is invented for the omitted substruct.
_testSTSRollingDefaultsNoParams: [
	if _testSTSRollingDefaultsTransformer.spec.updateStrategy.rollingUpdate != _|_ {"leaked"},
] & []

// Cross-transformer consistency: serviceName names the governing Service, so
// it must equal the name the Service transformer rendered for the SAME stub.
_testStatefulSetServiceNameMatchesService: "\(_testSTSDefaultTransformer.spec.serviceName)" &
	"\((#ServiceTransformer.#transform & {
		#component: _testSTSDefaultComponent
		#context:   _testSTSContext
	}).output.metadata.name)"

// Without #Expose the fallback arm is a read of the component's own short DNS
// name, the value a default-named headless Service would carry.
_testSTSNoExposeServiceName: "\(_testSTSStrategyTransformer.spec.serviceName)" & "\(_testSTSStrategyComponent.#names.dns.short)" & "shop-db"

// Legacy shape: a stateful component compiled against a build <= alpha.5,
// whose expose carries `name?: string` unset (the wrapper set no default).
// expose is hand-written on purpose: embedding tr.#Expose gives `name!`.
// Container and #instance are current: their shapes did not move.
_testSTSLegacyExposeComponent: {
	res.#Container

	#instance: {name: "shop", namespace: "apps", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name: "db"
		labels: "core.opmodel.dev/workload-type": "stateful"
	}

	spec: {
		container: _testSTSContainer
		expose: {
			type:      "ClusterIP"
			clusterIP: "None"
			ports: pg: {name: "pg", targetPort: 5432, protocol: "TCP"}
			name?: string
		}
	}
}

_testSTSLegacyExposeTransformer: (#StatefulsetTransformer.#transform & {
	#component: _testSTSLegacyExposeComponent
	#context:   _testSTSContext
}).output

// serviceName must be the name the #ServiceTransformer renders for the same
// legacy stub: the instance-scoped default the >= alpha.6 wrapper would have set.
_testSTSLegacyExposeServiceName: "\(_testSTSLegacyExposeTransformer.spec.serviceName)" & "\((#ServiceTransformer.#transform & {
	#component: _testSTSLegacyExposeComponent
	#context:   _testSTSContext
}).output.metadata.name)" & "shop-db"
