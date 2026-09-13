// Hand-written minimal k8up.io/v1 Schedule (experiment 01 plus
// backend.envFrom, which is how job-wide restic excludes reach the
// backup container: RESTIC_EXCLUDE from a ConfigMap the adapter owns).
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
		backend?: {
			repoPasswordSecretRef!: #SecretKeyRef
			s3!: {
				endpoint!:                 string
				bucket!:                   string
				accessKeyIDSecretRef!:     #SecretKeyRef
				secretAccessKeySecretRef!: #SecretKeyRef
			}
			envFrom?: [...{configMapRef?: name!: string, secretRef?: name!: string}]
		}
		backup?: {
			schedule!: string
			labelSelectors?: [...#LabelSelector]
			tags?: [...string]
		}
		prune?: {
			schedule!:  string
			retention?: #Retention
		}
		check?: schedule!: string
	}
}

#SecretKeyRef: {name!: string, key!: string}
#LabelSelector: matchLabels?: [string]: string
#Retention: {
	keepLast?:    int
	keepHourly?:  int
	keepDaily?:   int
	keepWeekly?:  int
	keepMonthly?: int
	keepYearly?:  int
}
