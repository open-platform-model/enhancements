package e0019x10

_instance: #InstanceIdentity & {name: "prod", namespace: "media"}
_istio: #InstanceIdentity & {name:    "istio", namespace: "istio-system"}

// A1 — default: expose.name = #names.dns.short; Service, workload and DNS agree.
a1: #Expose & {
	metadata: name: "web"
	#resources: container: #ContainerResource
	#instance: _instance
}
_a1Svc: (#ServiceTransformer & {#component: a1}).output.metadata.name == "prod-web"
_a1Svc: true
_a1Fqdn: a1.#names.dns.fqdn == "prod-web.media.svc.cluster.local"
_a1Fqdn: true

// A2 — exact Service name via expose.name (istiod). Service is "istiod";
// workload stays "istio-istiod"; the DNS projection follows the WORKLOAD.
a2: #Expose & {
	metadata: name: "istiod"
	#resources: container: #ContainerResource
	spec: expose: name: "istiod"
	#instance: _istio
}
_a2Svc: (#ServiceTransformer & {#component: a2}).output.metadata.name == "istiod"
_a2Svc: true
_a2Workload: a2.#names.resourceName == "istio-istiod"
_a2Workload: true
_a2DnsDiverges: a2.#names.dns.short != (#ServiceTransformer & {#component: a2}).output.metadata.name
_a2DnsDiverges: true

// A3 — exact name via resourceName instead: Expose's #nameConstraint admits
// it (DNS-1035), expose.name defaults to it, all three agree.
a3: #Expose & {
	metadata: {name: "istiod", resourceName: "istiod"}
	#resources: container: #ContainerResource
	#instance: _istio
}
_a3Svc: (#ServiceTransformer & {#component: a3}).output.metadata.name == "istiod"
_a3Svc: true
_a3Fqdn: a3.#names.dns.fqdn == "istiod.istio-system.svc.cluster.local"
_a3Fqdn: true

// C1 — Path C: override on the trait's own spec path through the wrapper.
c1: #ExposeC & {
	metadata: name: "istiod"
	#resources: container: #ContainerResource
	spec: expose: name: "istiod"
	#instance: _istio
}
// MEASURED REFUTED: on the #traits ENTRY, spec.expose.name is the TYPE
// (#ServiceNameType), never the author's value — that lands on the
// component's spec only. So the entry's #nameConstraint degrades to the
// type, and the override never reaches resourceName:
//   c1.#traits.expose.spec.expose.name  -> =~"^[a-z]..." & MaxRunes(63)
//   c1.#traits.expose.#nameConstraint   -> same type
//   c1.#names.resourceName              -> "istio-istiod"
_c1PathCDegrades: c1.#names.resourceName == "istio-istiod"
_c1PathCDegrades: true

// C2 — Path C with the wrapper feeding spec back to the entry. MEASURED
// REFUTED (cue v0.17.1): the reference cycle entry.spec -> component.spec ->
// entry.spec runs through the component's `if t.spec != _|_` comprehension
// guard, which then contributes nothing, so the author's own
// `spec: expose: ...` is refused as "field not allowed":
//
//   c2: #ExposeC2 & {
//   	metadata: name: "istiod"
//   	#resources: container: #ContainerResource
//   	spec: expose: name: "istiod"
//   	#instance: _istio
//   }
//
//   c2.spec.expose: field not allowed
//       ./cases.cue:59:8

// MUST FAIL F — dotted expose.name: refused by the field's own type.
//   failF: #Expose & {
//   	metadata: name: "web"
//   	#resources: container: #ContainerResource
//   	spec: expose: name: "svc.internal"
//   	#instance: _instance
//   }
