// Hand-written minimal velero.io/v1 Schedule (experiment 01 plus hooks,
// resourcePolicy, storageLocation, snapshotMoveData), from
// research/velero.md sections 2, 3, 6.
package v1

#Schedule: {
	apiVersion: "velero.io/v1"
	kind:       "Schedule"
	metadata: {
		name!:      string
		namespace!: string
		labels?: [string]:      string
		annotations?: [string]: string
	}
	spec: {
		schedule!: string
		paused?:   bool
		template: {
			includedNamespaces?: [...string]
			labelSelector?: matchLabels?: [string]: string
			ttl?:                      string & =~"^[0-9]+h$"
			snapshotVolumes?:          bool
			snapshotMoveData?:         bool
			defaultVolumesToFsBackup?: bool
			storageLocation?:          string
			resourcePolicy?: {kind: "configmap", name!: string}
			hooks?: resources?: [...#HookResource]
		}
	}
}

#HookResource: {
	name!: string
	labelSelector?: matchLabels?: [string]: string
	pre?: [...#Hook]
	post?: [...#Hook]
}

#Hook: exec: {
	container!: string
	command!: [string, ...string]
	onError?: "Fail" | "Continue"
	timeout?: string
}
