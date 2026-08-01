// Variant 2d against a REQUIRED label field. Expected to pass: indexing never iterates.
package v_index_req

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

	// One key, named by the schema (variant 2d). Indexes rather than iterates.
	#LabelWorkloadType: "core.opmodel.dev/workload-type"
	_allLabels: {
		for _, r in #resources {
			if r.metadata.labels[#LabelWorkloadType] != _|_ {
				(#LabelWorkloadType): r.metadata.labels[#LabelWorkloadType]
			}
		}
		if #blueprints != _|_ {for _, b in #blueprints {
			if b.metadata.labels[#LabelWorkloadType] != _|_ {
				(#LabelWorkloadType): b.metadata.labels[#LabelWorkloadType]
			}}}
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
