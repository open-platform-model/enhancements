# 02-publish-plan-gates — Module and Catalog Publishing

Status: Running

Pins: D1's one-pipeline-two-kinds, D2's derive-never-compose, D3's `--version` semantics, D4's identity-completeness gate, D6's local-override asymmetry, and D8's schema-path lookup — as `schemas/target.cue`'s `#PublishPlan` executed rather than unified.

## Hypothesis

The whole publish decision is computable from the artifact's own committed bytes plus the flags on the command line: coordinates **derived** from what the artifact declares rather than composed from parts, each gate refusing with the offending field and file named, and one implementation serving both artifact kinds with the differences reduced to which package identity lives in, whether a version exists in source, and whether the local-override escape hatch applies.

And the gate D4 exists for is genuinely necessary: `cue mod publish` will push a tree whose identity is not concrete.

## Setup

Self-contained; nothing outside this directory is read or modified. No registry (`--dry-run` only), no network beyond CUE's own dependency resolution, nothing pushed.

- **`variants/`** — six complete little CUE modules, each isolating one condition. They are separate modules rather than packages in one, because half the gates compare the artifact's declared identity against its **own `cue.mod/module.cue`**, which only exists per module.
  - `ok-catalog` — concrete identity, `cue.mod` agrees, no override.
  - `unfilled-catalog` — `Version` open.
  - `renamed-catalog` — every value right, the version field named `CatalogVersion`. This is the case the rejected `role=` marker existed to find; it vets clean on its own, so only the schema-path lookup catches it (D8).
  - `skew-catalog` — `cue.mod` declares `…/other@v1`, identity declares `…/demo@v1`.
  - `override-catalog`, `override-module` — carry `cue.mod/local-module.cue`.
  - `ok-module` — a module, which under 0010 D2 declares no version at all.
- **`local/core/`** — a stub module that exists only so the overrides in the two `override-*` variants resolve. The gate is about the file's **presence** (D6), so the override has to be a working one; a broken override would test "the tree does not load" instead.
- **`main.go`** — the planner. `plan()` is `#PublishPlan` as Go: same fields, same gates, and a refusal list in place of a failed unification. `go.mod` requires `cuelang.org/go v0.17.1`, matching `cli`.
- **`run.sh`** — fourteen invocations plus the three CUE-native measurements the gates exist for.

Identity is read from the artifact's **identity file** rather than by decoding the whole artifact through `core`. That is enough for every gate here and keeps the variants small; the production command would decode the artifact as well.

Identity fields are located by their **schema-fixed path** (0010 D22, D8): `ModulePath` and `Version` for a catalog, `metadata.modulePath` for a module. There is no marker attribute to scan for — `identitySpecs()` is the whole lookup, and it is a transcription of what `#IdentityPackage` and `#Module` name. A field that is not at its path is `absent`, which is a refusal rather than a cue to search wider.

## Run

```bash
bash run.sh
```

Requires `cue` v0.17.1 and Go 1.26 on PATH. First run resolves CUE dependencies for the override variants.

## Outcome

Observed 2026-07-26 with cue v0.17.1, Go 1.26.2. **Re-run 2026-07-29** after D22/D8 replaced the marker lookup with the schema-path lookup: every verdict below reproduced unchanged, and the `renamed-catalog` row is new.

| Invocation | Verdict |
| --- | --- |
| clean catalog | **GO** — `example.com/catalogs/demo:v1.2.0`, tag from the artifact's own `Version` |
| unfilled catalog | REFUSED — `Version` unfilled, at `identity/identity.cue:9:1` |
| unfilled catalog, `--version 1.2.0` | **GO** — tag from `--version` |
| clean catalog, `--version 9.9.9` | REFUSED — disagrees with the declared `1.2.0`; publish asserts, it does not overwrite |
| clean catalog, `--version 1.2.0` | **GO** — assertion holds |
| renamed field (`CatalogVersion`) | REFUSED — `Version` not declared at its schema-fixed path |
| `cue.mod` skew | REFUSED — both paths named |
| catalog + local override | REFUSED |
| catalog + local override + `--allow-local-override` | REFUSED — the flag does not apply to catalogs |
| module + local override | REFUSED, escape hatch offered by name |
| module + local override + `--allow-local-override` | **GO** |
| module without `--version` | REFUSED — a module declares no version in source |
| module, `--version 9.1.0` against a `@v2` path | REFUSED — tag major skew |
| clean module, `--version 2.1.0` | **GO** — `example.com/m/acme/media_server:v2.1.0` |

**Hypothesis held.**

### Dropping the marker cost the planner nothing and made one refusal sharper

The 2026-07-29 re-run replaced an attribute walk (`Value.Walk` + `Attributes(cue.FieldAttr)` + a `role` argument to read off each one, ~35 lines) with a two-entry table and a `LookupPath` per field (~15 lines). Every one of the thirteen original verdicts reproduced identically, which is the expected result and worth stating: the gates read identity *values*, and how a field was located never entered any of them.

