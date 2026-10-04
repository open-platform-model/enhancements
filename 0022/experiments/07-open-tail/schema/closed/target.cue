// Core-schema delta for enhancement 0022 — Machine-Readable Artifact
// Metadata in cue.mod/module.cue.
//
// Delta manifest (vs opmodel.dev/core@v2):
//
//   - #ModuleFileCustomKey — NEW: the `custom` namespace key OPM owns,
//     "opmodel.dev@v0" (D1). The suffix is the block's own schema major.
//   - #ArtifactKind — NEW: "module" | "catalog" | "template" (D2, D3).
//   - #ModuleFileCustom — NEW: the block shape (D2). Plain data: CUE parses
//     cue.mod/module.cue in data mode, so nothing here may be referenced
//     from the module file itself; the definition is a PUBLISH GATE input
//     (SPEC.md §5), never embedded by an artifact.
//   - #ModuleFileCustomGate — NEW: the gate publish unifies against (D4),
//     declared beside implied in the #CatalogMemberFQNGate style. Inputs are
//     what publish already holds: the module file's `module:` and `deps`,
//     and the identity package's Version.
//
// The two core types the block uses (#ModulePathType, #VersionType) are
// restated here verbatim from core/src/types.cue (core commit a11aefc),
// because the published core@v2 alpha does not yet export them under these
// names and the delta must vet on its own; the real change imports them.
//
// Fields gated on an Open Question carry an `// OQN:` marker pointing at
// ../07-questions.md.
package schema

import "strings"

// Mirrors of core/src/types.cue; not part of the delta.
#ModulePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$" & strings.MinRunes(1) & strings.MaxRunes(254)
#VersionType:    string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// #ModuleFileCustomKey: the one key OPM writes under `custom`. Chosen to
// satisfy both the live module-file schema (any string) and CUE's dormant
// #Strict variant (which requires an @vN suffix). Bumped only when a key in
// #ModuleFileCustom changes meaning or is removed (D1).
#ModuleFileCustomKey: "opmodel.dev@v0"

// #ArtifactKind: what the artifact is. Templates are module-kind at publish
// (0011 D25) but a template is what a scaffolder looks for and an instance
// initializer refuses, so it names itself (D3).
#ArtifactKind: "module" | "catalog" | "template"

// #ModuleFileCustom: the block an artifact carries at
// custom[#ModuleFileCustomKey]. Every field required, every value concrete.
#ModuleFileCustom: {
	kind!: #ArtifactKind

	// identity repeats the two authored values of identity/identity.cue.
	// ModulePath is byte-identical to the module file's `module:` (0010 D1);
	// Version is the one identity value the module file does not carry.
	identity!: {
		ModulePath!: #ModulePathType
		Version!:    #VersionType
	}

	// core names the core line the artifact was built against: the major
	// (what a compatibility check compares) and the exact pin from deps.
	core!: {
		major!:   =~"^v[0-9]+$"
		version!: #VersionType
	}

	// catalogs maps every catalog dependency (module path with major, the
	// same string that keys deps and a platform's registry map) to its exact
	// pin. May be empty.
	catalogs!: [#ModulePathType]: #VersionType
}

// #ModuleFileCustomGate: what publish unifies the block against. The
// `declared` field is stated twice: once as the block the artifact wrote,
// once as the module file and identity package imply. Unification is the
// check, so a stale block fails at the field with CUE's own error (D4).
#ModuleFileCustomGate: {
	// Inputs publish already holds.
	module!:          #ModulePathType // cue.mod `module:`
	identityVersion!: #VersionType    // identity/identity.cue Version
	deps!: [string]: v!: string            // cue.mod `deps`, v-prefixed pins

	// The block as authored.
	declared!: #ModuleFileCustom

	// What the inputs imply. Each line is an assertion.
	declared: identity: ModulePath: module
	declared: identity: Version:    identityVersion
	declared: core: version: strings.TrimPrefix(deps["opmodel.dev/core@"+declared.core.major].v, "v")

	// Every first-party catalog dependency appears at its pin.
	// OQ1: catalog dependencies outside opmodel.dev/catalogs/ are not implied
	// here; whether they are author-declared and checked, or resolved through
	// their own block, is open.
	declared: catalogs: {
		for p, d in deps if strings.HasPrefix(p, "opmodel.dev/catalogs/") {
			(p): strings.TrimPrefix(d.v, "v")
		}
	}

	// And every declared catalog is a dependency at that pin.
	_catalogsAreDeps: {
		for p, v in declared.catalogs {
			(p): deps[p].v & ("v" + v)
		}
	}

	// OQ2: whether `kind` is additionally asserted against the path prefix
	// inside OPM-owned domains is open; no implied value for kind is stated.
}
