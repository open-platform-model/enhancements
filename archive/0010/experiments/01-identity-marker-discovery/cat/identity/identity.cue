// Package identity is the single source of this catalog's identity.
//
// It sits at the bottom of the catalog's import graph — it imports nothing
// within the module — so the resources/, traits/, blueprints/ and
// transformers/ subpackages can source ModulePath and Version without a
// circular import, and the root catalog.cue can stamp transformer metadata in
// lockstep.
//
// D5: this file is COMMITTED, VISIBLE, and TOOL-WRITTEN. `opm catalog version
// set` and `opm catalog publish --version` write into it the way `npm version`
// writes package.json. Nothing here is generated behind the author's back, and
// nothing is gitignored.
//
// D5 (placement): the subpackage is FORCED, not chosen. The leaves compute
// their own FQNs at their own definition sites; a root-supplied constant makes
// root and leaves import each other, which CUE rejects with
// "package import cycle not allowed" (measured — enhancement 0003 exp 03).
package identity

import "strings"

// #VersionType mirrors core.#VersionType (SemVer 2.0). Duplicated here so the
// identity package stays import-free at the bottom of the graph — the same
// mirror convention catalog_opm/src/identity/identity.cue already uses.
#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// ModulePath is the catalog's COMPLETE CUE module path, major suffix included
// (D1). Every FQN this catalog ships is derived from it, so it must be
// concrete for the tree to evaluate at all.
//
// D6: ModulePath is DERIVABLE — it is exactly the `module:` line in
// cue.mod/module.cue, so any opm command that touches the tree can fill it
// offline and deterministically. In practice it is always concrete.
ModulePath: "example.com/catalogs/demo@v1" @opm(identity, owner=publish)

// Version is the catalog's compatibility signal (D3) — a full SemVer that is
// never part of any key. It travels on every primitive as metadata.version and
// is what the matcher compares when a demand misses (D12).
//
// LEFT OPEN HERE ON PURPOSE (D6). An open field is an ABSENT value, not a
// placeholder one: CUE refuses to build on it and names this file and line.
// The retired alternative — `#VersionType | *"0.0.0-dev"` — is a value: it
// evaluates, renders, and flows into keys, so a dev tree and a published tree
// both vet clean while disagreeing.
//
// CHOICE POINT — 03-decisions.md D6 writes the open form as `Version: string`.
// This file writes `Version: #VersionType`, which is open in exactly the same
// sense (non-concrete, CUE refuses to build on it) while still rejecting a
// non-SemVer the moment a tool writes one. The cost is that a writer filling
// it must decide between replacing the whole value with "1.2.0" and unifying
// into `#VersionType & "1.2.0"` — see enhancements/0011 experiment 01.
Version: #VersionType @opm(identity, owner=publish)

// ─── Derived — not tool-owned, no marker ────────────────────────────────────
//
// FINDING, and a correction to 02-design.md's "Leaf files are unchanged".
//
// Today a leaf writes `modulePath: "\(id.ModulePath)/resources"`. Under D1
// that yields ".../demo@v1/resources" — the major is terminal, so the
// subpackage segment cannot simply be appended. Every leaf would have to
// split the major out and re-append it, and CUE has no string slicing, so
// each one would need `strings.SplitN` and an import of "strings".
//
// Splitting once here keeps that out of the leaves entirely: a leaf writes
// `modulePath: id.Prefix.resources` and still names no version and no major.
// (Importing the "strings" BUILTIN does not compromise this package's
// position at the bottom of the graph — the constraint is that it imports
// nothing WITHIN the module.)
//
// CHOICE POINT — schemas/target.cue expresses this as
// #CatalogIdentity.primitivePrefix, a {kind!: ..., out: ...} shape a leaf must
// call as `(id.primitivePrefix & {kind: "resources"}).out`. The enumeration
// below reads better at the call site and additionally rejects a typo'd kind
// ("undefined field: resourcs") where the parametrized form silently accepts
// any string. Its cost: adding a primitive KIND touches this file in every
// catalog. There are four kinds and core fixes them, so that cost is bounded.
//
// A third form — a `#PrimitivePath` helper exported by core, called as
// `(c.#PrimitivePath & {catalog: id.ModulePath, kind: "resources"}).out` —
// centralises the splice in core instead of repeating it in every catalog's
// identity.cue, at the price of a clunkier call site. Not implemented here.
//
// MEASURED: a pattern constraint (`Prefix: [Kind=string]: …`) does NOT work.
// `id.Prefix.resources` fails with "undefined field: resources" — a pattern
// constraint constrains keys that exist, it does not generate them.
_p: strings.SplitN(ModulePath, "@", 2)

// RegistryPath is the OCI repository this catalog's tags hang off.
RegistryPath: _p[0]

// Major is the identity-bearing version component — read, never parsed.
Major: _p[1]

// Prefix.<kind> is the complete module path of a primitive subpackage.
//   Prefix.resources => "example.com/catalogs/demo/resources@v1"
Prefix: {
	resources:    RegistryPath + "/resources@" + Major
	traits:       RegistryPath + "/traits@" + Major
	blueprints:   RegistryPath + "/blueprints@" + Major
	transformers: RegistryPath + "/transformers@" + Major
}
