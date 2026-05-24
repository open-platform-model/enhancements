// Three-component cascade probe — exercises every branch of the
// `metadata.resourceName: *name | #NameType` disjunction-default cascade.
//
//   default-name      → no metadata.name set; defaults to map key
//                       "default-name"; resourceName defaults to that
//   explicit-name     → metadata.name: "explicit-svc"; resourceName
//                       defaults to metadata.name
//   explicit-override → metadata.name: "internal"; metadata.resourceName:
//                       "public"; override wins
//
// Plus byte-identity assertions between #components.<id>.#names and
// #ctx.components.<id>.
//
// Lives in the same package as target.cue (`schema`); `cue eval ./...`
// fails the file if any unification mismatches.
package schema

cascade_module: #Module & {
	metadata: {
		name:       "cascade-probe"
		modulePath: "opmodel.dev/experiments/0001/01"
		version:    "1.0.0"
		uuid:       "00000000-0000-0000-0000-000000000001"
	}
	#components: {
		"default-name": {
			// neither metadata.name nor metadata.resourceName set
			#resources: {}
			spec: {}
		}
		"explicit-name": {
			metadata: name: "explicit-svc"
			// metadata.resourceName not set → defaults to metadata.name
			#resources: {}
			spec: {}
		}
		"explicit-override": {
			metadata: {
				name:         "internal"
				resourceName: "public" // override wins
			}
			#resources: {}
			spec: {}
		}
	}
	#config:     {}
	debugValues: {}
	#ctx: release: {
		name:      "cascade-prod"
		namespace: "cascade-prod"
		uuid:      "00000000-0000-0000-0000-000000000011"
	}
}

// Surfaced results — hidden fields don't render in `cue eval` output.
results: {
	default_resource: cascade_module.#components."default-name".#names.resourceName
	default_fqdn:     cascade_module.#components."default-name".#names.dns.fqdn

	explicit_resource: cascade_module.#components."explicit-name".#names.resourceName
	explicit_fqdn:     cascade_module.#components."explicit-name".#names.dns.fqdn

	override_resource: cascade_module.#components."explicit-override".#names.resourceName
	override_fqdn:     cascade_module.#components."explicit-override".#names.dns.fqdn
}

// Byte-identity: #ctx.components.<id> is the comprehension projection of
// #components.<id>.#names. Unification fails if they differ.
identity_checks: {
	default_match: cascade_module.#ctx.components."default-name" & cascade_module.#components."default-name".#names
	explicit_match: cascade_module.#ctx.components."explicit-name" & cascade_module.#components."explicit-name".#names
	override_match: cascade_module.#ctx.components."explicit-override" & cascade_module.#components."explicit-override".#names

	// Concrete value assertions — `cue vet` fails if any string differs from
	// the expected.
	default_expected:  default_match.resourceName & "default-name"
	explicit_expected: explicit_match.resourceName & "explicit-svc"
	override_expected: override_match.resourceName & "public"
}
