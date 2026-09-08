// Variant 2e against a REQUIRED label field. Expected to FAIL: CUE cannot iterate a struct with an unset required field.
package v_denylist_req

import (
	"list"
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

	// Every key except a named categorisation set (variant 2e). Mirrors D30's
	// denylist-over-allowlist choice for the match operands.
	#nonComponentLabelKeys: [
		"resource.opmodel.dev/category",
		"trait.opmodel.dev/category",
	]
	_allLabels: {
		for _, r in #resources {
			if r.metadata.labels != _|_ {
				for k, v in r.metadata.labels if !list.Contains(#nonComponentLabelKeys, k) {(k): v}
			}
		}
		if #traits != _|_ {for _, t in #traits {if t.metadata.labels != _|_ {
			for k, v in t.metadata.labels if !list.Contains(#nonComponentLabelKeys, k) {(k): v}}}}
		if #blueprints != _|_ {for _, b in #blueprints {if b.metadata.labels != _|_ {
			for k, v in b.metadata.labels if !list.Contains(#nonComponentLabelKeys, k) {(k): v}}}}
	}
	metadata: labels: _allLabels
}

// Mirrors modules/jellyfin/components.cue:22 — stateful blueprint, container,
// volumes, configmaps, expose, security context.
jellyfinLike: #Component & {
	metadata: name: "jellyfin"
	#resources: {
		container:  p.#ContainerRequired
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
