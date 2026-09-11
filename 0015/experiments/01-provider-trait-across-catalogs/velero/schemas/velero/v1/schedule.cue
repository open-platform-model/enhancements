// Hand-written minimal velero.io/v1 Schedule from the fields this
// experiment renders (velero.io/docs/v1.18/api-types/schedule). Storage
// location, snapshot locations and volume mode are platform config and
// are left unset here.
package v1

#Schedule: {
	apiVersion: "velero.io/v1"
	kind:       "Schedule"
	metadata: {
		name!:      string
		namespace!: string
		labels?: [string]: string
	}
	spec: {
		schedule!: string
		paused?:   bool
		template: {
			includedNamespaces?: [...string]
			labelSelector?: matchLabels?: [string]: string
			ttl?:                      string & =~"^[0-9]+h$"
			snapshotVolumes?:          bool
			defaultVolumesToFsBackup?: bool
			storageLocation?:          string
		}
	}
}
