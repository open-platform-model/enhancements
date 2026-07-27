// Package core is a TRIMMED COPY of core/src/{types,module,catalog,resource,
// transformer,component}.cue taken 2026-07-26, modified to enhancement 0010's
// target shapes. Copy, never reference (experiments skill rule 3).
//
// Every divergence from today's core carries a CHANGED: or REMOVED: comment
// naming the decision and the current source line, so the delta can be read by
// eye without opening core/. Anything without such a comment is verbatim.
//
// Trimmed away entirely (not relevant to identity): #Trait, #Blueprint,
// #Platform, #ModuleRelease, #ctx / #instance wiring, #transform bodies,
// value schemas. The shapes that remain are the ones identity flows through.
package core

import (
	"strings"

	cue_uuid "uuid"
)

// ─── Types ──────────────────────────────────────────────────────────────────

#LabelsAnnotationsType: [string]: string | int | bool | [string | int | bool]

// Verbatim — core/src/types.cue:10. Primitive names stay kebab-case: they are
// not CUE identifiers and never serve as package names.
#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

// Verbatim — core/src/types.cue:17. Under D8 this stops being a projection
// target and becomes what a module author writes directly.
#SnakeNameType: string & =~"^[a-z0-9]([a-z0-9_]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

// CHANGED (D1, D8) — core/src/types.cue:20.
//   was: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"
// Two widenings. The "@vN" suffix is now mandatory, because a module path IS
// the complete CUE module path. And underscores are legal in path segments,
// because under D8 a module path ENDS IN the module's own snake_case name and
// every multi-word name contains one (media_server, cert_manager).
// Hyphens stay legal — CUE accepts them and OPM must be able to express its
// own organisation (github.com/open-platform-model/...). Only the LEAF is
// constrained to snake, and that constraint lives on #Module, not here.
#ModulePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$" & strings.MinRunes(1) & strings.MaxRunes(254)

// Verbatim — core/src/types.cue:22-24. Declared but unused in today's core;
// this is the design its doc comment describes.
#MajorVersionType: string & =~"^v[0-9]+$"

// Verbatim — core/src/types.cue:34. SemVer 2.0, no "v" prefix.
#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// CHANGED (D4) — core/src/types.cue:37-46.
//   was: ".../name@1.4.0"  (full SemVer in the key)
//   now: ".../name@v1"     (major only)
// A catalog's whole compatible series shares one key space, so a module built
// against any build of catalog@v1 matches a platform that materialized any
// other build of catalog@v1. The exact resolved version does not disappear —
// it moves to metadata.version beside the key (D12).
#FQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+$"

#UUIDType: string & =~"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

// REMOVED (D2) — core/src/types.cue:26-28, #ModuleFQNType (the "path/name:semver"
// form). A module's fqn is its modulePath; there is no second shape.
//
// REMOVED (D3/D4) — core/src/catalog.cue:10, #CatalogFQNType (the
// "modulePath@version" form). A catalog's fqn is its modulePath too.
//
// REMOVED (D8) — core/src/types.cue:69-72, #KebabToSnake. It exists only to
// project a kebab name onto a snake one; with `name` already snake there is
// nothing left to project.

// Verbatim — core/src/types.cue:52. MUST remain immutable.
OPMNamespace: "11bc6112-a6e8-4021-bec9-b3ad246f9466"

// Verbatim — core/src/types.cue:56-64. Keeps its other callers (primitives are
// still kebab); stops being applied to a module name.
#KebabToPascal: {
	X="in": string
	let _parts = strings.Split(X, "-")
	out: strings.Join([for p in _parts {
		let _runes = strings.Runes(p)
		strings.ToUpper(strings.SliceRunes(p, 0, 1)) + strings.SliceRunes(p, 1, len(_runes))
	}], "")
}

// NEW (D8) — CHOICE POINT, see core/src/module.cue:27.
// Today #Module.metadata.#definitionName is (#KebabToPascal & {in: name}).out.
// With a snake `name` that yields "Media_server", which is wrong. Two options:
//   (a) this snake-aware projection, keeping #definitionName available; or
//   (b) delete #definitionName from #Module entirely — 02-design.md leaves the
//       choice open ("a snake-aware projection or removal").
// (a) is implemented here so the consequence is visible; nothing in this
// experiment depends on which is chosen.
#SnakeToPascal: {
	X="in": string
	let _parts = strings.Split(X, "_")
	out: strings.Join([for p in _parts {
		let _runes = strings.Runes(p)
		strings.ToUpper(strings.SliceRunes(p, 0, 1)) + strings.SliceRunes(p, 1, len(_runes))
	}], "")
}

