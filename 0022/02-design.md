# Design — Machine-Readable Artifact Metadata in cue.mod/module.cue

## Design Goals

- A consumer that holds an artifact's `cue.mod/module.cue` learns its kind, its identity, its core line and the catalogs it was built against, without the zip.
- The block cannot lie: every value that repeats something the module file or the identity package states is asserted equal at publish, and a mismatch refuses.
- The block is authored by tooling in the committed tree, never generated at publish, so 0011's "published bytes are committed bytes" holds unchanged.
- Facts that exist only at push time are carried where CUE already puts its own (OCI manifest annotations), and never in the tree.
- CUE's package manager needs no change and never sees anything it does not already carry.
- The published fleet is never invalidated: an artifact without the block keeps resolving, and readers fall back.

## Non-Goals

- **A new artifact format.** CUE's two-layer module manifest is kept as is.
- **Projecting evaluated content.** Anything that needs the zip (component contracts, `initValues`) is a later entry's field under the same key.
- **Provenance beyond identification.** Annotations name the publisher, the toolchain and the commit; signing and attestation are 0011's stated non-goal and stay so.
- **Reading the block anywhere but 0016 D5.** Further readers come with their own entries.

## High-Level Approach

Two channels, split by when a fact is known:

```text
                     committed tree                          push time
                 ┌──────────────────────────┐          ┌─────────────────────────┐
  authored by    │ cue.mod/module.cue       │          │ OCI manifest            │
  tooling        │   module: ...            │          │   annotations:          │
  (init, version │   deps: ...              │  publish │     org.cuelang.vcs-*   │
  set, template  │   custom: "opmodel.dev@v0": {        ├─────────►│     dev.opmodel.publisher│
  re-identify)   │     kind, identity,      │  gate    │     dev.opmodel.cue     │
                 │     core, catalogs }     │  checks  │     ...                 │
                 │ identity/identity.cue    │  block   │ layer 0: zip (verbatim) │
                 │   ModulePath, Version    │  against │ layer 1: module.cue     │
                 └──────────────────────────┘  these   │          (verbatim)     │
                                                       └─────────────────────────┘
                                                                  │
                                            reader (0016 D5): manifest + layer 1 only
                                            kind? core.major? -> select / skip
                                            no block? -> parse deps (today's rule)
```

**The block** is plain data under `custom."opmodel.dev@v0"`. CUE parses `module.cue` in data mode, so the block holds concrete values only: no references, no definitions, no defaults. That is fine, because the block states facts, not rules.

**The gate** lives in `core` beside `#IdentityPackage` and is applied by publish exactly as 0011 D21 applies the identity gate: publish already loads `module:`, `deps` and the identity package; it fills those into the gate's implied side, unifies the block into the declared side, and surfaces CUE's own error on conflict. The gate is a definition, not a comparator, so there is one statement of the contract.

**The writer** is the tooling 0011 already trusts to touch the tree: `opm module init` seeds the block when it seeds identity; `version set` and `publish --version` keep `identity.Version` in step when they write the identity version; template re-identification rewrites `identity.ModulePath` when it rewrites `module:`. Publish reads and refuses; it never writes.

**The annotations** are written at push, beside CUE's VCS keys, through the client call CUE provides for that purpose. They are not in the zip, not in the module file, and not in any committed byte, so 0011 D2 holds to the letter.

**The reader** (0016 D5) already fetches the manifest and layer 1 per candidate major. With the block it reads two fields; without it, it does what it does today.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue) (core delta) and [`contracts/contracts.cue`](contracts/contracts.cue) (annotations, reader ladder).

**Core: two new publish-gate definitions** (§5 of SPEC.md, beside `#IdentityPackage`):

- `#ModuleFileCustom`: the block shape. `kind` (`module | catalog | template`), `identity {ModulePath, Version}`, `core {major, version}`, `catalogs` (catalog module path with major to version, possibly empty). Every field required, every value concrete.
- `#ModuleFileCustomGate`: declared beside implied. Inputs are what publish already holds: `module:`, the identity `Version`, the `deps` map. Implied values: `identity.ModulePath` is `module:`; `identity.Version` is the identity version; `core.version` is the pin of `opmodel.dev/core@<core.major>` in `deps`; `catalogs` contains every `opmodel.dev/catalogs/*` dep at its pin, and every declared catalog is a dep at that pin. Unification is the check.

Additive: no existing definition changes; nothing in `core` unifies against these; an artifact without the block is unaffected by the schema.

**CLI:**

- Publish applies the gate when the block is present; refusal names the conflicting field with CUE's diagnostic and the writer verb that fixes it. Absence is a warning until the D8 date, then a refusal.
- `opm module init` seeds the block; `version set` / `publish --version` maintain `identity.Version`; template re-identification maintains `identity.ModulePath`. Same surgical-edit posture as the identity writer (comments preserved, no-op when equal).
- Publish writes annotations: CUE's `org.cuelang.vcs-*` and OPM's `dev.opmodel.*` keys (set in `contracts/`).
- `opm instance init`'s major walk (0016 D5) reads `kind` and `core.major` from the block, falling back to today's `deps` parse.

**Module file, as authored** (cert_manager, after `cue mod tidy` normalisation):

```cue
module: "opmodel.dev/modules/cert_manager@v2"
language: version: "v0.17.0"
source: kind: "self"
deps: {
	"opmodel.dev/catalogs/opm@v2": v: "v2.0.0-alpha.2"
	"opmodel.dev/core@v2":         v: "v2.0.0-alpha.4"
}
custom: "opmodel.dev@v0": {
	kind: "module"
	identity: {ModulePath: "opmodel.dev/modules/cert_manager@v2", Version: "2.0.1"}
	core: {major: "v2", version: "2.0.0-alpha.4"}
	catalogs: "opmodel.dev/catalogs/opm@v2": "2.0.0-alpha.2"
}
```

## Integration Points

- **`core/`**: the two definitions and their SPEC.md §5 section, under the `core-schema-edit` protocol. Pure additive.
- **`cli/`**: the gate beside the identity gate; the writer beside the identity writer; annotations at the push; the 0016 reader. The publish pipeline's existing reads of `module:` and `deps` are the gate's inputs.
- **`catalog_opm/` and `modules/`**: each artifact's committed `cue.mod/module.cue` gains the block, produced by running the writer once per tree; thereafter `version set` maintains it. No artifact content changes.
- **`opmodel.dev/`**: the registry-namespaces page states that kind is now declared, and a module-file reference section documents the block.

## Before / After

**Before** (0016 D5 walk, per candidate major): fetch manifest, fetch layer 1, parse `deps`, find the key that starts with `opmodel.dev/core@`, split its major, handle its absence by a rule the reader invented; kind is the path prefix.

**After**: fetch manifest, fetch layer 1, read `custom."opmodel.dev@v0".core.major` and `.kind`; if the block is absent, do the above. The gate makes the two answers identical whenever both exist, and the report can say "template, skipped" instead of guessing from a path.
