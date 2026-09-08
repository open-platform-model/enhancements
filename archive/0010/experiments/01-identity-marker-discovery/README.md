# 01-identity-marker-discovery — Module and Catalog Identity

Status: Concluded

> **The marker this experiment discovers was dropped by D22 (noted 2026-07-29).** The fixtures and observations below are unedited and still reproduce; what changed is that identity fields no longer carry `@opm()` at all, so nothing in the design has a marker to discover. Read this as the measurement that *retired* the mechanism rather than one that supports it: finding 3 — that a reference does not carry the declaration's attribute, so a consumer can never see a marker — is what established the marker could never carry a guarantee, and its closing line ("what a reader relies on is the schema") is the argument D22 acts on. The recommendation in section 0, that D5's marker gain a `role` argument, is **rejected** by D22 and 0011 D8.

> **Recorded before D13 (noted 2026-07-27).** The observations below are unedited — they are what the run produced on 2026-07-26, against the then-current major-keyed FQN design. D13 reverted that: primitive FQNs carry the full SemVer again. Two consequences for reading this experiment. The `…@v1` values in the outcome tables would today read `…@1.2.0`, which does not affect what the experiment tested — marker discovery is indifferent to the key's shape. But section 3's finding **no longer holds under the current design**: it observed that every FQN still evaluates while `Version` is open, because only `ModulePath` fed the key. With the version back inside the FQN, an open `Version` leaves the whole key space non-concrete. That is recorded as a drawback in `05-risks.md`; the measurement here remains valid for the design it was run against.

Pins: the READ half of D5 and D6 — the `@opm()` marker as a machine-readable handle, and the open-vs-concrete distinction the whole "absence is not a placeholder" argument rests on. Also carries the target `#Module` / `#Catalog` / primitive shapes as authored CUE, so the schemas this enhancement produces can be reviewed as code rather than as a decision log.

Enhancement 0011 owns writing and publishing; this experiment only reads.

## Hypothesis

An OPM tool can locate every identity field it owns **by the `@opm()` marker alone** — never by field name — in both a module's root package and a catalog's `identity/` subpackage, classify each as open or concrete with a source position, and do so through the ordinary CUE Go API with no OPM-specific loader.

And the split D6 rests on holds in a real tree: with `ModulePath` concrete and `Version` open, **every FQN, every match key and the module UUID still evaluate**, so an unfilled tree computes the whole key space and only the compatibility signal is missing.

## Setup

Self-contained; nothing outside this directory is read or modified. No registry, no network.

**One CUE module, three package trees.** The module, the catalog and core are packages under a single `cue.mod`, so the experiment runs with no registry and no `local-module.cue` wiring. Cross-module resolution is not what is being tested — identity supply is — and each artifact's identity comes from its own committed file regardless of the enclosing module path. The *declared* identities (`example.com/m/acme/media_server@v2`, `example.com/catalogs/demo@v1`) are therefore deliberately unrelated to the enclosing `example.com/exp0010@v0`. Enhancement 0011's experiment 02 is where the declared path has to agree with `cue.mod`, and it uses per-variant modules for exactly that reason.

