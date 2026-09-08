// The Service-name source under review. Modelled on
// catalog_opm/opm/traits/v1beta1/expose.cue, cut to the naming surface.
package e0019x10

// PATH A' (the proposal under test): expose.name is a VALUE the transformer
// always reads. Typed #ServiceNameType (D20). Its default cannot live here —
// #ExposeSchema has no lexical path to the owning component — so the
// default lives on the #Expose wrapper below.
#ExposeSchema: {
	name: #ServiceNameType
	type: "ClusterIP" | "NodePort" | "LoadBalancer" | *"ClusterIP"
}

#ExposeTrait: #Trait & {
	metadata: name: "expose"
	#nameConstraint: #ServiceNameType // D21, unchanged
	spec: expose: #ExposeSchema
}

// The wrapper is where the default is expressible: it IS a #Component, so
// #names is in scope. Every fleet module attaches Expose through the wrapper
// (17 files embed tr.#Expose, zero attach #ExposeTrait raw — measured
// 2026-08-24).
#Expose: #Component & {
	// MEASURED: `#names` from #Component is NOT in lexical scope here
	// ("reference \"#names\" not found") — the same lexical rule 0019 records
	// for #transform slots. The wrapper re-declares the slot it references;
	// unification with #Component's own #names makes it the same value.
	#names: _
	#traits: expose: #ExposeTrait
	spec: expose: name: *#names.dns.short | #ServiceNameType
}

// Stand-in for service_transformer.cue: reads ONLY spec.expose.name.
#ServiceTransformer: {
	#component: _
	output: {
		kind: "Service"
		metadata: name: #component.spec.expose.name
	}
}

// PATH C (constraint-only field): the trait's #nameConstraint is computed
// from the trait's own filled spec. If the author's expose.name is concrete
// on the #traits ENTRY, resourceName follows it; if it is concrete only on
// the component's spec, the guard sees a non-concrete value (exp 09's
// measured `!= _|_` behaviour) and the constraint degrades to the type.
#ExposeTraitC: #Trait & {
	metadata: name: "expose"
	spec: expose: #ExposeSchema
	#nameConstraint: [
		if spec.expose.name != _|_ {spec.expose.name},
		#ServiceNameType,
	][0]
}

#ExposeC: #Component & {
	#traits: expose: #ExposeTraitC
}

// PATH C2: the wrapper feeds the component-level value BACK onto the trait
// entry so the entry's spec is concrete. Tests whether the resulting
// reference cycle (entry.spec -> component.spec -> entry.spec) resolves.
#ExposeC2: #Component & {
	spec: _ // same lexical rule: re-declare to reference
	_svcName: spec.expose.name
	#traits: expose: #ExposeTraitC & {spec: expose: name: _svcName}
}
