// Variant 2c — prefix-filtered union. Expected to pass, dropping the catalog-owned key.
package v_prefix

import (
	"strings"
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

	// Keys under the core namespace only (variant 2c).
	_allLabels: {
		for _, r in #resources {
			if r.metadata.labels != _|_ {
				for k, v in r.metadata.labels if strings.HasPrefix(k, "core.opmodel.dev/") {(k): v}
			}
		}
		if #traits != _|_ {for _, t in #traits {if t.metadata.labels != _|_ {
			for k, v in t.metadata.labels if strings.HasPrefix(k, "core.opmodel.dev/") {(k): v}}}}
		if #blueprints != _|_ {for _, b in #blueprints {if b.metadata.labels != _|_ {
			for k, v in b.metadata.labels if strings.HasPrefix(k, "core.opmodel.dev/") {(k): v}}}}
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
