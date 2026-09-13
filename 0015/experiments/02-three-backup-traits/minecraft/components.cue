package minecraft

import (
	bp "opmodel.dev/catalogs/opm/blueprints/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/exp02/contracts/traits/v1alpha1"
)

_data: {
	name:      "data"
	mountPath: "/data"
	readOnly:  false
	persistentClaim: {size: "20Gi", accessMode: "ReadWriteOnce", storageClass: "standard"}
}

// The itzg sequence as one command: quiesce, flush, stream, release.
// rcon-cli --host works from the live container and from a pod beside it.
_produce: "rcon-cli --host mc-demo-server save-off && rcon-cli --host mc-demo-server save-all flush && sync && tar -C /data --exclude=*.jar --exclude=cache --exclude=logs -c . ; s=$?; rcon-cli --host mc-demo-server save-on; exit $s"

#components: {
	server: {
		bp.#StatefulWorkload
		#traits: {
			(tr.#BackupTrait.metadata.fqn): tr.#BackupTrait
			if #config.mode == "owned" {
				(tr.#BackupOwnedTrait.metadata.fqn): tr.#BackupOwnedTrait
			}
			if #config.mode == "producer" {
				(tr.#BackupProducerTrait.metadata.fqn): tr.#BackupProducerTrait
			}
		}

		metadata: name: "server"

		spec: {
			statefulWorkload: {
				container: {
					name:  "minecraft"
					image: #config.image
					env: EULA: value: "TRUE"
				}
				volumes: {
					data: _data
					if #config.mode == "producer" {
						// Landing volume for file-capturing engines.
						backups: {
							name:      "backups"
							mountPath: "/backups"
							readOnly:  false
							persistentClaim: {size: "20Gi", accessMode: "ReadWriteOnce", storageClass: "standard"}
						}
					}
				}
				if #config.mode == "owned" {
					// Shape B: the module's own capture loop. It reads the projected
					// policy by the conventional ConfigMap name and the platform's
					// repository Secret by the conventional Secret name.
					sidecarContainers: [{
						name: "backup"
						image: {repository: "docker.io/itzg/mc-backup", tag: "latest", digest: ""}
						env: {
							BACKUP_METHOD: value: "restic"
							RCON_HOST: value: "localhost"
						}
						envFrom: [
							{configMapRef: name: "mc-demo-server-backup-config"},
							{secretRef: name: "mc-backup-restic"},
						]
						volumeMounts: data: {name: "data", mountPath: "/data", readOnly: true, persistentClaim: _data.persistentClaim}
					}]
				}
				scaling: count: 1
				restartPolicy: "Always"
				updateStrategy: type: "RollingUpdate"
			}
			backup: {
				schedule:   "0 * * * *"
				retention:  {keepWithin: "20d"}
				repository: "mc-backup"
				capture:    "filesystem"
				excludes: ["*.jar", "cache", "logs", "*.tmp", "bluemap/web/maps/**"]
			}
			if #config.mode == "owned" {
				backupOwned: {
					format: "restic"
					// The itzg loop's own key names.
					envKeys: {schedule: "CRON_SCHEDULE", retention: "PRUNE_RESTIC_RETENTION", excludes: "EXCLUDES"}
				}
			}
			if #config.mode == "producer" {
				backupProducer: {
					container:     "minecraft"
					command:       _produce
					volumes: ["data"]
					landing: {volume: "backups", path: "world.tar"}
					fileExtension: ".tar"
					compensate: command: ["rcon-cli", "save-on"]
				}
			}
		}
	}
}
