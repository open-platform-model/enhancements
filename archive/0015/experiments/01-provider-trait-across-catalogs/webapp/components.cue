// Shape copied from cli/tests/fixtures/modules/podinfo/components.cue
// (bp.#StatelessWorkload answers the workload-type matching key; a raw
// res.#Container does not), plus res.#Volumes and the backup trait attached
// directly through #traits so `optional` can be narrowed from #config.
package webapp

import (
	bp "opmodel.dev/catalogs/opm/blueprints/v1beta1"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/contracts/traits/v1alpha1"
)

#components: {
	web: {
		bp.#StatelessWorkload
		res.#Volumes
		#traits: (tr.#BackupTrait.metadata.fqn): tr.#BackupTrait & {optional: #config.backupAdvisory}

		metadata: name: "web"

		spec: {
			statelessWorkload: {
				container: {
					name:  "web"
					image: #config.image
				}
				scaling: count: 1
				restartPolicy: "Always"
				updateStrategy: type: "RollingUpdate"
			}
			volumes: data: {
				readOnly: false
				persistentClaim: {
					size:         "1Gi"
					accessMode:   "ReadWriteOnce"
					storageClass: "standard"
				}
			}
			backup: {
				schedule: "0 2 * * *"
				retention: {keepDaily: 7, keepWeekly: 4}
			}
		}
	}
}
