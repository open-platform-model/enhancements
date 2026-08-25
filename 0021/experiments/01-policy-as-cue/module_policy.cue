// The module class as one policy file would carry it in modules/policy/.
package policy

policies: module: #Policy & {
	class:     "module"
	repo:      "modules"
	carrier:   "cue-module-semver"
	surface:   ["the #config schema, compared by subsumption over accepted values"]
	bump:      {kind: "table", table: stableBump}
	prestable: "open" // 0021 OQ4
	rules: {
		R1: {
			statement: "A release that stops accepting values the previous release accepted MUST bump the major."
			strength:  "must"
			layer:     "convention"
			source: ["0021 D2"]
			unenforcedBecause: "the module compatibility gate is 0021 OQ5/OQ6 and not yet built"
			examples: fail: ["rename #config.database to #config.db in a minor"]
		}
		R2: {
			statement: "A release that adds only optional fields or fields with defaults MUST bump at least the minor."
			strength:  "must"
			layer:     "claim"
			source: ["0021 D2"]
		}
		R3: {
			statement: "A version already present in the registry MUST be refused, never skipped."
			strength:   "must"
			layer:      "gate"
			enforcedBy: "opm module publish"
			source: ["0011 D15"]
		}
		R4: {
			statement: "A module promoted from an older train SHOULD bump its path major past that train's line, and CI refuses two trains sharing a major."
			strength:   "should"
			layer:      "gate"
			enforcedBy: "modules release workflow, cross-train major separation guard"
			source: ["modules/CLAUDE.md major separation rule"]
		}
		R5: {
			statement: "A field that stays accepted but is no longer read MAY not be detected by any gate and is still a breaking change."
			strength: "may"
			layer:    "convention"
			source: ["0021 05-risks.md"]
		}
	}
}
