package transformers

/////////////////////////////////////////////////////////////////
//// Service naming
/////////////////////////////////////////////////////////////////

// WHY: Usage: (#ServiceName & {#comp: #component}).out
//
// Six readers name the Service: the Service transformer itself, the
// StatefulSet's serviceName and the four route transformers' backendRefs.
// The last five are cross-object references (0019 D22, carve-out 3) and must
// be byte-identical to what the Service transformer emits, or a headless
// Service or backend is silently pointed at nothing. The fallback arm is what
// keeps a component compiled against a build <= alpha.5 (expose.name?:
// string, unset) rendering (0010 D27); alpha.6 dropped it from every reader.
//
// The list-index form is load-bearing. The obvious spelling,
// `#comp.spec.expose.name | *#comp.#names.dns.short`, reads as "the
// override, defaulting to the core name" and means the opposite: in CUE a
// default arm wins over a concrete one, so the override would be silently
// discarded. Same trap that put cert-manager's webhook Service on the wrong
// port (see service_transformer.cue). `#names` is only concrete once
// `#instance` is set, which #Module does at render and fixtures do by hand.

// #ServiceName resolves the name of the Service an Expose component renders:
// expose.name when the component set or defaulted it (every build >= alpha.6
// attaches through the #Expose wrapper), otherwise the component's own
// #names.dns.short, the value that wrapper defaults to.
// See docs/name-constraints.md.
#ServiceName: {
	#comp!: _

	out: [
		if #comp.spec.expose.name != _|_ {#comp.spec.expose.name},
		#comp.#names.dns.short,
	][0]
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// Legacy shape: a component compiled against a build <= alpha.5, whose
// #ExposeSchema carried `name?: string` and whose wrapper set no default.
// Hand-built on purpose (embedding the current trait gives `name!`); #names
// is set as core would derive it.
_testServiceNameLegacy: (#ServiceName & {
	#comp: {
		#names: dns: short: "shop-web"
		spec: expose: {
			type: "ClusterIP"
			ports: http: {name: "http", targetPort: 8080, protocol: "TCP"}
			name?: string
		}
	}
}).out

_testServiceNameLegacyResolves: "\(_testServiceNameLegacy)" & "shop-web"

// Exact name wins over the component's own name.
_testServiceNameExact: (#ServiceName & {
	#comp: {
		#names: dns: short: "istio-istiod"
		spec: expose: {
			name: "istiod"
			type: "ClusterIP"
			ports: "https-dns": {name: "https-dns", targetPort: 15012, protocol: "TCP"}
		}
	}
}).out

_testServiceNameExactResolves: "\(_testServiceNameExact)" & "istiod"
