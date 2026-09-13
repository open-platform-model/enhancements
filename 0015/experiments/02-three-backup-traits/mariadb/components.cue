// Shape A for a database: the producer streams a logical dump over the
// service name (works from the engine's own pod and from the live
// container alike); `landing` names the volume file-capturing engines
// write it to. `data` is never captured by either engine.
package mariadb

import (
	bp "opmodel.dev/catalogs/opm/blueprints/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/exp02/contracts/traits/v1alpha1"
)

#components: {
	db: {
		bp.#StatefulWorkload
		#traits: {
			(tr.#BackupTrait.metadata.fqn):         tr.#BackupTrait
			(tr.#BackupProducerTrait.metadata.fqn): tr.#BackupProducerTrait
		}

		metadata: name: "db"

		spec: {
			statefulWorkload: {
				container: {
					name:  "mariadb"
					image: #config.image
					env: MARIADB_DATABASE: value: "app"
					envFrom: [{secretRef: name: #config.rootSecretName}]
				}
				volumes: {
					data: {
						name:      "data"
						mountPath: "/var/lib/mysql"
						readOnly:  false
						persistentClaim: {size: "2Gi", accessMode: "ReadWriteOnce", storageClass: "standard"}
					}
					dumps: {
						name:      "dumps"
						mountPath: "/dumps"
						readOnly:  false
						persistentClaim: {size: "1Gi", accessMode: "ReadWriteOnce", storageClass: "standard"}
					}
				}
				scaling: count: 1
				restartPolicy: "Always"
				updateStrategy: type: "RollingUpdate"
			}
			backup: {
				schedule:   "0 2 * * *"
				retention:  {keepDaily: 7, keepWeekly: 4, keepMonthly: 6}
				repository: "mc-backup"
				maintenance: {pruneSchedule: "0 3 * * 0", checkSchedule: "0 4 * * 0"}
			}
			backupProducer: {
				container: "mariadb"
				command:   "mariadb-dump --single-transaction --routines --events --triggers --databases app -h mariadb-demo-db -uroot -p\"$MARIADB_ROOT_PASSWORD\""
				landing: {volume: "dumps", path: "app.sql"}
			}
		}
	}
}
