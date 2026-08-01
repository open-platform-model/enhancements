// Variant 3 — a DEDICATED matching field. metadata.labels is left alone and
// never unified; matchLabels is unified wholesale, with no filter, because
// every key in it exists to be matched on.
//
// Two properties follow from having no filter:
//   - conflicts are meaningful (two primitives disagreeing on workload-type
//     SHOULD fail) rather than accidental
//   - the union embeds structs instead of iterating them, so a REQUIRED field
//     survives — the thing no filtered union could preserve
package v_matchfield

import (
	p "enhancements.opmodel.dev/0010/exp04/prim"
)

#Component: {
	metadata: {
		name!:   string
		labels?: p.#LabelsType // descriptive only; NOT unified from primitives
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

jellyfinLike: #Component & {
	metadata: name: "jellyfin"
	#resources: {
		container:  p.#ContainerMatch // carries a REQUIRED open disjunction
		volumes:    p.#VolumesMatch
		configMaps: p.#ConfigMapsMatch
	}
	#traits: {
		expose:   p.#ExposeMatch
		security: p.#SecurityContextMatch
	}
	#blueprints: stateful: p.#StatefulBlueprintMatch
}

out: jellyfinLike.matchLabels

// What metadata.labels looks like — untouched by the union, so the
// categorisation labels that collided in v_full simply never meet.
outDescriptive: jellyfinLike.metadata

// Container alone — nothing supplies a concrete workload type. The REQUIRED
// marker must still bite, which is what no filtered union could preserve.
containerOnly: #Component & {
	metadata: name: "bare"
	#resources: container: p.#ContainerMatch
}
outBare: containerOnly.matchLabels
