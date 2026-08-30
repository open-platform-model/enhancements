# Problem Statement: Machine-Readable Artifact Metadata in cue.mod/module.cue

## Current State

A published OPM artifact is a CUE module in an OCI registry: one manifest, a zip of the module's files (layer 0) and the module's `cue.mod/module.cue` on its own (layer 1, media type `application/vnd.cue.modulefile.v1`). CUE's client fetches the module file without the zip (`Module.ModuleFile` reads only layer 1), and the file is small: 226 bytes for `opmodel.dev/modules/cert_manager` v2.0.1, whose zip is 230 268 bytes (enhancement 0016, experiment 02). That file states the module path, the language floor and the dependency pins, and nothing else.

CUE's module-file schema reserves one field for exactly this situation. `custom?: [#Module | "legacy"]: [_]: _` is documented as "arbitrary data intended for use by third-party tools; each field at the top level represents a tooling namespace, conventionally a module or domain name". It shipped in CUE v0.9.0, `modfile.Parse` returns it, `cue mod tidy`, `get` and `edit` carry it across rewrites, `cue mod publish` pushes the module file byte-for-byte, and fetch returns it unchanged. OPM writes nothing there.

The OCI manifest also carries annotations. CUE defines three (`org.cuelang.vcs-type`, `-commit`, `-commit-time`) and ignores unknown keys. OPM's publish calls the plain `PutModule` and writes no annotations at all.

What a consumer can learn about an artifact today without the zip is therefore its dependency pins and its path. Kind is inferred from the path prefix, and only inside domains OPM owns: `opmodel.dev/modules/`, `catalogs/`, `templates/`. A third-party path such as `example.com/platform/tooling@v1` says nothing about whether it is a module, a catalog or a template.

## Gap / Pain

1. **Kind is a guess outside OPM's own namespace.** `opm instance init` (0016) must refuse a template or a catalog, and the registry-namespaces reference says path inference "holds only inside OPM-owned domains". A third-party module cannot be told apart from a third-party catalog without fetching and evaluating it.
2. **Compatibility is derivable, but only by parsing.** A consumer that wants "which core line was this built against" reads `deps` and matches the `opmodel.dev/core@vN` key by hand. 0016's experiment 02 does exactly that and found artifacts with no such key at all (pre-v2 lines on `opmodel.dev/core/v1alpha1`). Every reader re-implements the same lookup and the same edge cases.
3. **Nothing records who published.** No annotation, no field. When a published artifact turns out malformed there is no way to tell which `opm` or which toolchain wrote it, or from which commit.
4. **The channel that would solve all three already exists and is empty.** The module file is fetched anyway by every consumer that resolves the artifact, and CUE reserved a namespace in it for this purpose.

## Concrete Example

`opmodel.dev/modules/cert_manager` has eight published versions across three majors (0016 experiment 01). 0016's D5 walk must pick the newest major whose core line the CLI can build. Today it fetches each candidate's module file and parses `deps`:

```text
cert_manager v2.0.1  deps: opmodel.dev/core@v2 v2.0.0-alpha.4   -> compatible with a core-v2 CLI
cert_manager v1.1.1  deps: opmodel.dev/core@v1 v1.1.0           -> skip
cert_manager v0.1.0  deps: (no opmodel.dev/core dependency)     -> skip, by a rule the reader had to invent
```

With the block, the same 226-byte blob says it outright:

```cue
custom: "opmodel.dev@v0": {
	kind: "module"
	identity: {ModulePath: "opmodel.dev/modules/cert_manager@v2", Version: "2.0.1"}
	core: {major: "v2", version: "2.0.0-alpha.4"}
	catalogs: "opmodel.dev/catalogs/opm@v2": "2.0.0-alpha.2"
}
```

and the reader checks `kind == "module"` and `core.major == "v2"` without knowing how `deps` keys are spelled. The publish gate guarantees that block agrees with `module:`, `identity/identity.cue` and `deps` at the moment it was pushed, so the reader trusts it exactly as far as it trusts the pins.

## User Stories

- As a **CLI developer**, I want artifact kind and core compatibility as named fields in the module file so that `opm instance init` and the platform tooling read one field instead of each re-deriving the answer from `deps` and path shapes. Today: every reader parses `deps` and pattern-matches paths.
- As a **module or catalog author**, I want the block written and kept in step by the same tooling that writes my version so that I never author it by hand and a stale block cannot be published. Today: no block exists; the identity version is the only tool-written value.
- As a **platform operator**, I want to know which `opm` and which commit produced a published artifact so that a bad build can be traced to its source. Today: nothing records it.

## Why Existing Workarounds Fail

- **Parse `deps` and infer.** Works for `opmodel.dev/*` and only there; every reader re-implements it, and each meets the same edge cases (no core dep, several catalogs) alone.
- **A sidecar artifact or a second tag.** Not content-addressed with the module: it can drift from the zip it describes, needs its own publish step, and CUE's own tooling never sees it.
- **A third OCI layer.** CUE's client rejects any manifest that does not have exactly two layers, so this breaks every CUE consumer.
- **Evaluate the module.** Correct and complete, and it costs the zip plus a CUE evaluation per candidate, which is what the D5 walk exists to avoid.
