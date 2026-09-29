// Velero provider for `backup`, with backup-command folded in as a
// pre-hook that writes the artefact into the landing volume (the only
// volume then captured). executor: module renders the policy projection
// and nothing else: Velero has no maintenance for a module's restic
// repository. Admin-scoped (design doc P2).
package transformers

import (
	"encoding/yaml"
	"list"
	"strconv"
	"strings"

	id "testing.opmodel.dev/experiments/0015/exp02/velero/identity"
	cfg "testing.opmodel.dev/experiments/0015/exp02/contracts/config"
	proj "testing.opmodel.dev/experiments/0015/exp02/contracts/projection"
	velerov1 "testing.opmodel.dev/experiments/0015/exp02/velero/schemas/velero/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/exp02/contracts/traits/v1alpha1"
)

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
		description:    "Renders backup (and a command as a landing-volume pre-hook) as a Velero Schedule plus a volume policy; the projection only when the module executes"
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
		_ns:        #context.#moduleInstanceMetadata.namespace
		_name:      "\(_ns)-\(#component.#names.resourceName)"

		_command: [if #component.spec.backupCommand != _|_ {#component.spec.backupCommand}, {}][0]
		_isOwned:   _backup.executor == "module"
		_isCommand: _command.command != _|_
		_repo: [if _backup.repository != _|_ {cfg.repositories[_backup.repository]}, {}][0]

		// A command needs a landing volume here; the adapter derives the
		// scope from it and appends the redirect.
		_landing: [if _isCommand {_command.landing}, {}][0]
		_landingMount: [if _landing.volume != _|_ {#component.spec.volumes[_landing.volume].mountPath}, ""][0]

		_allVols: [if #component.spec.volumes != _|_ for k, _ in #component.spec.volumes {k}]
		_selected: [
			if _landing.volume != _|_ {[_landing.volume]},
			if _backup.volumes != _|_ {_backup.volumes},
			_allVols,
		][0]
		_skipped: [for v in _allVols if !list.Contains(_selected, v) {v}]

		_hours: [
			if _r.keepHourly != _|_ {_r.keepHourly},
			if _r.keepLast != _|_ {_r.keepLast * 24},
			if _r.keepDaily != _|_ {_r.keepDaily * 24},
			if _r.keepWeekly != _|_ {_r.keepWeekly * 168},
			if _r.keepMonthly != _|_ {_r.keepMonthly * 744},
			if _r.keepYearly != _|_ {_r.keepYearly * 8784},
			if _r.keepWithin != _|_ {(#WithinHours & {"in": _r.keepWithin}).out},
		]

		_pre: [if _landing.volume != _|_ {
			exec: {
				container: _command.container
				command: ["sh", "-c", "\(_command.command) > \(_landingMount)/\(_landing.path)"]
				onError: "Fail"
				timeout: "10m"
			}
		}]
		_post: [if _isCommand if _command.compensate != _|_ {
			exec: {container: _command.container, command: _command.compensate.command, onError: "Continue", timeout: "30s"}
		}]

		_schedule: velerov1.#Schedule & {
			metadata: {
				name:      _name
				namespace: "velero"
				labels:    #context.labels
			}
			spec: {
				schedule: _backup.schedule
				template: {
					includedNamespaces: [_ns]
					labelSelector: matchLabels: #context.componentLabels
					if len(_hours) > 0 {
						ttl: "\(list.Max(_hours))h"
					}
					if _backup.repository != _|_ {
						storageLocation: cfg.repositories[_backup.repository].storageLocation
					}
					if _backup.method == "snapshot" {
						snapshotVolumes:  true
						snapshotMoveData: true
					}
					if _backup.method != "snapshot" {
						defaultVolumesToFsBackup: true
					}
					if len(_skipped) > 0 {
						resourcePolicy: {kind: "configmap", name: "\(_name)-volume-policy"}
					}
					if len(_pre) + len(_post) > 0 {
						hooks: resources: [{
							name: _name
							labelSelector: matchLabels: #context.componentLabels
							if len(_pre) > 0 {pre: _pre}
							if len(_post) > 0 {post: _post}
						}]
					}
				}
			}
		}

		_policy: {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: {
				name:      "\(_name)-volume-policy"
				namespace: "velero"
				labels:    #context.labels
			}
			data: "policy.yaml": yaml.Marshal({
				version: "v1"
				volumePolicies: [for v in _skipped {
					conditions: pvcLabels: {for k, l in #context.componentLabels {(k): l}, (#VolumeLabel): v}
					action: type: "skip"
				}]
			})
		}

		_projection: (proj.#ConfigMap & {
			#backup:    _backup
			#repo:      _repo
			#name:      #component.#names.resourceName
			#instance:  #context.#moduleInstanceMetadata.name
			#namespace: _ns
			#labels:    #context.labels
		}).out

		output: list.Concat([
			[if !_isOwned {_schedule}],
			[if !_isOwned if len(_skipped) > 0 {_policy}],
			[if _isOwned {_projection}],
		])
	}
}
