// The policy contract. Every engine implements it. One field, `executor`,
// says who carries it out: the platform's engine (default) or the module's
// own tool, in which case every adapter projects the policy into a
// ConfigMap the tool reads (contracts/projection) and an engine that can
// maintain the tool's repository format adds prune and check.
package v1alpha1

import (
	id "testing.opmodel.dev/experiments/0015/exp02/contracts/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#BackupTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1alpha1"
		name:           "backup"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/backup@v1alpha1"
		description:    "Scheduled backup policy for the component's persistent state"
		labels: "trait.opmodel.dev/category": "storage"
	}
	fulfilment: "provider"
	optional:   bool | *false
	appliesTo: [res.#VolumesResource]
	spec: backup: #BackupSchema
}

#Backup: c.#Component & {
	#traits: (#BackupTrait.metadata.fqn): #BackupTrait
}

#Cron: string & =~"^(\\S+\\s+){4}\\S+$"

#BackupSchema: {
	schedule!:  #Cron
	retention!: #BackupRetentionSchema

	// Who executes the policy.
	//   platform: the engine captures (the default).
	//   module:   the workload captures itself with a tool it declares
	//             (a sidecar); the engine projects the policy into a
	//             ConfigMap that tool reads and never captures. A value,
	//             not a contract: an adapter ignoring it takes an extra
	//             crash-consistent copy, which is keep-more, never lossy.
	executor: *"platform" | "module"

	// A repository the PLATFORM registered, by name. Absent: the default.
	repository?: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

	// Which of the component's volumes. Absent: all. Needs P1.
	volumes?: [string, ...string]

	// ADVISORY preference; both are complete captures.
	method: *"any" | "snapshot" | "filesystem"

	// ADVISORY under keep-more.
	excludes?: [...string & !=""]
	maintenance?: {
		pruneSchedule?: #Cron
		checkSchedule?: #Cron
	}

	// executor: module only. Env keys the module's tool reads for the
	// projected policy, so the projection stays tool-neutral.
	// RESTIC_REPOSITORY and RESTIC_HOSTNAME are restic-native and fixed;
	// credentials are read from the platform's repository Secret by name.
	projection?: envKeys: {
		schedule:  string | *"BACKUP_SCHEDULE"
		retention: string | *"BACKUP_RETENTION"
		excludes:  string | *"BACKUP_EXCLUDES"
	}
}

#BackupRetentionSchema: {
	keepLast?:    int & >0
	keepHourly?:  int & >0
	keepDaily?:   int & >0
	keepWeekly?:  int & >0
	keepMonthly?: int & >0
	keepYearly?:  int & >0
	keepWithin?:  string & =~"^[0-9]+[hdw]$"
	matchN(>=1, [
		{keepLast!: _}, {keepHourly!: _}, {keepDaily!: _}, {keepWeekly!: _},
		{keepMonthly!: _}, {keepYearly!: _}, {keepWithin!: _},
	])
}
