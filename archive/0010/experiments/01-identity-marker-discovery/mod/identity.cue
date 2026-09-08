// This is a module's whole identity — one line, committed and visible (D5).
//
// D7: it writes `metadata:` DIRECTLY and declares no top-level field. A
// top-level `ModulePath: "…"` here would vet clean standalone and fail only
// when the module is unified into the closed #ModuleInstance.#module slot,
// with "field not allowed" pointing at this file (measured). A hidden
// `_modulePath` would also be acceptable; a visible one is not.
//
// D5 (placement): a module keeps identity in its OWN ROOT PACKAGE, not in an
// identity/ subpackage. Modules are single-package, so nothing computes an FQN
// across a package boundary and there is no cycle to break — and referencing a
// subpackage would force the author to write the module's own path in an
// import statement, relocating the duplication rather than removing it.
//
// D6: this field is DERIVABLE from cue.mod/module.cue, so it is filled by any
// opm command that touches the tree and is effectively always concrete. That
// is load-bearing: with modulePath concrete, every FQN in the tree still
// evaluates while Version is open. With it open, `strings.SplitN` over a
// non-concrete string returns an empty list and the FQN derivation fails with
// "index out of range [0] with length 0" — an error pointing at the wrong thing.
package media_server

metadata: modulePath: "example.com/m/acme/media_server@v2" @opm(identity, owner=publish)
