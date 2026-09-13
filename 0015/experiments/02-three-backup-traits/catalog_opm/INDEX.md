# opm — Definition Index

CUE module: `opmodel.dev/catalogs/opm@v4`

---

## Project Structure

```
+-- blueprints/
|   +-- v1beta1/
+-- identity/
+-- resources/
|   +-- v1alpha1/
|   +-- v1beta1/
+-- schemas/
|   +-- kubernetes/
|       +-- apiextensions/
|       |   +-- v1/
|       +-- apps/
|       |   +-- v1/
|       +-- autoscaling/
|       |   +-- v2/
|       +-- batch/
|       |   +-- v1/
|       +-- core/
|       |   +-- v1/
|       +-- networking/
|       |   +-- v1/
|       +-- policy/
|           +-- v1/
+-- traits/
|   +-- v1beta1/
+-- transformers/
```

---

## Blueprints

### v1beta1

| Definition | File | Description |
|---|---|---|
| `#DaemonWorkload` | `blueprints/v1beta1/daemon_workload.cue` |  |
| `#DaemonWorkloadBlueprint` | `blueprints/v1beta1/daemon_workload.cue` |  |
| `#DaemonWorkloadSchema` | `blueprints/v1beta1/daemon_workload.cue` |  |
| `#ScheduledTaskWorkload` | `blueprints/v1beta1/scheduled_task_workload.cue` |  |
| `#ScheduledTaskWorkloadBlueprint` | `blueprints/v1beta1/scheduled_task_workload.cue` |  |
| `#ScheduledTaskWorkloadSchema` | `blueprints/v1beta1/scheduled_task_workload.cue` |  |
| `#StatefulWorkload` | `blueprints/v1beta1/stateful_workload.cue` |  |
| `#StatefulWorkloadBlueprint` | `blueprints/v1beta1/stateful_workload.cue` |  |
| `#StatefulWorkloadSchema` | `blueprints/v1beta1/stateful_workload.cue` |  |
| `#StatelessWorkload` | `blueprints/v1beta1/stateless_workload.cue` |  |
| `#StatelessWorkloadBlueprint` | `blueprints/v1beta1/stateless_workload.cue` |  |
| `#StatelessWorkloadSchema` | `blueprints/v1beta1/stateless_workload.cue` |  |
| `#TaskWorkload` | `blueprints/v1beta1/task_workload.cue` |  |
| `#TaskWorkloadBlueprint` | `blueprints/v1beta1/task_workload.cue` |  |
| `#TaskWorkloadSchema` | `blueprints/v1beta1/task_workload.cue` |  |

---

## Resources

### v1alpha1

| Definition | File | Description |
|---|---|---|
| `#AdmissionResourceRule` | `resources/v1alpha1/admission_policy.cue` |  |
| `#ValidatingAdmissionPolicies` | `resources/v1alpha1/admission_policy.cue` |  |
| `#ValidatingAdmissionPoliciesResource` | `resources/v1alpha1/admission_policy.cue` | CEL-based admission validation, the in-process alternative to a validating webhook: no serving certificate, no CA bundle, no availability coupling to a pod |
| `#ValidatingAdmissionPolicySchema` | `resources/v1alpha1/admission_policy.cue` |  |
| `#NamespaceSchema` | `resources/v1alpha1/namespace.cue` | Kubernetes Namespace, emitted with its exact name |
| `#Namespaces` | `resources/v1alpha1/namespace.cue` |  |
| `#NamespacesResource` | `resources/v1alpha1/namespace.cue` |  |
| `#MutatingWebhookConfigurationSchema` | `resources/v1alpha1/webhook.cue` |  |
| `#MutatingWebhookSchema` | `resources/v1alpha1/webhook.cue` | Mutating-only extension: the mutating admission API additionally supports reinvocationPolicy |
| `#MutatingWebhooks` | `resources/v1alpha1/webhook.cue` |  |
| `#MutatingWebhooksResource` | `resources/v1alpha1/webhook.cue` |  |
| `#ValidatingWebhookConfigurationSchema` | `resources/v1alpha1/webhook.cue` | The webhooks lists are declared per variant (not on the shared meta schema) so the mutating elements can carry reinvocationPolicy without fighting the closed base #WebhookSchema |
| `#ValidatingWebhooks` | `resources/v1alpha1/webhook.cue` |  |
| `#ValidatingWebhooksResource` | `resources/v1alpha1/webhook.cue` |  |
| `#WebhookConfigurationMetaSchema` | `resources/v1alpha1/webhook.cue` | Shared config-level metadata |
| `#WebhookSchema` | `resources/v1alpha1/webhook.cue` |  |

