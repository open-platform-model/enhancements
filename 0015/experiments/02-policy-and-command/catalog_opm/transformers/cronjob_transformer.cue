package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	"list"
	k8sbatchv1 "opmodel.dev/catalogs/opm/schemas/kubernetes/batch/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// CronJobTransformer converts scheduled task components to Kubernetes CronJobs
#CronJobTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "cronjob-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/cronjob-transformer@\(id.Version)"
		description:    "Converts scheduled task components to Kubernetes CronJobs"

		labels: {
			"core.opmodel.dev/workload-type": "scheduled-task"
			"core.opmodel.dev/resource-type": "cronjob"
		}
	}

	// Required label to match scheduled task workloads
	requiredLabels: {
		"core.opmodel.dev/workload-type": "scheduled-task"
	}

	// Required resources - Container MUST be present
	requiredResources: {
		(res.#ContainerResource.metadata.fqn): res.#ContainerResource
	}

	// Optional resources
	optionalResources: {
		(res.#VolumesResource.metadata.fqn): res.#VolumesResource
	}

	// Required traits - CronJobConfig is mandatory for CronJob
	requiredTraits: {
		(tr.#CronJobConfigTrait.metadata.fqn): tr.#CronJobConfigTrait
	}

	// Optional traits
	optionalTraits: {
		(tr.#RestartPolicyTrait.metadata.fqn):     tr.#RestartPolicyTrait
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
	}

	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext

		// Extract required Container resource
		_container: #component.spec.container

		// Extract required CronJobConfig trait
		_cronConfig: #component.spec.cronJobConfig

		// Apply defaults for optional RestartPolicy trait
		_restartPolicy: *"OnFailure" | string
		if #component.spec.restartPolicy != _|_ {
			_restartPolicy: #component.spec.restartPolicy
		}

		// Build main container: base conversion via helper, unified with trait fields
		_mainContainer: (#ToK8sContainer & {"in": _container}).out

		// Extract optional sidecar and init containers with defaults
		_sidecarContainers: [...]
		if #component.spec.sidecarContainers != _|_ {
			_sidecarContainers: #component.spec.sidecarContainers
		}

		_initContainers: [...]
		if #component.spec.initContainers != _|_ {
			_initContainers: #component.spec.initContainers
		}

		output: k8sbatchv1.#CronJob & {
			apiVersion: "batch/v1"
			kind:       "CronJob"
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
				schedule: _cronConfig.scheduleCron

				if _cronConfig.suspend != _|_ {
					suspend: _cronConfig.suspend
				}

				concurrencyPolicy: string | *"Allow"
				if _cronConfig.concurrencyPolicy != _|_ {
					concurrencyPolicy: _cronConfig.concurrencyPolicy
				}

				successfulJobsHistoryLimit: int | *3
				if _cronConfig.successfulJobsHistoryLimit != _|_ {
					successfulJobsHistoryLimit: _cronConfig.successfulJobsHistoryLimit
				}

				failedJobsHistoryLimit: int | *1
				if _cronConfig.failedJobsHistoryLimit != _|_ {
					failedJobsHistoryLimit: _cronConfig.failedJobsHistoryLimit
				}

				jobTemplate: {
					spec: {
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

								if #component.spec.securityContext != _|_ {
									let _sc = #component.spec.securityContext
									if _sc.runAsNonRoot != _|_ || _sc.runAsUser != _|_ || _sc.runAsGroup != _|_ || _sc.supplementalGroups != _|_ {
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

								// Volumes: map persistent claim volumes to PVC references
								if #component.spec.volumes != _|_ {
									volumes: [
										for vName, vol in #component.spec.volumes if vol.persistentClaim != _|_ {
											name: vol.name | *vName
											persistentVolumeClaim: claimName: vol.name | *vName
										},
									]
								}

								// Graceful shutdown: pod-level termination grace period
								if #component.spec.gracefulShutdown != _|_ {
									terminationGracePeriodSeconds: #component.spec.gracefulShutdown.terminationGracePeriodSeconds
								}
							}
						}
					}
				}
			}
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// Transformer fixtures never pass through #Module, so #instance is set by hand
// on the component stub; without it the resourceName default is incomplete and
// an interpolation guard passes vacuously under plain cue vet (see
// docs/name-constraints.md). cue eval -c on the guards is the gate.
_testCronJobContext: {
	#moduleInstanceMetadata: {
		name:      "batch"
		namespace: "jobs"
		fqn:       "opmodel.dev/catalogs/opm/batch@0.1.0"
		version:   "0.1.0"
		uuid:      "00000000-0000-0000-0000-000000000000"
	}
	#componentMetadata: name: "sync"
	#runtimeName: "opm-test"
	componentAnnotations: {}
}

_testCronJobContainer: {
	name: "sync"
	image: {
		repository: "alpine"
		tag:        "3.20"
		digest:     ""
	}
}

// Default naming: <instance>-<component>, read from #names.resourceName.
_testCronJobDefaultNameComponent: {
	res.#Container
	tr.#CronJobConfig

	#instance: {name: "batch", namespace: "jobs", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name: "sync"
		labels: "core.opmodel.dev/workload-type": "scheduled-task"
	}

	spec: {
		container: _testCronJobContainer
		cronJobConfig: scheduleCron: "0 * * * *"
	}
}

_testCronJobDefaultNameTransformer: (#CronJobTransformer.#transform & {
	#component: _testCronJobDefaultNameComponent
	#context:   _testCronJobContext
}).output

_testCronJobDefaultNameResolves: "\(_testCronJobDefaultNameTransformer.metadata.name)" & "batch-sync"

// Exact naming: metadata.resourceName renders verbatim.
_testCronJobExactNameComponent: {
	res.#Container
	tr.#CronJobConfig

	#instance: {name: "batch", namespace: "jobs", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name:         "sync"
		resourceName: "nightly-sync"
		labels: "core.opmodel.dev/workload-type": "scheduled-task"
	}

	spec: {
		container: _testCronJobContainer
		cronJobConfig: scheduleCron: "0 * * * *"
	}
}

_testCronJobExactNameTransformer: (#CronJobTransformer.#transform & {
	#component: _testCronJobExactNameComponent
	#context:   _testCronJobContext
}).output

_testCronJobExactNameResolves: "\(_testCronJobExactNameTransformer.metadata.name)" & "nightly-sync"
