// Build 1.2.0 of catalog A — VIOLATES the additive-only promise. `schedule`
// is narrowed from `string` to a two-value disjunction: options are removed
// inside a major, which the rule forbids. Present so the harness can measure
// whether the always-unify rung catches a broken promise or waves it through.
package catalog_v1_2_narrowed

import s "test.example/skew/schema"

#BackupResource: s.#Resource & {
	metadata: {
		name:           "backup"
		modulePath:     "test.example/cat-a/resources"
		apiVersion:     "v1"
		catalogVersion: "1.2.0"
		description:    "Generic backup contract, fulfilled by a platform provider"
	}

	spec: backup: {
		schedule!:  "daily" | "weekly" // ← narrowed from `string` in 1.2.0
		mode:       *"retain" | "retain" | "delete"
		retention?: string
	}
}
