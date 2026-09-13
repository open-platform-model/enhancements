// Shape B: the MODULE owns capture (a sidecar it declares itself, such as
// the itzg mc-backup restic loop), the platform owns policy. Catalog-
// fulfilled: the declaring catalog renders the policy PROJECTION (a
// ConfigMap the sidecar reads by a conventional name) on every platform;
// an engine that can maintain the module's repository format adds
// prune and check (k8up for restic). Velero adds nothing, honestly.
package v1alpha1

import (
	id "testing.opmodel.dev/experiments/0015/exp02/contracts/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#BackupOwnedTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1alpha1"
		name:           "backup-owned"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/backup-owned@v1alpha1"
		description:    "The module captures its own backups; the platform projects the policy it must follow"
		labels: "trait.opmodel.dev/category": "storage"
	}
	// Default fulfilment ("catalog"): implemented by this catalog.
	optional: false
	appliesTo: [res.#ContainerResource]
	spec: backupOwned: #BackupOwnedSchema
}

#BackupOwned: c.#Component & {
	#traits: (#BackupOwnedTrait.metadata.fqn): #BackupOwnedTrait
}

#BackupOwnedSchema: {
	// Repository format the module's tool writes. Engines with maintenance
	// for it (k8up: restic prune/check) schedule that; others add nothing.
	format: "restic"

	// Env keys the module's tool reads for the projected policy, so the
	// projection stays tool-neutral. RESTIC_REPOSITORY and RESTIC_HOSTNAME
	// are restic-native and fixed. Credentials are NOT projected: the tool
	// reads the platform's repository Secret by its conventional name.
	envKeys: {
		schedule:  string | *"BACKUP_SCHEDULE"
		retention: string | *"BACKUP_RETENTION"
		excludes:  string | *"BACKUP_EXCLUDES"
	}
}
