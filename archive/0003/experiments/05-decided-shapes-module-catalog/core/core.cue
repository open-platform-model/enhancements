// Trimmed copy of the core shapes this experiment exercises, reflecting
// decisions D13-D20. Copied 2026-07-26 from core/src/{types,module,catalog,
// resource,transformer}.cue and MODIFIED to the decided shapes — the diffs
// ARE the experiment. Copy, never reference (experiments skill rule 3).
//
// Every line that differs from today's core carries a CHANGED or REMOVED
// comment naming the decision and the current source line, so a reviewer can
// diff by eye without opening core/.
package core

import (
	"strings"
	cue_uuid "uuid"
)

// Copied verbatim from core/src/types.cue:52.
OPMNamespace: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

#NameType:      string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
#SnakeNameType: string & =~"^[a-z0-9]([a-z0-9_]*[a-z0-9])?$"
#VersionType:   string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
#UUIDType:      string & =~"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

// CHANGED (D16/D17). Today core/src/types.cue:20 is:
//   #ModulePathType: =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"
//
// The rule is now simply "whatever CUE accepts as a module path, plus the
// mandatory major suffix". CUE permits both hyphens and underscores in path
// segments (verified: `github.com/open-platform-model/my-thing@v1` evaluates
// and tidies clean), so OPM does not narrow the character class. What OPM
// constrains is the LEAF, and it does that with a constraint rather than a
// regex — `_leafOK` below requires the leaf to equal metadata.name, which is
// itself snake_case. Domains and org segments therefore stay exactly as CUE
// spells them ("opmodel.dev", "open-platform-model") while the module's own
// segment is snake.
#ModulePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$"

// CHANGED (D18). Primitive FQNs are MAJOR-keyed. Today core/src/types.cue:46
// requires a full SemVer tail, lifted there by enhancement 0001 D5 so that
// adjacent builds occupy distinct keys; D18 reverses that and moves divergence
// detection off the key. The path portion gains underscores for the same
// reason as #ModulePathType; the NAME segment stays kebab-case, since primitive
// names are #NameType and are not CUE identifiers.
#FQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+$"

// REMOVED (D13/D16/D17): #ModuleFQNType (path/name:semver) and #CatalogFQNType
// (path@semver). Both artifacts' fqn is now just modulePath, which is already
// #ModulePathType, so neither type has anything left to say.

// #SplitPath decomposes a full module path into registry path + major. This is
// the operation that REPLACES every "compose an address from a prefix and a
// name" site — cli/pkg/module/module.go:74 and the library import helper.
// A module path carries at most one "@", always at the end, so SplitN(2) is
// exact. (CUE has no string slicing, so LastIndex + slice is not available.)
#SplitPath: {
	in!:          string
	_p:           strings.SplitN(in, "@", 2)
	registryPath: _p[0]
	major:        _p[1]
}

// ─── #Module ────────────────────────────────────────────────────────────────

#Module: {
	kind: "Module"
	metadata: {
		// CHANGED. name is now SNAKE_CASE, authored directly. Today
		// core/src/module.cue:12 types it #NameType (kebab) and derives
		// nameSnakeCase from it via #KebabToSnake.
		//
		// REMOVED as a consequence: nameSnakeCase, #KebabToSnake, and the
		// #SnakeNameType/#NameType split for modules. They exist only to
		// project kebab onto snake; if name is already snake there is no
		// projection left to make, and "one identity, one canonical
		// projection" collapses to just "one identity". Note this DELETES
		// surface this very enhancement added — nameSnakeCase landed in core
		// on 2026-06-17 as D2.
		name!: #SnakeNameType

		// modulePath is NOT authored in module source — it comes from the
		// module's generated identity package. OQ18 asks whether generation is
		// the right mechanism; this experiment implements it so it can be read.
		modulePath!: #ModulePathType

		// REMOVED (D13): version!: #VersionType
		// Nothing in a module declares a version. The version is the tag the
		// artifact was published at; the kernel holds it as a coordinate.

		// CHANGED (D16): fqn was "\(modulePath)/\(name):\(version)".
		fqn:  #ModulePathType & modulePath
		uuid: #UUIDType & cue_uuid.SHA1(OPMNamespace, fqn)

		// D1's constraint, now checkable INSIDE one field rather than across
		// two independently-authored ones. With name already snake, this is a
		// direct comparison — no projection in between.
		_leafOK: true & strings.HasSuffix((#SplitPath & {in: modulePath}).registryPath, "/"+name)

		// REMOVED (D14/D15): "module.opmodel.dev/version" label. The kernel
		// stamps it from the resolved coordinate, because only the code that
		// fetched the artifact knows which one it got.
		labels: {
			"module.opmodel.dev/name": name
			"module.opmodel.dev/uuid": uuid
		}
	}

	// Components demand primitives by FQN. Under D18 those FQNs are
	// major-keyed, so they are stable across the catalog's whole 1.x line.
	#components: [Id=#NameType]: {
		id: Id
		demands: [...#FQNType]
	}
}

// ─── #Catalog ───────────────────────────────────────────────────────────────

#Catalog: {
	kind: "Catalog"
	M=metadata: {
		// From the catalog's generated identity package, same as #Module.
		modulePath!: #ModulePathType

		// REMOVED — THIS IS READING B, AND THE THING TO CONFIRM.
		// The phrasing was "remove #Catalog.metadata.version and only rely on
		// the identity subpackage", so the catalog root declares no version;
		// primitives read id.Version directly for their own metadata.version
		// (the compat signal), and the pattern constraint below no longer
		// stamps a version at all.
		//
		// READING A, if this is wrong, restores one line here:
		//     version!: #VersionType   // valued from the generated identity
		// and one line in #transformers below.
		//
		// CHANGED (D17): fqn was "\(modulePath)@\(version)".
		fqn: #ModulePathType & modulePath
	}

	// CHANGED (D17/D18). The constraint still stamps modulePath, but it must
	// SPLIT the major out and re-append it — under D16 the "@v1" sits
	// mid-string, so plain concatenation would yield ".../opm@v1/transformers".
	// It no longer stamps `version` (Reading B).
	#transformers: [#FQNType]: #ComponentTransformer & {
		metadata: modulePath: (#SplitPath & {in: M.modulePath}).registryPath + "/transformers@" + (#SplitPath & {in: M.modulePath}).major
	}
}

// ─── Primitives ─────────────────────────────────────────────────────────────

// #PrimitiveMetadata is shared by #Resource, #Trait, #Blueprint and
// #ComponentTransformer. It holds the D18/D19 separation in one place:
// fqn is the MATCH KEY (major only), version is the COMPATIBILITY SIGNAL
// (full SemVer, read from the catalog's identity package).
#PrimitiveMetadata: {
	name!:       #NameType
	modulePath!: #ModulePathType
	version!:    #VersionType

	// CHANGED (D18): fqn was "\(modulePath)/\(name)@\(version)".
	fqn: #FQNType & ((#SplitPath & {in: modulePath}).registryPath + "/" + name + "@" + (#SplitPath & {in: modulePath}).major)
}

#Resource: {
	kind:     "Resource"
	metadata: #PrimitiveMetadata
}

#ComponentTransformer: {
	kind:     "ComponentTransformer"
	metadata: #PrimitiveMetadata
	requiredResources: [...#FQNType]
}
