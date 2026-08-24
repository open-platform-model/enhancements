# Enhancement 0022 — Machine-Readable Artifact Metadata in cue.mod/module.cue

See [`config.yaml`](config.yaml) for metadata. This README is the index of the seven split documents plus the Scope and Cross-References tables; everything else lives in the split files.

## Summary

A CUE module in an OCI registry is one manifest and two blobs: the module zip and, on its own, `cue.mod/module.cue`. The module file is tiny (226 bytes for `opmodel.dev/modules/cert_manager` v2.0.1 against a 230 268-byte zip) and CUE's client reads it without touching the zip. CUE's module-file schema reserves a `custom` field for third-party tooling data, and its toolchain carries that field through `tidy`, `publish` and fetch untouched. Today OPM writes nothing there, writes no OCI manifest annotations either, and infers what kind of artifact a path names only inside domains OPM owns.

This entry defines OPM's block under `custom."opmodel.dev@v0"` (D1, D2): the artifact `kind`, its identity, the core line and the catalogs it was built against. Every value that repeats something the module file or the identity package already states is asserted equal by a publish gate that `core` ships beside `#IdentityPackage` (D4), so duplication cannot drift and a stale block refuses rather than lies. Tooling authors the block in the committed tree, the way `version set` authors the identity version; publish never writes it (D5), which keeps 0011's "published bytes are committed bytes" intact. Facts that only exist at push time (which `opm` and `cue` published, which commit) go to OCI manifest annotations, outside the tree (D6). The first reader is 0016's major walk, which can now learn core compatibility and artifact kind from the small blob alone (D7).

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from this entry's `delivery.yaml` log — run `task delivery ID=NNNN`. A
status block written here is a snapshot that goes stale the moment another change
lands, which is exactly the drift the implementation axis was removed to stop.
-->

## Documents

1. [01-problem.md](01-problem.md) — An artifact says nothing machine-readable about its kind or compatibility short of fetching and evaluating its zip
2. [02-design.md](02-design.md) — A gate-checked block in the module file for facts consumers want before the zip; OCI annotations for facts that exist only at push
3. [03-decisions.md](03-decisions.md) — Decision log (D1–D8)
4. [04-graduation.md](04-graduation.md) — Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, Alternatives not taken
6. [06-operational.md](06-operational.md) — Observability, semver impact, deprecation, rollback, cross-repo coordination
7. [07-questions.md](07-questions.md) — Open Questions register

Pure-CUE definitions live in [`schemas/target.cue`](schemas/target.cue) (the block shape `#ModuleFileCustom` and the publish gate `#ModuleFileCustomGate`, the core delta) and [`contracts/contracts.cue`](contracts/contracts.cue) (the OCI annotation key set and the reader's fallback ladder).

## Scope

### In scope

- The block: key `"opmodel.dev@v0"` under `custom` in `cue.mod/module.cue`, carrying `kind`, `identity {ModulePath, Version}`, `core {major, version}` and `catalogs` (D1, D2), on module, catalog and template artifacts (D3).
- A `core`-shipped publish gate that asserts the block's duplicated values against `module:`, `identity/identity.cue` and `deps`, refusing on mismatch with CUE's own diagnostic (D4), applied by publish the way 0011 D21 applies `#IdentityPackage`.
- Authoring by tooling: `opm module init` seeds the block, the version writer keeps `identity.Version` in step, template re-identification rewrites `identity.ModulePath` (D5). This needs one amendment inside 0011 (its D3/D8 name a single writer target); the wording is OQ4.
- OCI manifest annotations for push-time provenance, written by publish beside CUE's own `org.cuelang.vcs-*` keys (D6).
- The first reader: 0016 D5's major walk reads `core.major` and `kind` from the blob, with a `deps`-parse fallback for artifacts published before the block (D7).
- A grace window before a missing block becomes a publish refusal (D8).

### Out of scope

- Not an OPM OCI artifact format, not publish-generated content, not a provenance or SBOM record, and not a replacement for identity/identity.cue.
- **Anything inside the zip.** Facts that need the module evaluated (component contracts, `initValues`) are not projected into the block by this entry; a later entry may add such fields under the same key.
- **A second blob or OCI referrer.** CUE's manifest admits exactly two layers; a companion artifact is a separate design if one is ever needed.
- **`core` and `library` as carriers.** Nothing selects them by kind or compatibility.
- **Pre-v2 core lines.** Only the `opmodel.dev/core@v2` line is in scope; older artifacts are what the D7 fallback exists for.

## Relationship to adjacent enhancements

- **[0011](../0011/)** owns publishing, and this entry extends it. Reused unchanged: D21's mechanism (core ships a definition, publish unifies against it in Go and surfaces CUE's error), D16's posture (publish enforces the author's `cue.mod`, never edits it) and D2 (published bytes are committed bytes). Amended: D3 and D8 name `identity/identity.cue` `Version` as the writer's only target; with D5 here the writer also keeps the block's `identity.Version` in step, so 0011 gains a new decision carrying `**Amends:** D3, D8` once this entry is accepted (OQ4).
- **[0016](../0016/)** is the first reader. Its D5 walk already fetches the module-file blob per candidate major (experiment 02); with the block it reads `core.major` and `kind` directly instead of parsing `deps`, and refuses templates and catalogs by name rather than by path prefix.
- **[0010](../0010/)** fixed identity: `module:` is byte-identical to `identity.ModulePath`. The gate here leans on that equality rather than restating it.

## Deviations from Design

None at this stage. Update this section when implementation lands and any deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/src/identity_package.cue` | `#IdentityPackage` and `#CatalogMemberFQNGate`: the publish-gate pattern (declared beside implied, unification is the check) the new gate follows |
| `core/SPEC.md` §5 | Publish Gates: where the new gate's specification section lands |
| `cli/internal/publish/identity.go` | How publish unifies a loaded value against a core gate and surfaces CUE's error; the new gate is applied the same way |
| `cli/internal/publish/load.go` | Where publish already reads `module:`, `source.kind` and `deps.*.v` from `module.cue`: the implied side of the gate |
| `cli/internal/publish/registry.go` | The push: zips the tree in place and calls `PutModule`; annotations (D6) land beside it |
| `cli/internal/cueedit/cueedit.go` | The surgical `module.cue` and identity editors the writer (D5) extends |
| `cli/internal/scaffold/scaffold.go` | Template re-identification, which must rewrite the block's `identity.ModulePath` (D5) |
| `opmodel.dev/site/content/reference/registry-namespaces.md` | Documents that artifact kind is inferred from path only inside OPM-owned domains |
| `enhancements/0016/experiments/02-core-major-probe/` | Measured cost of reading the module-file blob without the zip |
| `modules/cert_manager/cue.mod/module.cue` | Concrete module file used as the example throughout |
