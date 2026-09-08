// The three dot-hostile primitives, declaring their constraints (D21).
// Modelled on the real catalog artefacts, cut to the naming surface:
//   #ExposeTrait            — catalog_opm/opm/traits/v1beta1/expose.cue
//   #StatefulWorkloadBlueprint — catalog_opm/opm/blueprints/v1beta1/stateful_workload.cue
//   #NamespaceResource      — catalog_opm (namespace resource)
// Plus one dot-neutral resource (#ContainerResource) to show the default
// path: no constraint declared, nothing tightens.
package e0019x11

// The common case, and (extension 2026-08-24) the first CONDITIONAL
// constraint: the resource computes its own #nameConstraint from its own
// matching key. Mirrors catalog_opm/opm/resources/v1beta1/container.cue:29,
// where the workload-type key is REQUIRED on the resource and answered by a
// blueprint or inline on the #resources entry (never on the component —
// core's _matchLabelsAreDerived refuses that). Because the answer lives on
// the primitive, the primitive can read it: a raw #Container labelled
// "stateful" renders a StatefulSet (statefulset_transformer.cue matches on
// this label, not on the blueprint), so it must carry the label rule with
// no blueprint attached. Every other workload type contributes top.
//
// The list-index form, not `| *`: a default arm would win over the concrete
// one (same trap as name_helpers.cue's #WorkloadName).
#ContainerResource: #Resource & {
	metadata: name: "container"
	matchLabels: "core.opmodel.dev/workload-type"!: "stateless" | "stateful" | "daemon" | "task" | "scheduled-task"
	#nameConstraint: [
		if matchLabels["core.opmodel.dev/workload-type"] == "stateful" {#NameType},
		_,
	][0]
}

// Service's name IS the first DNS label of <name>.<ns>.svc.<domain>, and its
// validator is DNS-1035 (leading letter). One line, on the primitive that
// owns the reason.
#ExposeTrait: #Trait & {
	metadata: name: "expose"
	#nameConstraint: #ServiceNameType
}

// StatefulSet pods get stable DNS <sts>-<n>.<svc>.<ns>.svc.<domain>; the API
// server enforces the label rule on BOTH axes — "must not contain dots" AND
// "must be no more than 63 characters" (64 refused, bisected 2026-08-24).
// #NameType IS the label rule, so this one constraint captures dots and
// length at once; nothing further to declare.
#StatefulWorkloadBlueprint: #Blueprint & {
	metadata: name: "stateful-workload"
	#nameConstraint: #NameType
}

// A Namespace is the second label of every FQDN in it. Same bespoke
// "must not contain dots" check server-side. (Modules shipping a Namespace
// is frowned upon anyway — the constraint costs nothing and closes the hole
// for the exceptions.)
#NamespaceResource: #Resource & {
	metadata: name: "namespace"
	#nameConstraint: #NameType
}
