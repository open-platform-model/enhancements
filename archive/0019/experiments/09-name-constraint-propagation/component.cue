// The D21 propagation mechanism, demonstrated on a minimal copy of
// core/src/component.cue.
//
// Copied (not referenced), then CUT DOWN to the name machinery:
//   #Component — core/src/component.cue. Kept: metadata.{name,resourceName},
//   #instance, #names, the three attachment maps. Dropped: matchLabels and
//   its derivation check, labels/annotations, _allFields/spec — none of them
//   touch naming, and rule 1 (one concept per experiment) says cut.
//   #InstanceIdentity — stand-in with the two fields #names reads.
//   #Resource/#Trait/#Blueprint — stand-ins with metadata.name plus the NEW
//   #nameConstraint slot; the real definitions carry far more, none of it
//   relevant here.
//
// CHANGED vs core (this is the proposal):
//   1. resourceName's ceiling: #NameType → #ObjectNameType (D20), and the
//      D16 qualified default is kept, unified against the SAME ceiling.
//   2. NEW #nameConstraint (top-default) on the three primitive kinds.
//   3. NEW comprehensions on #Component unifying every attached primitive's
//      #nameConstraint into metadata.resourceName — the matchLabels
//      wholesale-unification pattern applied to a scalar.
package e0019x09

// --------------------------------------------------------------------------
// Stand-ins for the primitive kinds. Only the naming surface is modelled.
// --------------------------------------------------------------------------

#Resource: {
	kind: "Resource"
	metadata: name!: #NameType
	// NEW (D21): a type the owning component's resourceName must ALSO
	// satisfy. Defaults to TOP, not optional-with-a-guard — measured on cue
	// v0.17.1 (this experiment, first run): `t.#nameConstraint != _|_` is
	// false for a NON-CONCRETE value, so an optional slot behind that guard
	// silently never propagates. Top makes propagation unconditional and
	// declaring-a-constraint identical to narrowing this field; unifying
	// with top is the identity, so an indifferent primitive costs nothing.
	// Hidden (definition) field: contract, never exported output.
	#nameConstraint: _
	...
}

#Trait: {
	kind: "Trait"
	metadata: name!: #NameType
	#nameConstraint: _
	...
}

#Blueprint: {
	kind: "Blueprint"
	metadata: name!: #NameType
	#nameConstraint: _
	...
}

#InstanceIdentity: {
	name!:         #NameType
	namespace!:    #NameType
	clusterDomain: string | *"cluster.local"
}

// --------------------------------------------------------------------------
// #Component — the propagation site
// --------------------------------------------------------------------------

#Component: {
	kind: "Component"

	metadata: {
		name!: #NameType

		// CHANGED (D20): ceiling widens #NameType → #ObjectNameType, so an
		// explicit override may carry dots (Deployment/DaemonSet/ConfigMap/
		// CSIDriver all admit them). The D16 qualified default stays, and
		// note it is intrinsically dotless: #instance.name and name are both
		// #NameType (labels), so the default can never trip a dot
		// constraint — only an EXPLICIT override can. That is what keeps the
		// default path structurally safe and pushes all validation cost onto
		// deliberate overrides.
		resourceName: *("\(#instance.name)-\(name)" & #ObjectNameType) | #ObjectNameType
	}

	#resources: [string]: #Resource
	#traits?: [string]:   #Trait
	#blueprints?: [string]: #Blueprint

	// NEW (D21): every attached primitive's #nameConstraint unifies into
	// resourceName — UNCONDITIONALLY. The matchLabels pattern applied to
	// naming: the component contributes nothing of its own; every constraint
	// traces to a primitive, so attaching the primitive IS what tightens the
	// name. Unification composes for free — Expose (DNS-1035) ∧
	// StatefulWorkload (DNS-1123 label) = DNS-1035, no precedence rule
	// written anywhere. No existence guard: the slot defaults to top (see
	// #Resource above for the measured reason), and unifying top is a no-op.
	for _, r in #resources {
		metadata: resourceName: r.#nameConstraint
	}
	if #traits != _|_ {
		for _, t in #traits {
			metadata: resourceName: t.#nameConstraint
		}
	}
	if #blueprints != _|_ {
		for _, b in #blueprints {
			metadata: resourceName: b.#nameConstraint
		}
	}

	#instance: #InstanceIdentity

	// COPY — core/src/component.cue #names, unchanged. The DNS projection is
	// deliberately NOT made conditional in this experiment: dns.* strings
	// still compute for a dotted resourceName (they are just strings), and
	// whether computing them should be gated on a DNS-bearing attachment is
	// a separate claim for a separate experiment.
	#names: {
		resourceName: metadata.resourceName
		dns: {
			short: resourceName
			local: "\(resourceName).\(#instance.namespace)"
			fqdn:  "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
		}
	}
}
