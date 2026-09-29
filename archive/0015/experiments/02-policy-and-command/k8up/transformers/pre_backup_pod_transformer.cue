// k8up provider for backup-command: a PreBackupPod built from the named
// container, mounting the command's volumes read-only and pinned beside
// the workload (RWO PVCs mount on one node; k8up's own folder backup pins
// the same way). Stdout is the snapshot; `landing` is ignored.
package transformers

import (
	id "testing.opmodel.dev/experiments/0015/exp02/k8up/identity"
	k8upv1 "testing.opmodel.dev/experiments/0015/exp02/k8up/schemas/k8up/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/exp02/contracts/traits/v1alpha1"
)

#PreBackupPodTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "pre-backup-pod-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/pre-backup-pod-transformer@\(id.Version)"
		description:    "Renders backup-command as a K8up PreBackupPod beside the workload, its volumes mounted read-only"
		labels: "core.opmodel.dev/resource-type": "prebackuppod"
	}

	requiredResources: (res.#ContainerResource.metadata.fqn): res.#ContainerResource
	requiredTraits: (tr.#BackupCommandTrait.metadata.fqn):    tr.#BackupCommandTrait

	#transform: {
		#component: _
		#context:   c.#TransformerContext
		_p:         #component.spec.backupCommand
		_name:      #component.#names.resourceName
		_instance:  #context.#moduleInstanceMetadata.name
		_ctr:       #component.spec.container
		_nameOK:    _ctr.name & _p.container
		_vols: [if _p.volumes != _|_ {_p.volumes}, []][0]

		output: k8upv1.#PreBackupPod & {
			metadata: {
				name:      "\(_name)-command"
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels & {(#TargetLabel): _name}
			}
			spec: {
				// The contract's command line, run by a shell (k8up adds none).
				backupCommand: "sh -c '\(_p.command)'"
				fileExtension: "-\(_instance)-\(#context.#componentMetadata.name)\(_p.fileExtension)"
				pod: spec: {
					containers: [{
						name:  _ctr.name
						image: _ctr.image.reference
						command: ["sleep", "infinity"]
						if _ctr.env != _|_ {
							env: [for k, e in _ctr.env if e.value != _|_ {name: k, value: e.value}]
						}
						if _ctr.envFrom != _|_ {
							envFrom: _ctr.envFrom
						}
						if len(_vols) > 0 {
							volumeMounts: [for v in _vols {
								name: v
								// The workload's own mount path, so the command is the
								// same in both pods; /mnt/<v> when it has none.
								mountPath: [if #component.spec.volumes[v].mountPath != _|_ {#component.spec.volumes[v].mountPath}, "/mnt/\(v)"][0]
								readOnly:  true
							}]
						}
					}]
					if len(_vols) > 0 {
						// PVC names as the base catalog's pvc-transformer renders them.
						volumes: [for v in _vols {
							name: v
							persistentVolumeClaim: {claimName: "\(_instance)-\(#context.#componentMetadata.name)-\(v)", readOnly: true}
						}]
						affinity: podAffinity: requiredDuringSchedulingIgnoredDuringExecution: [{
							labelSelector: matchLabels: #context.componentLabels
							topologyKey: "kubernetes.io/hostname"
						}]
					}
				}
			}
		}
	}
}
