// Variant 3, conflict case — two blueprints that genuinely disagree on the
// workload type. With no filter in the way this is a real conflict and must
// fail. Lives in its own package so the failure can be observed in isolation.
package v_matchfield_conflict

import (
	p "enhancements.opmodel.dev/0010/exp04/prim"
)

#Component: {
	metadata: {
		name!:   string
		labels?: p.#LabelsType
	}
	#resources: [string]:   p.#PrimitiveMatch
	#traits?: [string]:     p.#PrimitiveMatch
	#blueprints?: [string]: p.#PrimitiveMatch

	matchLabels: {
		for _, r in #resources {
			if r.matchLabels != _|_ {r.matchLabels}
		}
		if #traits != _|_ {for _, t in #traits {if t.matchLabels != _|_ {t.matchLabels}}}
		if #blueprints != _|_ {for _, b in #blueprints {if b.matchLabels != _|_ {b.matchLabels}}}
	}
}

// Two blueprints that genuinely disagree. With no filter in the way this is a
// real conflict and must fail.
conflicting: #Component & {
	metadata: name: "conflict"
	#resources: container: p.#ContainerMatch
	#blueprints: {
		stateful: p.#StatefulBlueprintMatch
		daemon:   p.#DaemonBlueprintMatch
	}
}
out: conflicting.matchLabels
