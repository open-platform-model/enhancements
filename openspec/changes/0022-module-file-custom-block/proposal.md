# 0022: Machine-Readable Artifact Metadata in cue.mod/module.cue

A published OPM artifact states its kind, identity and compatibility in its small module file. A reader learns them without downloading the zip. Publish refuses a stale fact.

## Why

A CUE module in a registry is one manifest and two blobs: the zip and the module file. For one shipped module the module file is 226 bytes and the zip is 230,268. The module file states only the path and the pins. A consumer that wants the kind, or the core line, must download the zip or parse the dependencies. Outside OPM's own domains the kind is a guess from the path. Nothing records who published an artifact.

## What Changes

- The module file of a module, catalog or template carries one OPM block with the artifact's kind, identity, core line and catalogs.
- Publish refuses a block that disagrees with the module path, the dependencies or the identity package.
- Tooling writes the block in the committed source. Publish never does.
- Push-time facts (publisher, toolchain, commit) go into registry manifest annotations.
- Instance initialisation reads kind and core major from the block, and falls back to the dependencies. A missing block warns first and refuses from a dated release.

## What this is not

- Not a new artifact format. CUE's two-layer manifest stays.
- Not content from inside the zip. Facts that need evaluation come in a later entry.
- Not signing or attestation. Annotations only identify the publisher.
- Not a block on `core` or the kernel library.

## Example

```cue
custom: "opmodel.dev@v0": {
	kind: "module"
	identity: {ModulePath: "opmodel.dev/modules/cert_manager@v2", Version: "2.0.1"}
	core: {major: "v2", version: "2.0.0-alpha.4"}
	catalogs: "opmodel.dev/catalogs/opm@v2": "2.0.0-alpha.2"
}
```

## Capabilities

- **New:** `module-file-block`, `block-publish-gate`, `block-authoring`, `block-reader`
- **Modified:** `module-authoring`, `published-module-resolution`

## Impact

- **Authors** run the writer once per tree. After that their version tool keeps the block in step.
- **CLI developers** read kind and core major from one field.
- **Operators** see which tool version and commit published an artifact.
- **Five repos** change: core, cli, catalog_opm, modules and opmodel.dev. The change is not breaking: the gate fires only when a block is present.

## Open questions

- Blocking: What does the gate do with a dependency that sits outside the first-party catalog paths, such as a third-party catalog? Options: the author lists it and the gate only checks it is a dependency at its pin; the gate reads the dependency's own block and requires the kind catalog; or third-party catalogs stay out of scope until one exists. The answer decides the implied side of the gate.
- Blocking: Does the gate assert `kind` against the path prefix inside OPM-owned domains (`modules/` and `templates/` imply module, `catalogs/` implies catalog)? It catches a copy-pasted block but ties the gate to paths. If it asserts, is the kind template required or only allowed under `templates/`?
- Not blocking: Which annotation keys does publish write? Proposed: a publisher key, a CUE toolchain key and a block key. Also open: whether CUE's own VCS keys are always written, and what a publish without a VCS writes.
- Blocking: What is the exact wording of the decision that amends the version writer's single target in entry 0011? The writer must also keep the version inside the block in step. The text must be agreed before acceptance, because accepted records are protected.
- Not blocking: Does the gate still pass after dependency tidying re-encodes the block? Values stay intact on 20 of 20 fleet modules, but the gate itself has not run against the tidied files. The change that lands the gate settles it.
- Blocking: What does a reader or gate do with a kind it does not know? The kind list is closed, so an older core refuses a block that names a newer kind. Either an unknown kind is opaque to readers and gates, or a new kind is a meaning change that moves the key suffix past `v0`. A listing index is one candidate new kind, and the entry that defines module listing decides whether it asks for one.