### v1beta1

| Definition | File | Description |
|---|---|---|
| `#ConfigMapSchema` | `resources/v1beta1/configmap.cue` | ConfigMap specification |
| `#ConfigMaps` | `resources/v1beta1/configmap.cue` |  |
| `#ConfigMapsResource` | `resources/v1beta1/configmap.cue` |  |
| `#ContentHash` | `resources/v1beta1/configmap.cue` | Deterministic 10-character hex hash of a string data map |
| `#ImmutableName` | `resources/v1beta1/configmap.cue` | K8s resource name for a ConfigMap |
| `#Container` | `resources/v1beta1/container.cue` |  |
| `#ContainerResource` | `resources/v1beta1/container.cue` |  |
| `#ContainerSchema` | `resources/v1beta1/container.cue` | Container specification |
| `#EnvFromSource` | `resources/v1beta1/container.cue` | Bulk injection source — inject all keys from a ConfigMap or Secret as env vars |
| `#EnvVarSchema` | `resources/v1beta1/container.cue` | Environment variable |
| `#FieldRefSchema` | `resources/v1beta1/container.cue` | Downward API field reference |
| `#GpuResourceSchema` | `resources/v1beta1/container.cue` | GPU extended resource claim |
| `#Image` | `resources/v1beta1/container.cue` | Image specification for container images |
| `#PortSchema` | `resources/v1beta1/container.cue` |  |
| `#ProbeSchema` | `resources/v1beta1/container.cue` | Probe specification used by liveness/readiness/startup probes |
| `#ResourceFieldRefSchema` | `resources/v1beta1/container.cue` | Container resource field reference |
| `#ResourceRequirementsSchema` | `resources/v1beta1/container.cue` |  |
| `#SecurityContextSchema` | `resources/v1beta1/container.cue` |  |
| `#CRDSchema` | `resources/v1beta1/crd.cue` | Kubernetes CustomResourceDefinition |
| `#CRDVersionSchema` | `resources/v1beta1/crd.cue` | A single version entry in a CRD |
| `#CRDs` | `resources/v1beta1/crd.cue` |  |
| `#CRDsResource` | `resources/v1beta1/crd.cue` |  |
| `#NonResourcePolicyRuleSchema` | `resources/v1beta1/role.cue` | ClusterRole (scope: "cluster") only — enforced in review/docs, not schema |
| `#PolicyRuleSchema` | `resources/v1beta1/role.cue` | Single RBAC permission rule, exactly one of the two k8s forms |
| `#ResourcePolicyRuleSchema` | `resources/v1beta1/role.cue` |  |
| `#Role` | `resources/v1beta1/role.cue` |  |
| `#RoleResource` | `resources/v1beta1/role.cue` |  |
| `#RoleSchema` | `resources/v1beta1/role.cue` |  |
| `#RoleSubjectSchema` | `resources/v1beta1/role.cue` | Role subject — embeds an identity directly via CUE reference |
| `#SecretSchema` | `resources/v1beta1/secret.cue` | Secret specification |
| `#Secrets` | `resources/v1beta1/secret.cue` |  |
| `#SecretsResource` | `resources/v1beta1/secret.cue` |  |
| `#ServiceAccount` | `resources/v1beta1/service_account.cue` |  |
| `#ServiceAccountResource` | `resources/v1beta1/service_account.cue` |  |
| `#ServiceAccountSchema` | `resources/v1beta1/service_account.cue` |  |
| `#WorkloadIdentitySchema` | `resources/v1beta1/service_account.cue` | Workload identity — used by #WorkloadIdentityTrait and as a #RoleSubjectSchema variant |
| `#EmptyDirSchema` | `resources/v1beta1/volume.cue` |  |
| `#ExternalObjectVolumeSourceSchema` | `resources/v1beta1/volume.cue` | Reference to a cluster object this module does not own, mounted by its exact name (never instance-prefixed) |
| `#FileMode` | `resources/v1beta1/volume.cue` |  |
| `#HostPathSchema` | `resources/v1beta1/volume.cue` | Mounts a file or directory from the host node |
| `#NFSVolumeSourceSchema` | `resources/v1beta1/volume.cue` | Mounts a directory from an NFS server |
| `#ObjectProjectionSchema` | `resources/v1beta1/volume.cue` |  |
| `#PersistentClaimSchema` | `resources/v1beta1/volume.cue` | To mount a CIFS/SMB share use a storageClass that matches a pre-installed SMB StorageClass (e |
| `#ProjectedSourceSchema` | `resources/v1beta1/volume.cue` | One entry in a projected volume |
| `#ProjectedVolumeSourceSchema` | `resources/v1beta1/volume.cue` | Combines several sources into a single mounted directory |
| `#SecretVolumeItemSchema` | `resources/v1beta1/volume.cue` |  |
| `#SecretVolumeSourceSchema` | `resources/v1beta1/volume.cue` |  |
| `#ServiceAccountTokenProjectionSchema` | `resources/v1beta1/volume.cue` | A short-lived, audience-bound ServiceAccount token |
| `#VolumeMountSchema` | `resources/v1beta1/volume.cue` | Volume mount spec — defines container mount point |
| `#VolumeSchema` | `resources/v1beta1/volume.cue` | Volume specification — defines storage source |
| `#Volumes` | `resources/v1beta1/volume.cue` |  |
| `#VolumesResource` | `resources/v1beta1/volume.cue` |  |

---

## Schemas

| Definition | File | Description |
|---|---|---|
| `#LabelsAnnotationsSchema` | `schemas/common.cue` | Labels and annotations schema |
| `#NameType` | `schemas/common.cue` | DNS label name type (RFC 1123) |
| `#VersionSchema` | `schemas/common.cue` | Semantic version schema |
| `#NormalizeCPU` | `schemas/quantity.cue` | #NormalizeCPU normalizes CPU input to Kubernetes canonical form |
| `#NormalizeMemory` | `schemas/quantity.cue` | #NormalizeMemory normalizes memory input to Kubernetes binary format |

### kubernetes/apiextensions/v1

| Definition | File | Description |
|---|---|---|
| `#CustomResourceColumnDefinition` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#CustomResourceDefinition` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#CustomResourceDefinitionList` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#CustomResourceDefinitionNames` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#CustomResourceDefinitionSpec` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#CustomResourceDefinitionVersion` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#CustomResourceSubresources` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#CustomResourceValidation` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |
| `#JSONSchemaProps` | `schemas/kubernetes/apiextensions/v1/types.cue` |  |

### kubernetes/apps/v1

| Definition | File | Description |
|---|---|---|
| `#ControllerRevision` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#ControllerRevisionList` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DaemonSet` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DaemonSetCondition` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DaemonSetList` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DaemonSetSpec` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DaemonSetStatus` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DaemonSetUpdateStrategy` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#Deployment` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DeploymentCondition` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DeploymentList` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DeploymentSpec` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DeploymentStatus` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#DeploymentStrategy` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#ReplicaSet` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#ReplicaSetCondition` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#ReplicaSetList` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#ReplicaSetSpec` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#ReplicaSetStatus` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#RollingUpdateDaemonSet` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#RollingUpdateDeployment` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#RollingUpdateStatefulSetStrategy` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSet` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSetCondition` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSetList` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSetOrdinals` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSetPersistentVolumeClaimRetentionPolicy` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSetSpec` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSetStatus` | `schemas/kubernetes/apps/v1/types.cue` |  |
| `#StatefulSetUpdateStrategy` | `schemas/kubernetes/apps/v1/types.cue` |  |

### kubernetes/autoscaling/v2

| Definition | File | Description |
|---|---|---|
| `#ContainerResourceMetricSource` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#ContainerResourceMetricStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#CrossVersionObjectReference` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#ExternalMetricSource` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#ExternalMetricStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HPAScalingPolicy` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HPAScalingRules` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HorizontalPodAutoscaler` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HorizontalPodAutoscalerBehavior` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HorizontalPodAutoscalerCondition` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HorizontalPodAutoscalerList` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HorizontalPodAutoscalerSpec` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#HorizontalPodAutoscalerStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#MetricIdentifier` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#MetricSpec` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#MetricStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#MetricTarget` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#MetricValueStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#ObjectMetricSource` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#ObjectMetricStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#PodsMetricSource` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#PodsMetricStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#ResourceMetricSource` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |
| `#ResourceMetricStatus` | `schemas/kubernetes/autoscaling/v2/types.cue` |  |

### kubernetes/batch/v1

| Definition | File | Description |
|---|---|---|
| `#CronJob` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#CronJobList` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#CronJobSpec` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#CronJobStatus` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#Job` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#JobCondition` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#JobList` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#JobSpec` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#JobStatus` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#JobTemplateSpec` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#PodFailurePolicy` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#PodFailurePolicyOnExitCodesRequirement` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#PodFailurePolicyOnPodConditionsPattern` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#PodFailurePolicyRule` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#SuccessPolicy` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#SuccessPolicyRule` | `schemas/kubernetes/batch/v1/types.cue` |  |
| `#UncountedTerminatedPods` | `schemas/kubernetes/batch/v1/types.cue` |  |

### kubernetes/core/v1

| Definition | File | Description |
|---|---|---|
| `#AWSElasticBlockStoreVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Affinity` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#AppArmorProfile` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#AttachedVolume` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#AzureDiskVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#AzureFilePersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#AzureFileVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Binding` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#CSIPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#CSIVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Capabilities` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#CephFSPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#CephFSVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#CinderPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#CinderVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ClientIPConfig` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ClusterTrustBundleProjection` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ComponentCondition` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ComponentStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ComponentStatusList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ConfigMap` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ConfigMapEnvSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ConfigMapKeySelector` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ConfigMapList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ConfigMapNodeConfigSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ConfigMapProjection` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ConfigMapVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Container` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerExtendedResourceRequest` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerImage` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerPort` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerResizePolicy` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerRestartRule` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerRestartRuleOnExitCodes` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerState` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerStateRunning` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerStateTerminated` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerStateWaiting` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ContainerUser` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#DaemonEndpoint` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#DownwardAPIProjection` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#DownwardAPIVolumeFile` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#DownwardAPIVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EmptyDirVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EndpointAddress` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EndpointPort` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EndpointSubset` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Endpoints` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EndpointsList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EnvFromSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EnvVar` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EnvVarSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EphemeralContainer` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EphemeralVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Event` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EventList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EventSeries` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#EventSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ExecAction` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#FCVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#FileKeySelector` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#FlexPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#FlexVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#FlockerVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#GCEPersistentDiskVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#GRPCAction` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#GitRepoVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#GlusterfsPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#GlusterfsVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#HTTPGetAction` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#HTTPHeader` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#HostAlias` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#HostIP` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#HostPathVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ISCSIPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ISCSIVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ImageVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#KeyToPath` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Lifecycle` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LifecycleHandler` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LimitRange` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LimitRangeItem` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LimitRangeList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LimitRangeSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LinuxContainerUser` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LoadBalancerIngress` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LoadBalancerStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LocalObjectReference` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#LocalVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ModifyVolumeStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NFSVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Namespace` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NamespaceCondition` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NamespaceList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NamespaceSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NamespaceStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Node` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeAddress` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeAffinity` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeCondition` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeConfigSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeConfigStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeDaemonEndpoints` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeFeatures` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeRuntimeHandler` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeRuntimeHandlerFeatures` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeSelector` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeSelectorRequirement` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeSelectorTerm` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeSwapStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#NodeSystemInfo` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ObjectFieldSelector` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ObjectReference` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolume` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeClaim` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeClaimCondition` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeClaimList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeClaimSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeClaimStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeClaimTemplate` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeClaimVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PersistentVolumeStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PhotonPersistentDiskVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Pod` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodAffinity` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodAffinityTerm` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodAntiAffinity` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodCertificateProjection` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodCondition` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodDNSConfig` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodDNSConfigOption` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodExtendedResourceClaimStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodIP` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodOS` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodReadinessGate` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodResourceClaim` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodResourceClaimStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodSchedulingGate` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodSecurityContext` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodTemplate` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodTemplateList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PodTemplateSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PortStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PortworxVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#PreferredSchedulingTerm` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Probe` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ProjectedVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#QuobyteVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#RBDPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#RBDVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ReplicationController` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ReplicationControllerCondition` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ReplicationControllerList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ReplicationControllerSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ReplicationControllerStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceClaim` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceFieldSelector` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceHealth` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceQuota` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceQuotaList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceQuotaSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceQuotaStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceRequirements` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ResourceStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SELinuxOptions` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ScaleIOPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ScaleIOVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ScopeSelector` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ScopedResourceSelectorRequirement` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SeccompProfile` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Secret` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SecretEnvSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SecretKeySelector` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SecretList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SecretProjection` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SecretReference` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SecretVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SecurityContext` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Service` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ServiceAccount` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ServiceAccountList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ServiceAccountTokenProjection` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ServiceList` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ServicePort` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ServiceSpec` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#ServiceStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SessionAffinityConfig` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#SleepAction` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#StorageOSPersistentVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#StorageOSVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Sysctl` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#TCPSocketAction` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Taint` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Toleration` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#TopologySelectorLabelRequirement` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#TopologySelectorTerm` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#TopologySpreadConstraint` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#TypedLocalObjectReference` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#TypedObjectReference` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#Volume` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#VolumeDevice` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#VolumeMount` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#VolumeMountStatus` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#VolumeNodeAffinity` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#VolumeProjection` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#VolumeResourceRequirements` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#VsphereVirtualDiskVolumeSource` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#WeightedPodAffinityTerm` | `schemas/kubernetes/core/v1/types.cue` |  |
| `#WindowsSecurityContextOptions` | `schemas/kubernetes/core/v1/types.cue` |  |

### kubernetes/networking/v1

| Definition | File | Description |
|---|---|---|
| `#HTTPIngressPath` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#HTTPIngressRuleValue` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IPAddress` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IPAddressList` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IPAddressSpec` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IPBlock` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#Ingress` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressBackend` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressClass` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressClassList` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressClassParametersReference` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressClassSpec` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressList` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressLoadBalancerIngress` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressLoadBalancerStatus` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressPortStatus` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressRule` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressServiceBackend` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressSpec` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressStatus` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#IngressTLS` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#NetworkPolicy` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#NetworkPolicyEgressRule` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#NetworkPolicyIngressRule` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#NetworkPolicyList` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#NetworkPolicyPeer` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#NetworkPolicyPort` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#NetworkPolicySpec` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#ParentReference` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#ServiceBackendPort` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#ServiceCIDR` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#ServiceCIDRList` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#ServiceCIDRSpec` | `schemas/kubernetes/networking/v1/types.cue` |  |
| `#ServiceCIDRStatus` | `schemas/kubernetes/networking/v1/types.cue` |  |

### kubernetes/policy/v1

| Definition | File | Description |
|---|---|---|
| `#Eviction` | `schemas/kubernetes/policy/v1/types.cue` |  |
| `#PodDisruptionBudget` | `schemas/kubernetes/policy/v1/types.cue` |  |
| `#PodDisruptionBudgetList` | `schemas/kubernetes/policy/v1/types.cue` |  |
| `#PodDisruptionBudgetSpec` | `schemas/kubernetes/policy/v1/types.cue` |  |
| `#PodDisruptionBudgetStatus` | `schemas/kubernetes/policy/v1/types.cue` |  |

---

## Traits

### v1beta1

| Definition | File | Description |
|---|---|---|
| `#CronJobConfig` | `traits/v1beta1/cron_job_config.cue` |  |
| `#CronJobConfigSchema` | `traits/v1beta1/cron_job_config.cue` |  |
| `#CronJobConfigTrait` | `traits/v1beta1/cron_job_config.cue` |  |
| `#DisruptionBudget` | `traits/v1beta1/disruption_budget.cue` |  |
| `#DisruptionBudgetSchema` | `traits/v1beta1/disruption_budget.cue` | Exactly one of minAvailable or maxUnavailable must be set |
| `#DisruptionBudgetTrait` | `traits/v1beta1/disruption_budget.cue` |  |
| `#EncryptionConfig` | `traits/v1beta1/encryption.cue` |  |
| `#EncryptionConfigSchema` | `traits/v1beta1/encryption.cue` |  |
| `#EncryptionConfigTrait` | `traits/v1beta1/encryption.cue` |  |
| `#Expose` | `traits/v1beta1/expose.cue` | Component wrapper: attaches the trait and supplies the Service name's default, the component's own short DNS name (0019 D22) |
| `#ExposeSchema` | `traits/v1beta1/expose.cue` | Service expose specification |
| `#ExposeTrait` | `traits/v1beta1/expose.cue` |  |
| `#GracefulShutdown` | `traits/v1beta1/graceful_shutdown.cue` |  |
| `#GracefulShutdownSchema` | `traits/v1beta1/graceful_shutdown.cue` |  |
| `#GracefulShutdownTrait` | `traits/v1beta1/graceful_shutdown.cue` |  |
| `#GrpcRoute` | `traits/v1beta1/grpc_route.cue` |  |
| `#GrpcRouteMatchSchema` | `traits/v1beta1/grpc_route.cue` |  |
| `#GrpcRouteRuleSchema` | `traits/v1beta1/grpc_route.cue` |  |
| `#GrpcRouteSchema` | `traits/v1beta1/grpc_route.cue` |  |
| `#GrpcRouteTrait` | `traits/v1beta1/grpc_route.cue` |  |
| `#HostIPC` | `traits/v1beta1/host_ipc.cue` |  |
| `#HostIPCTrait` | `traits/v1beta1/host_ipc.cue` | Enables hostIPC: true on the pod spec, sharing the node's IPC namespace |
| `#HostNetwork` | `traits/v1beta1/host_network.cue` |  |
| `#HostNetworkTrait` | `traits/v1beta1/host_network.cue` | Enables hostNetwork: true on the pod spec, sharing the node's network namespace |
| `#HostPID` | `traits/v1beta1/host_pid.cue` |  |
| `#HostPIDTrait` | `traits/v1beta1/host_pid.cue` | Enables hostPID: true on the pod spec, sharing the node's PID namespace |
| `#HttpRoute` | `traits/v1beta1/http_route.cue` |  |
| `#HttpRouteMatchSchema` | `traits/v1beta1/http_route.cue` |  |
| `#HttpRouteRuleSchema` | `traits/v1beta1/http_route.cue` |  |
| `#HttpRouteSchema` | `traits/v1beta1/http_route.cue` |  |
| `#HttpRouteTrait` | `traits/v1beta1/http_route.cue` |  |
| `#ImagePullSecrets` | `traits/v1beta1/image_pull_secrets.cue` |  |
| `#ImagePullSecretsSchema` | `traits/v1beta1/image_pull_secrets.cue` | References to pre-existing K8s Secrets |
| `#ImagePullSecretsTrait` | `traits/v1beta1/image_pull_secrets.cue` | References pre-existing K8s Secrets (type kubernetes |
| `#InitContainers` | `traits/v1beta1/init_containers.cue` |  |
| `#InitContainersSchema` | `traits/v1beta1/init_containers.cue` | Init container shape — alias of #ContainerSchema |
| `#InitContainersTrait` | `traits/v1beta1/init_containers.cue` |  |
| `#JobConfig` | `traits/v1beta1/job_config.cue` |  |
| `#JobConfigSchema` | `traits/v1beta1/job_config.cue` |  |
| `#JobConfigTrait` | `traits/v1beta1/job_config.cue` |  |
| `#NetworkPolicy` | `traits/v1beta1/network_policy.cue` |  |
| `#NetworkPolicyEgressRule` | `traits/v1beta1/network_policy.cue` |  |
| `#NetworkPolicyIngressRule` | `traits/v1beta1/network_policy.cue` | An empty rule (`{}`) means "allow all in this direction" — the idiom istiod uses for egress, because features like JWKS resolution need to reach user-defined endpoints |
| `#NetworkPolicyPeer` | `traits/v1beta1/network_policy.cue` |  |
| `#NetworkPolicyPort` | `traits/v1beta1/network_policy.cue` |  |
| `#NetworkPolicySchema` | `traits/v1beta1/network_policy.cue` |  |
| `#NetworkPolicyTrait` | `traits/v1beta1/network_policy.cue` | #NetworkPolicyTrait attaches an ingress/egress policy to a workload |
| `#PodMetadata` | `traits/v1beta1/pod_metadata.cue` |  |
| `#PodMetadataSchema` | `traits/v1beta1/pod_metadata.cue` | Pod-template metadata, distinct from the workload object's own metadata |
| `#PodMetadataTrait` | `traits/v1beta1/pod_metadata.cue` |  |
| `#PodScheduling` | `traits/v1beta1/pod_scheduling.cue` |  |
| `#PodSchedulingSchema` | `traits/v1beta1/pod_scheduling.cue` | Named `podScheduling`, not `scheduling`, because a one-character difference from the existing `scaling` trait is a reading hazard in module bodies |
| `#PodSchedulingTrait` | `traits/v1beta1/pod_scheduling.cue` |  |
| `#TolerationSchema` | `traits/v1beta1/pod_scheduling.cue` | A `key`-less toleration with operator "Exists" tolerates EVERY taint, which is why `key` is optional |
| `#RestartPolicy` | `traits/v1beta1/restart_policy.cue` |  |
| `#RestartPolicySchema` | `traits/v1beta1/restart_policy.cue` |  |
| `#RestartPolicyTrait` | `traits/v1beta1/restart_policy.cue` |  |
| `#RouteAttachmentSchema` | `traits/v1beta1/route_common.cue` | Shared attachment fields for route schemas (gateway, TLS, className) |
| `#RouteHeaderMatch` | `traits/v1beta1/route_common.cue` | Header match for route rules |
| `#RouteRuleBase` | `traits/v1beta1/route_common.cue` | Base fields shared by all route rules |
| `#RuntimeClass` | `traits/v1beta1/runtime_class.cue` |  |
| `#RuntimeClassTrait` | `traits/v1beta1/runtime_class.cue` | Selects the container runtime that executes the pod, by setting `runtimeClassName` on the pod spec |
| `#AutoscalingSpec` | `traits/v1beta1/scaling.cue` |  |
| `#MetricSpec` | `traits/v1beta1/scaling.cue` |  |
| `#MetricTargetSpec` | `traits/v1beta1/scaling.cue` |  |
| `#Scaling` | `traits/v1beta1/scaling.cue` |  |
| `#ScalingSchema` | `traits/v1beta1/scaling.cue` |  |
| `#ScalingTrait` | `traits/v1beta1/scaling.cue` |  |
| `#SecurityContext` | `traits/v1beta1/security_context.cue` |  |
| `#SecurityContextTrait` | `traits/v1beta1/security_context.cue` |  |
| `#SidecarContainers` | `traits/v1beta1/sidecar_containers.cue` |  |
| `#SidecarContainersSchema` | `traits/v1beta1/sidecar_containers.cue` | Sidecar container shape — alias of #ContainerSchema |
| `#SidecarContainersTrait` | `traits/v1beta1/sidecar_containers.cue` |  |
| `#Sizing` | `traits/v1beta1/sizing.cue` |  |
| `#SizingSchema` | `traits/v1beta1/sizing.cue` |  |
| `#SizingTrait` | `traits/v1beta1/sizing.cue` |  |
| `#VerticalScalingSchema` | `traits/v1beta1/sizing.cue` | Placeholder for future VPA support |
| `#TcpRoute` | `traits/v1beta1/tcp_route.cue` |  |
| `#TcpRouteRuleSchema` | `traits/v1beta1/tcp_route.cue` | No L7 match fields for TCP |
| `#TcpRouteSchema` | `traits/v1beta1/tcp_route.cue` |  |
| `#TcpRouteTrait` | `traits/v1beta1/tcp_route.cue` |  |
| `#TlsRoute` | `traits/v1beta1/tls_route.cue` |  |
| `#TlsRouteRuleSchema` | `traits/v1beta1/tls_route.cue` | No L7 match fields for TLS |
| `#TlsRouteSchema` | `traits/v1beta1/tls_route.cue` |  |
| `#TlsRouteTrait` | `traits/v1beta1/tls_route.cue` |  |
| `#UpdateStrategy` | `traits/v1beta1/update_strategy.cue` |  |
| `#UpdateStrategySchema` | `traits/v1beta1/update_strategy.cue` |  |
| `#UpdateStrategyTrait` | `traits/v1beta1/update_strategy.cue` |  |
| `#WorkloadIdentity` | `traits/v1beta1/workload_identity.cue` |  |
| `#WorkloadIdentityTrait` | `traits/v1beta1/workload_identity.cue` |  |

---

## Transformers

| Definition | File | Description |
|---|---|---|
| `#AdmissionPolicyTransformer` | `transformers/admission_policy_transformer.cue` | AdmissionPolicyTransformer converts ValidatingAdmissionPolicies resources to Kubernetes ValidatingAdmissionPolicy + ValidatingAdmissionPolicyBinding pairs |
| `#ConfigMapTransformer` | `transformers/configmap_transformer.cue` | ConfigMapTransformer converts ConfigMaps resources to Kubernetes ConfigMaps |
| `#ToK8sContainer` | `transformers/container_helpers.cue` | #ToK8sContainer converts an OPM #ContainerSchema to a Kubernetes #Container |
| `#ToK8sContainers` | `transformers/container_helpers.cue` | #ToK8sContainers converts a list of OPM containers to Kubernetes containers |
| `#ToK8sKeyToPath` | `transformers/container_helpers.cue` | #ToK8sKeyToPath converts OPM key/path/mode items to K8s KeyToPath entries |
| `#ToK8sObjectProjection` | `transformers/container_helpers.cue` | #ToK8sObjectProjection converts an OPM object projection (configMap or secret source inside a projected volume) to its K8s shape |
| `#ToK8sVolumes` | `transformers/container_helpers.cue` | #ToK8sVolumes converts OPM volumes map to Kubernetes volumes list |
| `#CRDTransformer` | `transformers/crd_transformer.cue` | CRDTransformer converts CRDs resources to Kubernetes CustomResourceDefinitions |
| `#CronJobTransformer` | `transformers/cronjob_transformer.cue` | CronJobTransformer converts scheduled task components to Kubernetes CronJobs |
| `#DaemonSetTransformer` | `transformers/daemonset_transformer.cue` | DaemonSetTransformer converts daemon workload components to Kubernetes DaemonSets |
| `#DeploymentTransformer` | `transformers/deployment_transformer.cue` | DeploymentTransformer converts stateless workload components to Kubernetes Deployments |
| `#GrpcRouteTransformer` | `transformers/grpc_route_transformer.cue` | GrpcRouteTransformer creates Gateway API GRPCRoutes from components with GrpcRoute and Expose traits |
| `#HPATransformer` | `transformers/hpa_transformer.cue` | HPATransformer realizes #ScalingTrait's `auto` block as a HorizontalPodAutoscaler |
| `#ToK8sMetricTarget` | `transformers/hpa_transformer.cue` | #ToK8sMetricTarget maps OPM's #MetricTargetSpec to a Kubernetes MetricTarget |
| `#HttpRouteTransformer` | `transformers/http_route_transformer.cue` | HttpRouteTransformer creates Gateway API HTTPRoutes from components with HttpRoute and Expose traits |
| `#JobTransformer` | `transformers/job_transformer.cue` | JobTransformer converts task workload components to Kubernetes Jobs |
| `#MutatingWebhookTransformer` | `transformers/mutating_webhook_transformer.cue` | MutatingWebhookTransformer converts MutatingWebhooks resources to Kubernetes MutatingWebhookConfigurations |
| `#ServiceName` | `transformers/name_helpers.cue` | #ServiceName resolves the name of the Service an Expose component renders: expose |
| `#NamespaceTransformer` | `transformers/namespace_transformer.cue` | NamespaceTransformer converts Namespaces resources to Kubernetes Namespaces |
| `#NetworkPolicyTransformer` | `transformers/network_policy_transformer.cue` | NetworkPolicyTransformer converts the #NetworkPolicyTrait to a Kubernetes NetworkPolicy whose podSelector is the workload's own rendered pod labels |
| `#PDBTransformer` | `transformers/pdb_transformer.cue` | PDBTransformer realizes #DisruptionBudgetTrait as a PodDisruptionBudget |
| `#PodSchedulingFields` | `transformers/pod_helpers.cue` | Pod-spec scheduling fields from #PodSchedulingTrait |
| `#PodTemplateMetadata` | `transformers/pod_helpers.cue` | Pod-template metadata: context labels merged with #PodMetadataTrait labels, plus pod-only annotations |
| `#PVCTransformer` | `transformers/pvc_transformer.cue` | PVCTransformer creates standalone PersistentVolumeClaims from Volume resources |
| `#RoleTransformer` | `transformers/role_transformer.cue` | RoleTransformer converts OPM Role resources to Kubernetes RBAC objects |
| `#ToK8sServiceAccount` | `transformers/sa_helpers.cue` | #ToK8sServiceAccount converts an OPM identity spec (either #WorkloadIdentitySchema or #ServiceAccountSchema — both share the same shape) to a Kubernetes ServiceAccount |
| `#ServiceAccountResourceTransformer` | `transformers/sa_resource_transformer.cue` | ServiceAccountResourceTransformer converts standalone ServiceAccount resources to Kubernetes ServiceAccounts |
| `#SecretTransformer` | `transformers/secret_transformer.cue` | SecretTransformer converts Secrets resources to Kubernetes Secrets |
| `#ServiceTransformer` | `transformers/service_transformer.cue` | ServiceTransformer creates Kubernetes Services from components with Expose trait |
| `#StatefulsetTransformer` | `transformers/statefulset_transformer.cue` | StatefulsetTransformer converts stateful workload components to Kubernetes StatefulSets |
| `#TcpRouteTransformer` | `transformers/tcp_route_transformer.cue` | TcpRouteTransformer creates Gateway API TCPRoutes from components with TcpRoute and Expose traits |
| `#TlsRouteTransformer` | `transformers/tls_route_transformer.cue` | TlsRouteTransformer creates Gateway API TLSRoutes from components with TlsRoute and Expose traits |
| `#ValidatingWebhookTransformer` | `transformers/validating_webhook_transformer.cue` | ValidatingWebhookTransformer converts ValidatingWebhooks resources to Kubernetes ValidatingWebhookConfigurations |

---

