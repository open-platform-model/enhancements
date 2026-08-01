// Package prim carries minimal stand-ins for the catalog primitives, copied in
// shape (not by import) from catalog_opm/src as of 2026-08-01.
//
// Only the label surface matters here, so specs are reduced to one field. The
// label VALUES are verbatim from the real catalog — that is what the experiment
// turns on:
//
//   catalog_opm/src/resources/container.cue:21   resource…/category: "workload"
//   catalog_opm/src/resources/volume.cue:19      resource…/category: "storage"
//   catalog_opm/src/resources/configmap.cue      resource…/category: "config"
//   catalog_opm/src/traits/expose.cue            trait…/category:    "network"
//   catalog_opm/src/traits/security_context.cue  trait…/category:    "security"
//   catalog_opm/src/blueprints/workload/stateful_workload.cue:44
//                                               core…/workload-type: "stateful"
package prim

#LabelsType: [string]: string | int | bool | [string | int | bool]

#Primitive: {
	metadata: {
		name!:    string
		labels?:  #LabelsType
	}
	spec?: {...}
}

// Container, with workload-type as a REQUIRED open disjunction — the real
// shape today, where the module author must pick. This is the form that
// decides whether an iterating union can be used at all.
#ContainerRequired: #Primitive & {
	metadata: {
		name: "container"
		labels: {
			"resource.opmodel.dev/category":    "workload"
			"core.opmodel.dev/workload-type"!: "stateless" | "stateful" | "daemon" | "task" | "scheduled-task"
		}
	}
	spec: container: image: string
}

// Same, with the required marker dropped.
#ContainerOpen: #Primitive & {
	metadata: {
		name: "container"
		labels: {
			"resource.opmodel.dev/category":   "workload"
			"core.opmodel.dev/workload-type": "stateless" | "stateful" | "daemon" | "task" | "scheduled-task"
		}
	}
	spec: container: image: string
}

#Volumes: #Primitive & {
	metadata: {name: "volumes", labels: "resource.opmodel.dev/category": "storage"}
	spec: volumes: [string]: path: string
}

#ConfigMaps: #Primitive & {
	metadata: {name: "config-maps", labels: "resource.opmodel.dev/category": "config"}
	spec: configMaps: [string]: data: string
}

#Expose: #Primitive & {
	metadata: {name: "expose", labels: "trait.opmodel.dev/category": "network"}
	spec: expose: port: int
}

#SecurityContext: #Primitive & {
	metadata: {name: "security-context", labels: "trait.opmodel.dev/category": "security"}
	spec: securityContext: runAsUser: int
}

// The stateful blueprint. Carries the matching label, plus a SECOND label in a
// namespace core does not own — the future state where the vocabulary has moved
// out of core into a catalog. Whether this key survives the union is what
// separates the prefix filter from the denylist.
#StatefulBlueprint: #Primitive & {
	metadata: {
		name: "stateful-workload"
		labels: {
			"core.opmodel.dev/workload-type": "stateful"
			"opm.opmodel.dev/tier":           "data"
		}
	}
	spec: statefulWorkload: replicas: int
}

/////////////////////////////////////////////////////////////////
//// Variant 3 stand-ins — matching moved to its own field
/////////////////////////////////////////////////////////////////

// #PrimitiveMatch splits the two concerns metadata.labels conflates today:
// `metadata.labels` stays descriptive (categorisation, browsing) and is never
// unified upward; `matchLabels` is what transformers select on and IS unified.
#PrimitiveMatch: {
	metadata: {
		name!:   string
		labels?: #LabelsType
	}
	matchLabels?: #LabelsType
	spec?: {...}
}

#ContainerMatch: #PrimitiveMatch & {
	metadata: {name: "container", labels: "resource.opmodel.dev/category": "workload"}
	matchLabels: "opm.opmodel.dev/workload-type"!: "stateless" | "stateful" | "daemon" | "task" | "scheduled-task"
	spec: container: image: string
}

#VolumesMatch: #PrimitiveMatch & {
	metadata: {name: "volumes", labels: "resource.opmodel.dev/category": "storage"}
	spec: volumes: [string]: path: string
}

#ConfigMapsMatch: #PrimitiveMatch & {
	metadata: {name: "config-maps", labels: "resource.opmodel.dev/category": "config"}
	spec: configMaps: [string]: data: string
}

#ExposeMatch: #PrimitiveMatch & {
	metadata: {name: "expose", labels: "trait.opmodel.dev/category": "network"}
	spec: expose: port: int
}

#SecurityContextMatch: #PrimitiveMatch & {
	metadata: {name: "security-context", labels: "trait.opmodel.dev/category": "security"}
	spec: securityContext: runAsUser: int
}

#StatefulBlueprintMatch: #PrimitiveMatch & {
	metadata: {name: "stateful-workload", labels: "blueprint.opmodel.dev/category": "workload"}
	matchLabels: {
		"opm.opmodel.dev/workload-type": "stateful"
		"opm.opmodel.dev/tier":          "data"
	}
	spec: statefulWorkload: replicas: int
}

// A second workload blueprint, to prove a genuine disagreement still fails.
#DaemonBlueprintMatch: #PrimitiveMatch & {
	metadata: {name: "daemon-workload", labels: "blueprint.opmodel.dev/category": "workload"}
	matchLabels: "opm.opmodel.dev/workload-type": "daemon"
	spec: daemonWorkload: hostNetwork: bool
}
