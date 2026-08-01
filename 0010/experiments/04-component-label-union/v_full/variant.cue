// Variant 1 — full union. Expected to FAIL: primitive categories collide.
package v_full

import (
	p "enhancements.opmodel.dev/0010/exp04/prim"
)

#Component: {
	metadata: {
		name!:   string
		labels?: p.#LabelsType
	}
	#resources: [string]:  p.#Primitive
	#traits?: [string]:    p.#Primitive
	#blueprints?: [string]: p.#Primitive

	// Every primitive label, unfiltered — what core/SPEC.md :216/:222/:658 describe.
	_allLabels: {
		for _, r in #resources {
			if r.metadata.labels != _|_ {r.metadata.labels}
		}
		if #traits != _|_ {for _, t in #traits {if t.metadata.labels != _|_ {t.metadata.labels}}}
		if #blueprints != _|_ {for _, b in #blueprints {if b.metadata.labels != _|_ {b.metadata.labels}}}
	}
	metadata: labels: _allLabels
}

// Mirrors modules/jellyfin/components.cue:22 — stateful blueprint, container,
// volumes, configmaps, expose, security context.
jellyfinLike: #Component & {
	metadata: name: "jellyfin"
	#resources: {
		container:  p.#ContainerOpen
		volumes:    p.#Volumes
		configMaps: p.#ConfigMaps
	}
	#traits: {
		expose:   p.#Expose
		security: p.#SecurityContext
	}
	#blueprints: stateful: p.#StatefulBlueprint
}

out: jellyfinLike.metadata.labels
