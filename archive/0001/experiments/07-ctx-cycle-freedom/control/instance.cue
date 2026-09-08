// Control case: a component whose metadata.resourceName depends on its OWN
// #ctx.components.<self-id>.dns.fqdn — which derives from resourceName via
// #names. This is the cycle D2's comprehension architecture is supposed to
// prevent in normal use.
//
// CUE MUST report a structural cycle here. Capture the exact message in the
// experiment Outcome.
package control

import schema "enhancements.opmodel.dev/0001/experiments/07-ctx-cycle-freedom/schema"

control_module: schema.#Module & {
	metadata: {
		name:       "ctx-cycle-control"
		modulePath: "opmodel.dev/experiments/0001/07"
		version:    "1.0.0"
		uuid:       "00000000-0000-0000-0000-000000000077"
	}
	#components: {
		cyclic: {
			// resourceName depends on its own dns.fqdn, which derives from
			// resourceName. Cycle.
			metadata: resourceName: #ctx.components.cyclic.dns.fqdn
			#resources: {}
			spec: {}
		}
	}
	#config:     {}
	debugValues: {}
	#ctx: release: {
		name:      "ctx-cycle-ctl"
		namespace: "ctx-cycle-ctl"
		uuid:      "00000000-0000-0000-0000-000000000087"
	}
}

// Force CUE to materialize the cycle. Surfacing a hidden field's concrete
// value triggers the cycle resolution that `cue eval` would otherwise skip.
cycle_probe: control_module.#components.cyclic.#names.dns.fqdn
