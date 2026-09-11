// Hand-written minimal k8up.io/v1 Schedule, from the fields this
// experiment renders (docs.k8up.io object-specifications, k8up source
// api/v1/backup_types.go BackupSpec.LabelSelectors). Definitions are closed:
// `spec.backend` is deliberately NOT declared, so a backend on the rendered
// object is a type error. That is credential shape 1 made structural: the
// operator's BACKUP_GLOBAL* env supplies repository and credentials.
package v1

#Schedule: {
	apiVersion: "k8up.io/v1"
	kind:       "Schedule"
	metadata: {
		name!:      string
		namespace!: string
		labels?: [string]:      string
		annotations?: [string]: string
	}
	spec: {
		backup?: {
			schedule!: string
			labelSelectors?: [...#LabelSelector]
			tags?: [...string]
			failedJobsHistoryLimit?:     int
			successfulJobsHistoryLimit?: int
		}
		prune?: {
			schedule!:  string
			retention?: #Retention
		}
		check?: schedule!: string
	}
}

#LabelSelector: {
	matchLabels?: [string]: string
}

#Retention: {
	keepLast?:    int
	keepHourly?:  int
	keepDaily?:   int
	keepWeekly?:  int
	keepMonthly?: int
	keepYearly?:  int
	keepTags?: [...string]
}