// ─── Address decomposition (D1) ─────────────────────────────────────────────

// NEW — from schemas/target.cue. Splits a complete module path into the OCI
// repository its tags live under and the major it declares. This single
// operation replaces every "compose an address from a prefix and a name" site
// in cli and library.
//
// A module path carries at most one "@", always terminal, so SplitN(2) is
// exact. CUE has no string slicing, so LastIndex-plus-slice is unavailable.
#ArtifactRef: {
	modulePath!: #ModulePathType

	_p: strings.SplitN(modulePath, "@", 2)

	registryPath: _p[0]
	major:        #MajorVersionType & _p[1]
	importPath:   modulePath
}

// ─── #Module (D1, D2, D7, D8, D9) ───────────────────────────────────────────

#Module: {
	kind: "Module"

	metadata: {
		// CHANGED (D8) — core/src/module.cue:12. Was #NameType (kebab).
		name!: #SnakeNameType // Example: "media_server"

		// REMOVED (D8) — core/src/module.cue:15-19, nameSnakeCase.

		// CHANGED (D1) — core/src/module.cue:21. Was a bare prefix
		// ("example.com/modules"); now the artifact's COMPLETE module path.
		// Written by the author's identity.cue (D5/D7), not by module.cue.
		modulePath!: #ModulePathType // Example: "example.com/m/acme/media_server@v2"

		// REMOVED (D2) — core/src/module.cue:22, version!. A module declares no
		// version at all; the full version is the coordinate it was published at
		// and resolved by, and the major arrives inside modulePath.

		_ref: #ArtifactRef & {"modulePath": modulePath}

		// CHANGED (D1) — core/src/module.cue:23.
		//   was: "\(modulePath)/\(name):\(version)"
		// fqn IS the module path. uuid keeps its formula (unchanged) over a
		// version-free, major-bearing input, so it is stable across every
		// release in the major and distinct between majors.
		fqn:  #ModulePathType & modulePath
		uuid: #UUIDType & cue_uuid.SHA1(OPMNamespace, fqn)

		// NEW (D8) — the path's leaf must equal `name`. Hidden rather than a
		// visible metadata field: this is an invariant, not data a consumer
		// reads. CHOICE POINT — schemas/target.cue expresses it as the visible
		// `leafMatchesName`, which produces a better error message
		// ("leafMatchesName: conflicting values false and true") than a hidden
		// field does. Trade-off: a visible boolean in every rendered metadata.
		_leafMatchesName: strings.HasSuffix(_ref.registryPath, "/"+name)
		_leafMatchesName: true

		// CHANGED (D8) — core/src/module.cue:27. See #SnakeToPascal above.
		#definitionName: (#SnakeToPascal & {"in": name}).out

		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType

		labels: {
			"module.opmodel.dev/name": "\(name)"
			// REMOVED (D9) — core/src/module.cue:36,
			//   "module.opmodel.dev/version": "\(version)"
			// The resolved coordinate is not a property of the module; only the
			// code that fetched an artifact knows which one it got. The kernel
			// stamps this label on the render path instead.
			"module.opmodel.dev/uuid": "\(uuid)"
		}
	}

	// Trimmed: the real #components pattern also wires #instance/#ctx.
	#components: [Id=#NameType]: #Component & {
		metadata: {
			name: string | *Id
			labels: "component.opmodel.dev/name": name
		}
	}
}

// ─── #Catalog (D3, D4, D12) ─────────────────────────────────────────────────

