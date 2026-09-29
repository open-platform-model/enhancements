// k8up provider for the `backup` policy contract, in three modes:
//   executor: module -> the policy projection (contracts/projection) plus
//                       prune + check ONLY, against the module's own repo
//   + backup-command -> backup of the adapter's PreBackupPod stream only
//   otherwise        -> file-level backup of the selected (or all) PVCs
// Repository by name from the platform table; excludes as a ConfigMap
// through backend.envFrom; keepWithin -> keepHourly.
package transformers

import (
	"list"
	"strconv"
	"strings"

	id "testing.opmodel.dev/experiments/0015/exp02/k8up/identity"
	cfg "testing.opmodel.dev/experiments/0015/exp02/contracts/config"
	proj "testing.opmodel.dev/experiments/0015/exp02/contracts/projection"
	k8upv1 "testing.opmodel.dev/experiments/0015/exp02/k8up/schemas/k8up/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/exp02/contracts/traits/v1alpha1"
)

#TargetLabel: "backup.k8up.opmodel.dev/target"
#VolumeLabel: "volume.opmodel.dev/name"

#WithinHours: {
	X="in": string
	_n:     strconv.Atoi(strings.TrimRight(X, "hdw"))
	out: [
		if strings.HasSuffix(X, "h") {_n},
		if strings.HasSuffix(X, "d") {_n * 24},
		if strings.HasSuffix(X, "w") {_n * 168},
	][0]
}

#BackupScheduleTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "backup-schedule-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/backup-schedule-transformer@\(id.Version)"
		description:    "Renders the backup policy as a K8up Schedule: volumes, a command's stream, or projection plus maintenance when the module executes"
		labels: "core.opmodel.dev/resource-type": "schedule"
	}

	requiredResources: (res.#VolumesResource.metadata.fqn): res.#VolumesResource
	requiredTraits: (tr.#BackupTrait.metadata.fqn):         tr.#BackupTrait
	optionalTraits: (tr.#BackupCommandTrait.metadata.fqn): tr.#BackupCommandTrait

	#transform: {
		#component: _
		#context:   c.#TransformerContext
		_backup:    #component.spec.backup
		_r:         _backup.retention
		_name:      #component.#names.resourceName
		_instance:  #context.#moduleInstanceMetadata.name

		_command: [if #component.spec.backupCommand != _|_ {#component.spec.backupCommand}, {}][0]
		_maint: [if _backup.maintenance != _|_ {_backup.maintenance}, {}][0]
		_volumes: [if _backup.volumes != _|_ {_backup.volumes}, []][0]
		_excludes: [if _backup.excludes != _|_ {_backup.excludes}, []][0]
		_repo: [if _backup.repository != _|_ {cfg.repositories[_backup.repository]}, {}][0]

		_isOwned:   _backup.executor == "module"
		_isCommand: _command.command != _|_

		_selectors: list.Concat([
			[if _isCommand {{matchLabels: (#TargetLabel): _name}}],
			[if !_isCommand for v in _volumes {{matchLabels: {for k, l in #context.componentLabels {(k): l}, (#VolumeLabel): v}}}],
			[if !_isCommand if len(_volumes) == 0 {{matchLabels: #context.componentLabels}}],
		])

		_retention: {
			for k, v in _r if k != "keepWithin" {(k): v}
			if _r.keepWithin != _|_ {
				keepHourly: (#WithinHours & {"in": _r.keepWithin}).out
			}
		}

		_schedule: k8upv1.#Schedule & {
			metadata: {
				name:      _name
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels & {(#TargetLabel): _name}
			}
			spec: {
				if _repo.s3 != _|_ {
					backend: {
						repoPasswordSecretRef: {name: _repo.secretName, key: "RESTIC_PASSWORD"}
						s3: {
							endpoint: _repo.s3.endpoint
							bucket:   "\(_repo.s3.bucket)/\(_instance)"
							accessKeyIDSecretRef: {name:     _repo.secretName, key: "AWS_ACCESS_KEY_ID"}
							secretAccessKeySecretRef: {name: _repo.secretName, key: "AWS_SECRET_ACCESS_KEY"}
						}
						if !_isOwned if len(_excludes) > 0 {
							envFrom: [{configMapRef: name: "\(_name)-backup-excludes"}]
						}
					}
				}
				// executor: module: the module's sidecar takes the backups; k8up
				// only maintains the repository it writes (same restic format,
				// host pinned to the namespace by the projection).
				if !_isOwned {
					backup: {
						schedule:       _backup.schedule
						labelSelectors: _selectors
						tags: [_instance, #context.#componentMetadata.name]
					}
				}
				prune: {
					schedule:  [if _maint.pruneSchedule != _|_ {_maint.pruneSchedule}, "@daily-random"][0]
					retention: _retention
				}
				check: schedule: [if _maint.checkSchedule != _|_ {_maint.checkSchedule}, "@weekly-random"][0]
			}
		}

		_excludesConfigMap: {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: {
				name:      "\(_name)-backup-excludes"
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
			}
			data: RESTIC_EXCLUDE: strings.Join(_excludes, ",")
		}

		_projection: (proj.#ConfigMap & {
			#backup:    _backup
			#repo:      _repo
			#name:      _name
			#instance:  _instance
			#namespace: #context.#moduleInstanceMetadata.namespace
			#labels:    #context.labels
		}).out

		output: list.Concat([
			[_schedule],
			[if !_isOwned if len(_excludes) > 0 {_excludesConfigMap}],
			[if _isOwned {_projection}],
		])
	}
}
