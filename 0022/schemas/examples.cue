// Concrete example instances for the target.cue delta — the test.
//
// A cert_manager-shaped artifact (modules/cert_manager at v2.0.1, deps as
// published) carries a block that passes the gate; hidden assertions pin
// the implied values so a change in the gate's behaviour breaks `cue vet`.
// Drift cases cannot be expressed as passing unifications; they are listed
// at the bottom as the inputs experiment 03 refuses, with the field each
// one fails on.
package schema

// The block as `opm module init` / `version set` author it.
certManagerBlock: #ModuleFileCustom & {
	kind: "module"
	identity: {
		ModulePath: "opmodel.dev/modules/cert_manager@v2"
		Version:    "2.0.1"
	}
	core: {
		major:   "v2"
		version: "2.0.0-alpha.4"
	}
	catalogs: "opmodel.dev/catalogs/opm@v2": "2.0.0-alpha.2"
}

// The gate as publish applies it: inputs from the module file and the
// identity package, the block unified into `declared`.
certManagerGate: #ModuleFileCustomGate & {
	module:          "opmodel.dev/modules/cert_manager@v2"
	identityVersion: "2.0.1"
	deps: {
		"opmodel.dev/catalogs/opm@v2": v: "v2.0.0-alpha.2"
		"opmodel.dev/core@v2":         v: "v2.0.0-alpha.4"
	}
	declared: certManagerBlock
}

// Pin the implied side so the assertions are visibly doing work.
_assertImpliedPath:    certManagerGate.declared.identity.ModulePath & "opmodel.dev/modules/cert_manager@v2"
_assertImpliedVersion: certManagerGate.declared.identity.Version & "2.0.1"
_assertImpliedCore:    certManagerGate.declared.core.version & "2.0.0-alpha.4"
_assertImpliedCatalog: certManagerGate.declared.catalogs["opmodel.dev/catalogs/opm@v2"] & "2.0.0-alpha.2"

// A catalog artifact: no catalog dependencies of its own, so `catalogs` is
// empty and the comprehension yields nothing.
catalogGate: #ModuleFileCustomGate & {
	module:          "opmodel.dev/catalogs/opm@v2"
	identityVersion: "2.0.0-alpha.5"
	deps: "opmodel.dev/core@v2": v: "v2.0.0-alpha.5"
	declared: {
		kind: "catalog"
		identity: {ModulePath: "opmodel.dev/catalogs/opm@v2", Version: "2.0.0-alpha.5"}
		core: {major: "v2", version: "2.0.0-alpha.5"}
		catalogs: {}
	}
}
_assertCatalogEmpty: len(catalogGate.declared.catalogs) & 0

// A template: module-kind at publish (0011 D25), self-named here (D3).
templateBlock: #ModuleFileCustom & {
	kind: "template"
	identity: {ModulePath: "opmodel.dev/templates/standard@v1", Version: "1.2.0"}
	core: {major: "v2", version: "2.0.0-alpha.4"}
	catalogs: "opmodel.dev/catalogs/opm@v2": "2.0.0-alpha.2"
}

// The key itself.
_assertKey: #ModuleFileCustomKey & "opmodel.dev@v0"

// Drift cases (experiment 03 records each error text). Each is
// certManagerGate with ONE value changed in `declared`, and the field the
// gate fails on:
//
//   identity.Version "2.0.0"            -> declared.identity.Version: conflicting values
//   identity.ModulePath "...@v3"        -> declared.identity.ModulePath: conflicting values
//   core.version "2.0.0-alpha.3"        -> declared.core.version: conflicting values
//   core.major "v1" (no such dep)       -> declared.core.version: TrimPrefix of an undefined field
//   catalogs missing the opm entry      -> declared.catalogs."opmodel.dev/catalogs/opm@v2": field required by the implied side
//   catalogs with an entry not in deps  -> _catalogsAreDeps.<path>: undefined field deps.<path>
