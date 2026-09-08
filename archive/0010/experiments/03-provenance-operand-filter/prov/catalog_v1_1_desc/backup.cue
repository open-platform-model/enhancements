// Build 1.1.0 of catalog A, with the description REWORDED against 1.0.0 and
// nothing else changed relative to catalog_v1_1. Same contract major (`v1`),
// same spec body, same added `retention?`.
//
// This build exists to isolate ONE variable: a provenance field that is not
// `catalogVersion`. A catalog author fixing a typo or clarifying wording
// between builds is the most ordinary edit there is, and it must not be able
// to break a match.
package catalog_v1_1_desc

import s "test.example/skew/schema"

#BackupResource: s.#Resource & {
	metadata: {
		name:           "backup"
		modulePath:     "test.example/cat-a/resources"
		apiVersion:     "v1"
		catalogVersion: "1.1.0"
		description:    "Generic backup contract, fulfilled by an installed provider" // ← reworded
	}

	spec: backup: {
		schedule!:  string
		mode:       *"retain" | "retain" | "delete"
		retention?: string
	}
}
