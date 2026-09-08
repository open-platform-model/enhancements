// Package schema is a minimal, self-contained slice of `core/src/*.cue`,
// copied (never imported) per the experiments rules. Copied 2026-07-29 from:
//
//   core/src/types.cue      (#NameType, #VersionType, #KebabToPascal)
//   core/src/resource.cue   (#Resource, #ResourceMap)
//   core/src/component.cue  (#Component — trimmed to the fields Match reads)
//   core/src/transformer.cue(#ComponentTransformer — trimmed to the maps
//                            unifyIntersection walks)
//
// TWO DELIBERATE DEVIATIONS FROM SHIPPED core, both under test:
//
//  1. `#FQNType` is MAJOR-keyed (`path/name@v1`) rather than SemVer-keyed
//     (`path/name@1.2.0`). Under the shipped scheme the two sides of every
//     case below carry DIFFERENT keys and never meet in the matcher at all,
//     so there is nothing to measure. The whole question only exists once one
//     key spans several builds.
//  2. A primitive carries `apiVersion` (the contract major, which keys the
//     FQN) and `catalogVersion` (the build it shipped in, provenance only).
//     Shipped core has a single `version` that does both.
//
// Everything else is structural: `spec!: (strings.ToCamel(#definitionName)): _`
// is reproduced exactly, because the dynamic field label and the `_` leaf are
// among the things that could plausibly decide the closedness answer.
package schema

import "strings"

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

// SemVer 2.0 — the build a primitive shipped in.
#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#PackagePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*$"

// The contract major. Widened beyond core's `#MajorVersionType` (`^v[0-9]+$`)
// to admit the alpha/beta forms the discussion settled on for pre-stable
// contracts.
#APIVersionType: string & =~"^v[0-9]+((alpha|beta)[0-9]+)?$"

// MAJOR-keyed primitive FQN — `path/name@v1`.
#FQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+((alpha|beta)[0-9]+)?$"

// Copied verbatim from core/src/types.cue.
#KebabToPascal: {
	X="in": string
	let _parts = strings.Split(X, "-")
	out: strings.Join([for p in _parts {
		let _runes = strings.Runes(p)
		strings.ToUpper(strings.SliceRunes(p, 0, 1)) + strings.SliceRunes(p, 1, len(_runes))
	}], "")
}

#Resource: {
	kind: "Resource"

	metadata: {
		name!: #NameType
		#definitionName: (#KebabToPascal & {"in": name}).out

		modulePath!:     #PackagePathType
		apiVersion!:     #APIVersionType
		catalogVersion!: #VersionType

		fqn: #FQNType & "\(modulePath)/\(name)@\(apiVersion)"

		description?: string
	}

	spec!: (strings.ToCamel(metadata.#definitionName)): _
}

#ResourceMap: [string]: #Resource

#Component: {
	kind: "Component"

	metadata: name!: #NameType

	#resources: #ResourceMap
}

#ComponentTransformer: {
	kind: "ComponentTransformer"

	metadata: {
		name!:           #NameType
		modulePath!:     #PackagePathType
		apiVersion!:     #APIVersionType
		catalogVersion!: #VersionType

		fqn: #FQNType & "\(modulePath)/\(name)@\(apiVersion)"

		description!: string
	}

	requiredResources?: [#FQNType]: #Resource
	optionalResources?: [#FQNType]: #Resource
}