#Catalog: {
	kind: "Catalog"

	M=metadata: {
		// CHANGED (D1) — core/src/catalog.cue:62. Now the complete module path.
		modulePath!: #ModulePathType // Example: "example.com/catalogs/demo@v1"

		// KEPT, DEFAULT REMOVED (D3, D6) — core/src/catalog.cue:63.
		//   was: #VersionType | *"0.0.0-dev"
		// A catalog keeps a full SemVer because it is a vocabulary provider whose
		// consumers must be able to state a minimum. The sentinel default is gone:
		// a sentinel is a VALUE — it evaluates, renders, and flows into keys, so
		// "nobody set this" becomes indistinguishable from "somebody set this".
		// An unfilled field must be an ABSENT value instead.
		version!: #VersionType

		// CHANGED (D1) — core/src/catalog.cue:64.
		//   was: "\(modulePath)@\(version)"
		// The version is a compatibility signal, never part of a key.
		fqn: #ModulePathType & modulePath

		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// CHANGED (D1, D12) — core/src/catalog.cue:70-76.
	// The pattern constraint keeps stamping BOTH modulePath and version onto
	// every entry. modulePath now has to split the major out and re-append it,
	// because under D1 "@v1" sits mid-string and plain concatenation would
	// yield ".../demo@v1/transformers".
	//
	// The version stamp is KEPT rather than dropped (D12) because it is the only
	// STRUCTURAL guarantee available: this pattern constraint owns the
	// #transformers map, while resources/traits/blueprints are reached
	// transitively through required/optional maps and have no site for a
	// constraint to attach to. They supply their own version from the catalog's
	// identity package at their own definition sites.
	#transformers: [#FQNType]: #ComponentTransformer & {
		let _ref = #ArtifactRef & {modulePath: M.modulePath}
		metadata: {
			modulePath: _ref.registryPath + "/transformers@" + _ref.major
			version:    M.version
		}
	}
}

// ─── Primitives (D4, D12) ───────────────────────────────────────────────────

// The fqn/version split repeated on every primitive kind. In real core this is
// written out per file (resource.cue, trait.cue, blueprint.cue,
// transformer.cue); here it is one definition the two primitives below embed,
// purely to keep the copy short.
//
// BOTH FIELDS ARE LOAD-BEARING AT MATCH TIME (D12):
//   fqn      — the match key. Major only, so it is stable across the catalog's
//              whole compatible series.
//   version  — the catalog BUILD this definition came from. The matcher reads
//              it to say either "this platform has no subscription to that
//              catalog" or "it resolved an older build than this module needs",
//              in place of `no matching transformer`, which names neither.
#PrimitiveMetadata: {
	name!: #NameType

	// CHANGED (D1) — was a bare prefix; now the complete module path of the
	// SUBPACKAGE the primitive is defined in (".../demo/resources@v1").
	modulePath!: #ModulePathType

	// KEPT REQUIRED (D12) — core/src/{resource,trait,blueprint,transformer}.cue.
	// It no longer feeds the FQN; it is the compatibility signal that travels
	// with the primitive into every module built against it.
	version!: #VersionType

	_ref: #ArtifactRef & {"modulePath": modulePath}

	// CHANGED (D4) — was "\(modulePath)/\(name)@\(version)".
	fqn: #FQNType & (_ref.registryPath + "/" + name + "@" + _ref.major)

	#definitionName: (#KebabToPascal & {"in": name}).out

	description?: string
	labels?:      #LabelsAnnotationsType
	annotations?: #LabelsAnnotationsType
}

#Resource: {
	kind:     "Resource"
	metadata: #PrimitiveMetadata
	spec!: (strings.ToCamel(metadata.#definitionName)): _
}

#ComponentTransformer: {
	kind: "ComponentTransformer"
	metadata: #PrimitiveMetadata & {
		description!: string
	}

	requiredLabels?: #LabelsAnnotationsType
	requiredResources?: [#FQNType]: #Resource
	optionalResources?: [#FQNType]: #Resource

	// Trimmed: #transform body.
}

#Component: {
	metadata: {
		name!:        #NameType
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	#resources: [#FQNType]: #Resource

	// Component labels are the union of the labels its primitives carry.
	metadata: labels: {
		for _, r in #resources for k, v in r.metadata.labels {(k): v}
	}

	// Trimmed copy of core/src/component.cue:59-81 — the spec a component
	// exposes is the merge of its primitives' specs. Unchanged by this
	// enhancement; present only so the module below can set values.
	_allFields: {
		for _, resource in #resources {
			if resource.spec != _|_ {resource.spec}
		}
	}
	spec: close({_allFields})
}
