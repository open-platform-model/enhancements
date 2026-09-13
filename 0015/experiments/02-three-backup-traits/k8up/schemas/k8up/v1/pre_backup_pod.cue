// Hand-written minimal k8up.io/v1 PreBackupPod (experiment 01's Schedule shape plus
// volumes, volumeMounts and affinity, so the producer pod can read the
// workload's PVCs read-only from the same node).
package v1

#PreBackupPod: {
	apiVersion: "k8up.io/v1"
	kind:       "PreBackupPod"
	metadata: {
		name!:      string
		namespace!: string
		labels?: [string]:      string
		annotations?: [string]: string
	}
	spec: {
		backupCommand!: string
		fileExtension?: string
		pod: spec: {
			containers!: [...#Container]
			volumes?: [...{name!: string, persistentVolumeClaim!: {claimName!: string, readOnly?: bool}}]
			affinity?: podAffinity?: requiredDuringSchedulingIgnoredDuringExecution?: [...{
				labelSelector: matchLabels: [string]: string
				topologyKey: string
			}]
			restartPolicy: "Never"
		}
	}
}

#Container: {
	name!:  string
	image!: string
	command?: [...string]
	env?: [...{name!: string, value!: string}]
	envFrom?: [...{secretRef?: name!: string, configMapRef?: name!: string}]
	volumeMounts?: [...{name!: string, mountPath!: string, readOnly?: bool}]
}