What changed is what happens to a field that is not where the schema says. Under the marker, an unmarked-but-correct field read as `absent` and a *renamed* field could be found if it carried `role=version` — that accommodation was the marker's whole remaining justification. `renamed-catalog` measures what replaces it: a catalog whose values are all correct and whose version field is named `CatalogVersion` **vets clean on its own** (`cue vet -c ./...`, exit 0) and is refused by the planner naming the schema-fixed path it failed to find. So the condition is caught, it is caught by the publisher rather than by a consumer, and the diagnosis names a contract rather than a missing attribute.

That variant also exposed an asymmetry in the refusal list. The `open` case already carried a guard against the tag rule restating the same problem (`already refused above; do not say it twice`); the `absent` case had none, so a renamed field produced two refusals for one cause — the missing field, then "no version available from the artifact or from `--version`". Fixed rather than recorded, because the intent was clearly present in the `open` path already. One cause, one refusal.

### D4's gate is necessary, and its evidence needs correcting on one point

Against the unfilled tree, in the same directory, in the same session:

```
$ cue mod publish v1.2.0 --dry-run
dry-run published example.com/catalogs/demo@v1.2.0 to registry.cue.works/example.com/catalogs/demo:v1.2.0
exit 0
```

CUE will publish an artifact whose identity is not concrete. That is the whole argument for the gate and it reproduces exactly as D4 records it.

The other half of D4's evidence does not. D4 says `cue vet` without `-c` "reports `some instances are incomplete` and **exits 0**". Measured here on the same tree, it reports that line and **exits 1**:

```
$ cue vet ./...
some instances are incomplete; use the -c flag to show errors or -c=false to allow incomplete instances
exit 1
```

The exit code turns out to depend on where the unfilled value sits. In enhancement 0010's experiment 01, `cue vet ./cat` exits 1 (the catalog root's `metadata.version` is a regular field) while `cue vet ./mod` exits **0** — even though every primitive that module demands carries an open version — because the module's incompleteness is reachable only through definitions. So the correct claim is narrower and still supports the gate: **a default `cue vet` catches an unfilled catalog and misses an unfilled module**, and `cue mod publish` catches neither. D4's conclusion stands; its evidence sentence should be rewritten to what reproduces.

### Deriving beats composing, and the plan shows why

Every coordinate in the plan is a read or a split of one declared string:

```
declaredPath    example.com/m/acme/media_server@v2     ← the artifact's own metadata.modulePath
registryRepo    example.com/m/acme/media_server        ← before the "@"
major           v2                                     ← after the "@"
tag             v2.1.0                                 ← --version
```

There is no place in that sequence for a prefix and a name to be joined, which is where `cli/pkg/module/module.go`'s `CanonicalModuleRef()` / `majorVersionTag()` / `ensureVPrefix()` live today. They have no work left.

The `cue.mod` agreement check is worth keeping separate from the derivation even though both read a path: the failure it catches — an artifact whose identity says one thing and whose module says another — is invisible to CUE, which is perfectly happy to publish `…/demo@v1`'s bytes to `…/other@v1`'s repository.

### The two artifact kinds differ in exactly three places

Reducing D1's table to code, the whole difference is:

1. **Where identity lives** — a module's root package vs a catalog's `identity/` subpackage, which under D8 is two rows of a table rather than two code paths (0010 D23 keeps that asymmetry deliberately).
2. **Whether a version exists in source** — a catalog's `Version` is a field to read or fill; a module has none, so `--version` is mandatory rather than optional.
3. **Whether the local-override flag applies** — modules yes, catalogs never.

Everything else — the split, the tag rule, the completeness gate, the `cue.mod` check — is shared. That is a stronger result than "one pipeline, two entry points": the entry points differ by three predicates, not by a code path.

### Smaller observations

- **A refusal list beats a single error.** `skew-catalog` and a hypothetical unfilled-and-skewed tree both benefit: the author fixes everything in one pass. `#PublishPlan`'s `_unpublishable` already anticipates this for identity fields; it is worth extending to every gate rather than only that one.
- **`--version` against a concrete field must compare, not overwrite**, and getting that wrong is silent: the artifact would be published under a tag its own `Version` contradicts. It is one comparison, and it belongs beside the tag derivation rather than in the writer.
- **A tree that does not load has no readable identity**, and reporting that as "identity absent" blames the wrong thing. The planner surfaces the load error instead. This matters most for exactly the trees the override gate targets, where a stale local path is a common state.
- **`cue mod publish` needs `source:` in `cue.mod/module.cue`** (`cue mod edit --source`), or it refuses before it looks at anything else. Not a design point, but it will be part of the publish preflight in practice.
