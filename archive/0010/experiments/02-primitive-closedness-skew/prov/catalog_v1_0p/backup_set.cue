// Build 1.0.0 of catalog A's OTHER shape: a spec whose body is a pattern
// constraint over an author-chosen map key, which is how catalog_opm actually
// writes several of its resources (`spec: configMaps: [cmName=string]:
// #ConfigMapSchema`, catalog_opm/src/resources/configmap.cue:23). A pattern
// constraint is open over KEYS; the question is whether the VALUE definition
// stays closed across builds.
package catalog_v1_0p

import s "test.example/skew/schema"

#BackupSetSchema: {
	name!:     string // auto-populated from the map key, as catalog_opm does
	schedule!: string
	mode:      *"retain" | "retain" | "delete"
}

#BackupSetResource: s.#Resource & {
	metadata: {
		name:           "backup-set"
		modulePath:     "test.example/cat-a/resources"
		apiVersion:     "v1"
		catalogVersion: "1.0.0"
		description:    "Generic multi-target backup contract"
	}

	spec: backupSet: [setName=string]: #BackupSetSchema & {name: string | *setName}
}
