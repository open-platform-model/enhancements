// The three dot-hostile primitives, declaring their constraints (D21).
// Modelled on the real catalog artefacts, cut to the naming surface:
//   #ExposeTrait            — catalog_opm/opm/traits/v1beta1/expose.cue
//   #StatefulWorkloadBlueprint — catalog_opm/opm/blueprints/v1beta1/stateful_workload.cue
//   #NamespaceResource      — catalog_opm (namespace resource)
// Plus one dot-neutral resource (#ContainerResource) to show the default
// path: no constraint declared, nothing tightens.
package e0019x09

// Dot-neutral: the common case. Declares NO #nameConstraint, so a component
// made only of these keeps the full #ObjectNameType ceiling — dots allowed,
// matching what the API server admits for Deployment/DaemonSet.
#ContainerResource: #Resource & {
	metadata: name: "container"
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
