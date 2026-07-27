# 03-identity-subpackage-necessity — OPM Module Publishing Workflow

Status: Concluded

Pins: OQ13 — establishes whether enhancement 0001's D7 + D19 (sibling `identity/` subpackage) survive a reversal of its D8 + D9

## Hypothesis

The sibling `identity/` subpackage exists for a reason **independent of publish-time stamping**: without it, the catalog root package and its transformer subpackage import each other (root imports transformers to assemble `#transformers`; transformers imports root to read the shared version), which CUE rejects as a package import cycle. If true, `identity/` must be retained under *any* version-authoring alternative, and reversing 0001 D8/D9 does not imply reversing D7/D19.

## Setup

Self-contained; nothing outside this directory is read or modified. Two variants inside one CUE module, each a three- or two-package catalog reduced to the minimum that exhibits the import topology.

`with_identity/` — the production topology (0001 D7/D19):

- `identity/identity.cue` (package `identity`) — `ModulePath` + `Version`. Imports nothing inside the module: the bottom of the graph.
- `transformers/foo.cue` (package `transformers`) — imports `identity`, builds `#FooTransformer.metadata.fqn` from it.
- `catalog.cue` (package `with_identity`) — imports **both** `identity` and `transformers`, assembles `#transformers` keyed by the transformer's own FQN.

`without_identity/` — the same catalog with the identity package removed:

- `catalog.cue` (package `without_identity`) — declares the shared `Catalog: {ModulePath, Version}` constant at the root **and** imports `transformers` to assemble `#transformers`.
- `transformers/foo.cue` (package `transformers`) — must reach back into the root package to read `Catalog.Version`.

The FQN interpolations mirror `core/src/catalog.cue`'s shapes; the `#ComponentTransformer` body is reduced to metadata only, since the claim is about package topology, not schema shape.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0003/experiments/03-identity-subpackage-necessity@v0"`, language `v0.17.0`.

## Run

```bash
for v in with_identity without_identity; do
  echo "== $v"
  cue vet -c ./$v/...                      ; echo "  vet -c exit=$?"
  cue export ./$v -e shipped --out yaml
done
```

## Outcome

Observed 2026-07-25 with cue v0.17.1.

| Variant | `cue vet -c` | Result |
| --- | --- | --- |
| `with_identity` | 0 | exports `example.com/cat@1.0.0-alpha.2` and `example.com/cat/transformers/foo@1.0.0-alpha.2` |
| `without_identity` | **1** | `import failed: … package import cycle not allowed`, citing both `catalog.cue:5:8` and `transformers/foo.cue:5:8` |

**Hypothesis held.** The cycle is real and CUE names both ends of it. The `identity/` subpackage is load-bearing for a reason that has nothing to do with how the version is *authored* or *stamped*: it is the only way a subpackage can source catalog-wide identity without the root and the subpackage importing each other.

**Implications:**

1. **0001 D7 and D19 survive any decision about D8/D9.** A move to a strict committed version (experiment 02, variant B) changes what `identity.Version` *contains* — a concrete SemVer instead of a sentinel disjunction — and removes the `version_override.cue` stamping step. It does not touch the package topology. "Reverse D8 + D9, keep D7 + D19" is structurally coherent, not a compromise.
2. The alternative topology of duplicating the version into each subpackage was not tested, because it reintroduces exactly the multi-source-of-truth drift this enhancement exists to remove — it would vet clean while permitting subpackages to disagree with the catalog root.
