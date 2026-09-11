// The backup trait exactly as designed 2026-09-11 for catalog_opm
// (opm/traits/v1alpha1/backup.cue). Shape copied from
// catalog_opm/opm/traits/v1beta1/disruption_budget.cue; only the identity
// package and the appliesTo import differ.
package v1alpha1

import (
	id "testing.opmodel.dev/experiments/0015/contracts/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

// Declares that this component's persistent volumes are backed up on a
// schedule. The declaring catalog ships no transformer for it: a platform
// carries exactly one provider (k8up, Velero, ...) whose transformer
// requires this trait and renders the engine's policy object (0010 D37,
// 0015 D1).
//
// Grain is the component: every persistent volume the component declares
// is in scope, selected by the labels the base transformers stamp on the
// PVCs and pods. Per-volume selection and in-container hooks are out of
// this version: an adapter can render new objects and select existing
// ones, but cannot annotate objects another transformer rendered.
#BackupTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1alpha1"
		name:           "backup"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/backup@v1alpha1"
		description:    "Scheduled backup of the component's persistent volumes"
		labels: {
			"trait.opmodel.dev/category": "storage"
		}
	}

	// Implemented by a provider catalog, never by this one.
	fulfilment: "provider"

	// Load-bearing posture: an unhandled backup demand means there are no
	// backups. A module may narrow to `optional: true` for data it can lose.
	optional: bool | *false

	appliesTo: [res.#VolumesResource]

	spec: backup: #BackupSchema
}

#Backup: c.#Component & {
	#traits: (#BackupTrait.metadata.fqn): #BackupTrait
}

#BackupSchema: {
	// Standard five-field cron. Engine-specific tokens (k8up's
	// `@daily-random`) are deliberately not admitted; a provider may add
	// jitter on its own side.
	schedule!: string & =~"^(\\S+\\s+){4}\\S+$"

	// How many snapshots to keep, per tier. At least one tier is required:
	// every engine's default with no retention is "keep nothing" or
	// "keep forever", and neither is a backup policy.
	//
	// Engines without tiered retention (Velero: a single ttl) MUST map this
	// to a duration that keeps at least as long as the longest tier asks.
	// A lossy mapping keeps more, never less.
	retention!: #BackupRetentionSchema
}

#BackupRetentionSchema: {
	keepLast?:    int & >0
	keepHourly?:  int & >0
	keepDaily?:   int & >0
	keepWeekly?:  int & >0
	keepMonthly?: int & >0
	keepYearly?:  int & >0
	matchN(>=1, [
		{keepLast!: _},
		{keepHourly!: _},
		{keepDaily!: _},
		{keepWeekly!: _},
		{keepMonthly!: _},
		{keepYearly!: _},
	])
}
