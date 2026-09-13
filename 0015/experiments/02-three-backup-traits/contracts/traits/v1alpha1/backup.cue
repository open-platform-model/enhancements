// The policy contract, as proposed in research/backup-traits-proposal.cue
// (2026-09-12). Copied wrapper shape from experiment 01. Every engine
// implements it; three fields are advisory under the keep-more rule.
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
		description:    "Scheduled backup of the component's persistent volumes"
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

	// A repository the PLATFORM registered, by name (design doc section 6).
	// The provider resolves it; the adapter derives a per-instance prefix.
	// Absent: the platform default.
	repository?: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

	// Which of the component's volumes are in scope. Absent: all. Needs P1
	// (the volume key stamped on the PVC as volume.opmodel.dev/name).
	volumes?: [string, ...string]

	// ADVISORY preference; both modes are complete captures.
	capture: *"any" | "snapshot" | "filesystem"

	// ADVISORY under keep-more: an engine that cannot exclude backs up more.
	excludes?: [...string & !=""]

	// ADVISORY: when maintenance runs, never what survives.
	maintenance?: {
		pruneSchedule?: #Cron
		checkSchedule?: #Cron
	}
}

#BackupRetentionSchema: {
	keepLast?:    int & >0
	keepHourly?:  int & >0
	keepDaily?:   int & >0
	keepWeekly?:  int & >0
	keepMonthly?: int & >0
	keepYearly?:  int & >0
	// Rolling window. Single unit in this experiment (h, d, w); the
	// adapters convert it to hours for the keep-more rule.
	keepWithin?: string & =~"^[0-9]+[hdw]$"
	matchN(>=1, [
		{keepLast!: _}, {keepHourly!: _}, {keepDaily!: _}, {keepWeekly!: _},
		{keepMonthly!: _}, {keepYearly!: _}, {keepWithin!: _},
	])
}
