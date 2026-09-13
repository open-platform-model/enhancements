// The policy projection for backup-owned, rendered by the DECLARING
// catalog on every platform. Requires only the catalog-fulfilled
// backup-owned contract: requiring `backup` here would make this catalog
// a second provider of it under the exactly-one-provider rule, so the
// policy is READ off the component without being required.
package transformers

import (
	"strings"

	id "testing.opmodel.dev/experiments/0015/exp02/contracts/identity"
	cfg "testing.opmodel.dev/experiments/0015/exp02/contracts/config"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/exp02/contracts/traits/v1alpha1"
)

#ResticFlags: {
	keepLast:    "--keep-last"
	keepHourly:  "--keep-hourly"
	keepDaily:   "--keep-daily"
	keepWeekly:  "--keep-weekly"
	keepMonthly: "--keep-monthly"
	keepYearly:  "--keep-yearly"
	keepWithin:  "--keep-within"
}

#BackupConfigTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "backup-config-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/backup-config-transformer@\(id.Version)"
		description:    "Projects the backup policy into a ConfigMap a module-owned backup tool reads"
		labels: "core.opmodel.dev/resource-type": "configmap"
	}

	requiredResources: (res.#ContainerResource.metadata.fqn): res.#ContainerResource
	requiredTraits: (tr.#BackupOwnedTrait.metadata.fqn):      tr.#BackupOwnedTrait

	#transform: {
		#component: _
		#context:   c.#TransformerContext
		_owned:     #component.spec.backupOwned
		_backup:    #component.spec.backup
		_name:      #component.#names.resourceName
		_instance:  #context.#moduleInstanceMetadata.name
		_keys:      _owned.envKeys

		_repo: [if _backup.repository != _|_ {cfg.repositories[_backup.repository]}, {}][0]
		_flags: [if _backup.retention != _|_ for k, v in _backup.retention {"\(#ResticFlags[k]) \(v)"}]
		_excludes: [if _backup.excludes != _|_ {_backup.excludes}, []][0]

		output: {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: {
				// The conventional name a module's sidecar reads via envFrom.
				name:      "\(_name)-backup-config"
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
			}
			data: {
				if _repo.s3 != _|_ {
					RESTIC_REPOSITORY: "s3:\(_repo.s3.endpoint)/\(_repo.s3.bucket)/\(_instance)"
				}
				// Pinned to the namespace so an engine's `forget --host` (k8up)
				// sees the module's snapshots.
				RESTIC_HOSTNAME: #context.#moduleInstanceMetadata.namespace
				if _backup.schedule != _|_ {
					(_keys.schedule): _backup.schedule
				}
				if len(_flags) > 0 {
					(_keys.retention): strings.Join(_flags, " ")
				}
				if len(_excludes) > 0 {
					(_keys.excludes): strings.Join(_excludes, ",")
				}
			}
		}
	}
}