- **`core/core.cue`** — trimmed copy of `core/src/{types,module,catalog,resource,transformer,component}.cue` taken 2026-07-26, modified to this enhancement's target shapes. Every divergence carries a `CHANGED:` or `REMOVED:` comment naming the decision and the current source line, so the delta reads by eye without opening `core/`. Anything without such a comment is verbatim. Copy, never reference (skill rule 3). Trimmed away entirely: `#Trait`, `#Blueprint`, `#Platform`, `#ModuleRelease`, `#ctx`/`#instance` wiring, `#transform` bodies.
- **`cat/`** — the catalog as an author writes it: `identity/identity.cue` (the tool-owned file), `catalog.cue`, `resources/configmaps.cue`, `transformers/configmap_transformer.cue`. Modelled on `catalog_opm/src/`. `Version` is left **open** in the committed tree — that is the state under test.
- **`mod/`** — the module as an author writes it: `identity.cue` (one line, D7's direct `metadata:` write) and `module.cue`. No `version`, no `modulePath`, no `nameSnakeCase`.
- **`main.go`** — the marker-driven reader. Hardcodes exactly one name, `"opm"`, and finds everything else through `cue.Value.Attributes`. Three sections: marker discovery with three-state classification (scanning four targets, including the catalog **root** package as a control on whether the marker survives a reference), an open-vs-filled comparison of every derived value, and the error an open field produces. `go.mod` requires `cuelang.org/go v0.17.1`, matching `cli` and `library`.
- **`run.sh`** — `cue vet`, `cue vet -c`, then the Go reader.

The filled and absent states are produced by **in-memory `load.Config.Overlay`**, never by editing the tree, so the committed bytes stay in the open state the design is about.

### Choice points deliberately left visible

Each is marked in the source with `CHOICE POINT`, and nothing in the experiment depends on which way they resolve:

- **`Version: #VersionType` vs D6's `Version: string`** (`cat/identity/identity.cue`). Both are open in the sense that matters; the typed form additionally rejects a non-SemVer the moment a tool writes one, at the price of giving the writer a conjunction to preserve. It also changes the error text: `incomplete value =~"^\\d+\\..."` rather than `incomplete value string`.
- **`_leafMatchesName` hidden vs `leafMatchesName` visible** (`core/core.cue`). `schemas/target.cue` uses the visible form, which produces the better message (`conflicting values false and true`); the hidden form keeps a boolean out of every rendered metadata.
- **`#definitionName` under a snake `name`** (`core/core.cue`). Implemented as a new `#SnakeToPascal`; `02-design.md` leaves "a snake-aware projection or removal" open.
- **Where the primitive-path splice lives** (`cat/identity/identity.cue`). Implemented as an enumerated `Prefix` in the identity package; the alternatives are `target.cue`'s parametrized `primitivePrefix` and a `#PrimitivePath` helper exported by core.

## Run

```bash
bash run.sh
```

Requires `cue` v0.17.1 and Go 1.26 on PATH. `go run` needs `cuelang.org/go v0.17.1` in the module cache or network access on first run.

## Outcome

Observed 2026-07-26 with cue v0.17.1, Go 1.26.2.

### 1. Marker discovery works, and it is genuinely name-free

| Artifact | Field found | State | Position reported |
| --- | --- | --- | --- |
| module `./mod` | `metadata.modulePath` | concrete | `./mod/identity.cue:23:23` |
| catalog `./cat` (root package) | — | **nothing found** | — |
| catalog `./cat/identity` | `ModulePath` | concrete | `./cat/identity/identity.cue:34:1` |
| catalog `./cat/identity` | `Version` | **open** | `./cat/identity/identity.cue:52:1` |

The reader hardcodes one string — `"opm"` — and no field name. Three properties held that the design assumes without having stated them:

- **Attributes survive unification with a closed definition.** The module's marker is written in `identity.cue` on `metadata: modulePath:`, unified into `core.#Module`'s closed `metadata`; the attribute is still readable and `Value.Path()` reports `metadata.modulePath`.
- **An open field keeps its attribute.** `Version: #VersionType @opm(...)` is non-concrete and still reports the marker, so a tool can locate a field it must fill *because* it is unfilled. This is what makes `version set` possible at all.
- **`Value.Pos()` points at the author's declaration**, not the definition site, so a refusal can name the file and line a human has to edit.

One mechanical caveat: the same attribute is reported under both `cue.FieldAttr` and `cue.ValueAttr` and must be deduped. And `Value.Walk` does not descend into definitions or hidden fields, so a marker placed inside a `#Definition` would not be found — every identity field in this design is a regular field, so it does not bite, but it is a constraint on where markers may be put.

**The marker does not survive a reference, and that is a placement rule, not a defect.** The catalog root writes `metadata: modulePath: id.ModulePath`; scanning the root package finds *nothing*, because the attribute is attached to the declaration in `identity/identity.cue` and a reference to that value does not carry it. Two consequences worth writing down: tooling must know **where** to look per artifact kind (a module's root package, a catalog's `identity/` subpackage — the same asymmetry D5 already forces for a different reason), and a **consumer can never see the marker** on an imported artifact. Neither is a problem for the design as scoped — the marker exists for the tooling that owns the tree — but the second one means the marker can never carry a guarantee a reader relies on. What a reader relies on is the schema: `#Catalog.metadata.version!` makes an absent field a build failure with or without a marker anywhere.

### 2. `absent` is not discoverable by marker — the tool must carry the expectation

Deleting the `Version` declaration (in-memory overlay) leaves nothing to find: a field that was never declared carries no attribute. The reader reports `ABSENT` only because it was told which fields a catalog must have.

This is a real constraint on 0011's `#IdentityState`. Its three states are not symmetric — `open` and `concrete` are *discovered*, `absent` is *asserted against a list the tool holds*. Either publish hardcodes the required identity fields per artifact kind, or the schema does the work: `#Catalog.metadata.version!` already makes an absent field a build failure before publish ever looks. The latter is strictly better, and it means publish's identity gate is really only ever distinguishing **open from concrete**.

### 3. D6's split holds: identity and keys evaluate while `Version` is open

Every value below evaluated against the committed tree (Version open) and against the same tree with `Version: "1.2.0"` overlaid:

| Value | Version open | Version filled | |
| --- | --- | --- | --- |
| module `metadata.fqn` | `example.com/m/acme/media_server@v2` | identical | same |
| module `metadata.uuid` | `4271367e-2d19-5d4b-af11-131bb3ea0aa6` | identical | same |
| catalog `metadata.fqn` | `example.com/catalogs/demo@v1` | identical | same |
| resource `metadata.fqn` | `…/demo/resources/config-maps@v1` | identical | same |
| transformer `metadata.fqn` | `…/demo/transformers/configmap-transformer@v1` | identical | same |
| module's demanded FQN | `…/demo/resources/config-maps@v1` | identical | same |
| catalog `metadata.version` | *open* | `1.2.0` | **MOVED** |
| resource `metadata.version` | *open* | `1.2.0` | **MOVED** |
| transformer `metadata.version` | *open* | `1.2.0` | **MOVED** |

The whole match key space is computable from an unfilled tree. Only the compatibility signal is missing, and asking for it produces a position, not a value:

```
metadata.version: incomplete value =~"^\d+\.\d+\.\d+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$":
    ./cat/identity/identity.cue:25:24
```

**Hypothesis held**, on both halves.

### Findings that change the design documents

Four, none of them fatal, all worth folding back before promotion.

**0. D5's marker needs a `role` argument.** This one comes from the write side — enhancement 0011's experiment 01 — and lands on D5 rather than on that entry. `@opm(identity, owner=publish)` says a field is identity that publish owns, but not *which* identity field it is, so `version set` has nothing to match on and falls back to `name == "Version"`, reintroducing the hardcoded name the marker exists to remove. `@opm(identity, role=version|modulePath, owner=publish)` fixes it in one argument, and 0011 experiment 01 demonstrates it finding a field named `CatalogVersion` that no name lookup would have found. Read-side discovery — everything in this experiment — works fine without it; the write side does not.

**a. `02-design.md` says "Leaf files are unchanged". They are not.** Today a leaf writes `modulePath: "\(id.ModulePath)/resources"`. Under D1 the major is terminal, so that interpolation yields `…/demo@v1/resources`, which is not a module path. The splice has to happen somewhere, and CUE has no string slicing, so doing it per leaf means `strings.SplitN` and a `"strings"` import in every primitive file. Splitting once in `identity.cue` and exposing `Prefix.resources` keeps the leaves as short as they are today — but the leaf line *does* change, and the design doc currently claims otherwise. (The claim is true of `import` statements, which is what its evidence is about.)

**b. `primitivePrefix` as written in `schemas/target.cue` is awkward at the call site, and the obvious alternative does not work.** A pattern constraint (`Prefix: [Kind=string]: …`) is unusable: `id.Prefix.resources` fails with `undefined field: resources`, because a pattern constrains keys that exist rather than generating them. What works is an enumerated struct, which has the side benefit of rejecting a typo'd kind. Worth reflecting into `target.cue`.

**c. `cue vet` without `-c` does not uniformly exit 0 on an unfilled tree**, which is narrower than the evidence recorded under 0011 D4. Measured here: `cue vet ./cat` exits **1** (`some instances are incomplete`) because `metadata.version` is a regular field on the catalog root; `cue vet ./mod` exits **0** although every primitive the module demands carries an open version, because the module's incompleteness sits inside definitions. So the publish gate is still necessary — the module case passes a default vet silently — but D4's sentence is broader than what reproduces. The `cue mod publish --dry-run` half of that measurement is not re-tested here; it belongs to 0011 experiment 02.

Also worth noting for anyone writing modules: a component must **embed** its catalog primitive (`#components: config: { res.#ConfigMaps, … }`), the way `modules/jellyfin/components.cue` does. Unifying with `&` re-closes the definition and the primitive's own `spec` is rejected as `field not allowed`. Unrelated to identity, but it cost time here and it is not written down anywhere.

### Conclusion — 2026-07-31

**The hypothesis held as measured on 2026-07-26, and the design has since moved past both halves — in opposite directions.**

**Half one — marker discovery — held, and was then retired by its own evidence.** Everything measured still reproduces: attributes survive unification with a closed definition, an open field keeps its attribute, and `Value.Pos()` points at the author's declaration rather than the definition site. What retired the mechanism is finding 3, recorded above as a placement rule and later recognised as the disqualifying property — a reference does not carry the attribute of the declaration it points at, so a consumer can never see a marker, and a marker can therefore never carry a guarantee a reader relies on. D5 (absorbing D22) drops `@opm()` from every identity field and locates them by schema-fixed path instead, citing this experiment's own closing sentence as the argument: *what a reader relies on is the schema*. Finding 0's recommendation — that D5's marker gain a `role` argument — is **rejected** by D5 and by 0011 D8, on the ground that its only advantage over a schema-path lookup is tolerating a renamed identity field, which should fail `vet` rather than be found.

**Half two — D6's split — was falsified by an intermediate design and then largely restored by the current one.** As measured, every FQN and the module UUID evaluated with `Version` open, because only `ModulePath` fed the keys. The full-SemVer contract keys that followed made that false for the entire key space, which is what the second banner at the top of this file records. D4's contract/build split then narrowed it back: a contract key interpolates `apiVersion`, which is authored per primitive and always concrete, so an unfilled `Version` leaves only the transformer keys and the `catalogVersion` provenance stamps non-concrete. The measured claim therefore holds again across a module's whole demand surface and for three of the four primitive kinds, and fails only on the supply side — tracked in `05-risks.md`, not here.

**What is not re-measured, and must not be read as if it were.** The fixtures in this directory are the pre-split shape: major-keyed FQNs, `version` rather than `catalogVersion`, no `apiVersion` field, no API-version ladder. The paragraph above is a reading of the current design's interpolation rule (`02-design.md`: `fqn` interpolates `apiVersion` for a contract and `catalogVersion` for a transformer), not a re-run. Findings a, b and c were folded into `02-design.md` and `schemas/target.cue` when they were recorded and are not restated here.

**Verdict: hypothesis held as run; the mechanism it validated is superseded (half one) and the property it demonstrated is narrowed but intact (half two).** The experiment is retained rather than deleted because both reversals were driven by measurements recorded here, and a reader of D5 is sent to this file for them.
