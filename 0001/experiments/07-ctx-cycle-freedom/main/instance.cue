// Main case: three components cross-referencing via #ctx.components inside
// `spec` (downstream of #names). Per D2/D3, this evaluates to a fully
// concrete value because #names depends only on metadata + #release, and
// #ctx.components is a comprehension downstream of #names.
//
// Component graph (cross-refs):
//   api    → reads worker.dns.fqdn   (cross)
//   worker → reads api.dns.fqdn      (cross — mutual)
//   db     → reads its own #names    (self)
//
// `cue eval ./main/...` MUST succeed with three concrete spec.url strings.
package main

import schema "enhancements.opmodel.dev/0001/experiments/07-ctx-cycle-freedom/schema"

main_module: schema.#Module & {
	metadata: {
		name:       "ctx-cycle-main"
		modulePath: "opmodel.dev/experiments/0001/07"
		version:    "1.0.0"
		uuid:       "00000000-0000-0000-0000-000000000007"
	}
	#components: {
		api: {
			#resources: {}
			spec: url: "http://\(#ctx.components.worker.dns.fqdn)"
		}
		worker: {
			#resources: {}
			spec: url: "http://\(#ctx.components.api.dns.fqdn)"
		}
		db: {
			// Self-reference via #ctx.components.<self-id> projection — the
			// projection IS the comprehension over #names, semantically
			// identical to "#names.dns.fqdn" but resolvable from inside spec's
			// lexical scope (CUE references resolve before unification, and
			// #names lives only in #Component's definition body, not in the
			// outer literal's scope; #ctx is a sibling of #components at the
			// #Module level so it IS in scope).
			#resources: {}
			spec: selfUrl: "http://\(#ctx.components.db.dns.fqdn)"
		}
	}
	#config:     {}
	debugValues: {}
	#ctx: release: {
		name:      "ctx-cycle-prod"
		namespace: "ctx-cycle-prod"
		uuid:      "00000000-0000-0000-0000-000000000017"
	}
}

// Surfaced concrete results — hidden fields don't render in `cue eval` output;
// re-export the strings we care about so they show up.
results: {
	api_url:    main_module.#components.api.spec.url
	worker_url: main_module.#components.worker.spec.url
	db_url:     main_module.#components.db.spec.selfUrl
	api_fqdn:   main_module.#ctx.components.api.dns.fqdn
	db_fqdn:    main_module.#ctx.components.db.dns.fqdn
}
