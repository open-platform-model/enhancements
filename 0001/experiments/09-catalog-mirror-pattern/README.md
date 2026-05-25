# 09-catalog-mirror-pattern — #Platform Redesign Umbrella

Status: Concluded

Pins: D19 (`_md: metadata` hidden-mirror rationale; CUE alias-form semantics across pattern-constraint boundaries)

## Hypothesis

Inside a CUE pattern constraint that defines an inner `metadata: { ... }` block, five forms of "stamp the inner struct from the outer catalog metadata" behave distinctly:

1. **`_md: metadata` hidden top-level field reference (mirror).** Vet clean; pattern stamps each constraint match with the outer metadata's modulePath + version concretely.
2. **`M=metadata: {...}` label-alias form (label_alias).** Vet clean; the label alias `M` is bound to the field/path itself and DOES carry across the nested pattern-constraint boundary, resolving to the outer catalog's metadata.
3. **`metadata: M={...}` value-alias form (alias).** Vet FAILS with "reference M not found". Value aliases bind to the value of the field and do NOT carry across the nested struct boundary.
4. **Bare `metadata.modulePath` with public projection (direct).** Vet fails at concrete-eval time (forced by a public reader). Inside the inner `metadata: { ... }` block, the bare `metadata.modulePath` reference walks up to the closest parent field named `metadata` — which is the inner field being constructed itself — producing a self-referential non-concrete interpolation rather than resolving to the outer `#Catalog.metadata`.
5. **Bare `metadata.modulePath` with no public reader (direct_hidden, production mode).** Same self-reference bug as `direct/`, but with `#transformers` hidden and no public projection: plain `cue vet` AND `cue vet -c` BOTH pass silently. The bug is visible only via `cue eval --all` (traversing hidden fields) or at kernel-time materialize.

D19's history entry recorded the value-alias failure as the original attempt that motivated the `_md` mirror workaround. This experiment validates all five forms side by side, locks down the exact diagnostic each produces, AND discovers the label-alias form as a second sound alternative — useful for a future SPEC authoring guide that needs citable examples.

### CUE scoping mechanism (the key insight)

CUE's reference resolution walks up the lexical struct hierarchy looking for the closest parent field with the matching name. Inside a pattern constraint of the form:

```cue
#transformers: [#FQNType]: #ComponentTransformer & {
    metadata: {
        modulePath: "\(metadata.modulePath)/transformers"   // ← what does `metadata` resolve to?
    }
}
```

The `metadata.modulePath` reference walks up looking for the closest field named `metadata` — and finds the **inner** `metadata:` field being constructed *one block above*, not the outer `#Catalog.metadata`. That inner field IS the field we're defining; the reference self-embeds.

To reach the outer `#Catalog.metadata`, you need a distinct identifier that doesn't collide with any field in the lexical walk. Two forms work:

- `_md: metadata` — a separate sibling field on `#Catalog` with a distinct name (`_md`); no inner field shadows it, so `_md.modulePath` resolves cleanly to the outer mirror.
- `M=metadata: {...}` — a label alias on the metadata field itself; `M` becomes a path identifier that DOES carry across the nested boundary. (Distinct from `metadata: M={...}` value-alias form, which does NOT carry.)

## Setup

`./schema/common.cue` — minimal `#PrimitiveMetadata` + `#ComponentTransformer` + `#FQNType` + `#NameType` + `#ModulePathType` + `#VersionType` slice copied from `enhancements/0001/schemas/target.cue` (skill rule: copy, never reference). Shared across all five variant packages so the only thing that varies is the `#Catalog` definition itself.

Five sibling packages, each defining `#Catalog` with one stamping form, plus a concrete `instance` triggering the pattern with one transformer entry:

- `./mirror/catalog.cue` (package `mirror`) — `_md: metadata` mirror; pattern reads `_md.modulePath` / `_md.version`. Public `stamped:` projection exposes stamped values.
- `./label_alias/catalog.cue` (package `label_alias`) — `M=metadata: {...}` field-label alias; pattern reads `M.modulePath` / `M.version`. Public `stamped:` projection exposes stamped values.
- `./alias/catalog.cue` (package `alias`) — `metadata: M={...}` value alias; pattern reads `M.modulePath` / `M.version`. (No public projection needed — value alias fails at vet time structurally.)
- `./direct/catalog.cue` (package `direct`) — pattern reads bare `metadata.modulePath` / `metadata.version`. Public `stamped:` projection forces concretization and surfaces the self-reference error at plain vet.
- `./direct_hidden/catalog.cue` (package `direct_hidden`) — same bare-literal pattern as `direct/` but with no public projection. Mirrors how production `core/catalog.cue` will be structured: `#transformers` is hidden, no public reader. Demonstrates the silent-pass production failure mode.

Each instance uses the same map key (`example.com/cat/transformers/foo@1.0.0`) and the same outer metadata (`example.com/cat` + `1.0.0`); the only differ is which scoping form the pattern constraint uses.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/09-catalog-mirror-pattern@v0"`.

## Run

```bash
# Mirror: clean at plain vet, -c vet, and export. Stamped values reflect
# the schema-enforced subpath.
cue vet ./mirror/...
cue vet -c ./mirror/...
cue export ./mirror/... --out yaml | grep -q "modulePath: example.com/cat/transformers"

# Label-alias: same outcome as mirror — second sound form.
cue vet ./label_alias/...
cue vet -c ./label_alias/...
cue export ./label_alias/... --out yaml | grep -q "modulePath: example.com/cat/transformers"

# Value-alias: fails at plain vet with "reference M not found" — structural error.
cue vet ./alias/... 2>&1 | grep -q 'reference "M" not found'

# Direct (with public projection): public reader forces concretization;
# plain vet reports "incomplete"; -c shows the precise "non-concrete value" error.
cue vet ./direct/... 2>&1 | grep -q "incomplete"
cue vet -c ./direct/... 2>&1 | grep -q "non-concrete value"

# Direct in production mode (no public projection): plain vet AND -c vet
# BOTH pass silently. Bug visible only via cue eval --all or at kernel-time
# materialize.
cue vet ./direct_hidden/...                       # exit 0 — SILENT TRAP
cue vet -c ./direct_hidden/...                    # exit 0 — STILL SILENT
cue eval ./direct_hidden/... --all | grep -q "#ModulePathType &"
```

## Outcome

Observed on 2026-05-25 with cue v0.16.x:

- **Mirror.** Plain vet clean. `-c` vet clean. `cue export` shows `stamped: { name: foo, modulePath: example.com/cat/transformers, version: 1.0.0, fqn: example.com/cat/transformers/foo@1.0.0 }` — pattern stamped both modulePath and version concretely, computed fqn matches the map key.
- **Label-alias.** Identical to mirror: plain vet clean, `-c` clean, stamped values concrete. The `M=metadata:` label-alias form is a second sound alternative — discovered while debugging the experiment.
- **Value-alias.** Plain vet → exit 1. Errors:
  - `#Catalog: unreferenced alias or let clause M: ./alias/catalog.cue:14:12`
  - `#Catalog.#transformers.[].metadata.modulePath: reference "M" not found: ./alias/catalog.cue:20:19`
  - `#Catalog.#transformers.[].metadata.version: reference "M" not found: ./alias/catalog.cue:21:16`
- **Direct (public projection).** Plain vet → exit 1, reporting "some instances are incomplete; use the -c flag to show errors". `-c` shows: `instance.#transformers."…/foo@1.0.0".metadata.modulePath: invalid interpolation: non-concrete value =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$" (type string)` and `stamped.version: incomplete value =~"^\d+\.\d+\.\d+…$"`.
- **Direct (production mode, no public reader).** Plain vet → exit 0 (silent). `cue vet -c` → exit 0 (still silent). `cue eval --all` shows the bug: `metadata.modulePath: #ModulePathType & "\(metadata.modulePath)/transformers"` (unresolved interpolation; the self-referential evaluation is visible as a literal). `metadata.version: =~"^\d+\.\d+\.\d+…$"` (regex constraint, never resolved to the concrete catalog version).

**Hypothesis held — with three refinements.**

1. **Two sound forms, not one.** The `_md: metadata` mirror is sound, AND `M=metadata: {...}` label-alias is sound. D19 chose the mirror; the label-alias is an equivalent alternative the SPEC authoring guide should mention.
2. **The mechanism is closest-parent-field-walk, not "shadowing" in the usual sense.** CUE's reference resolution walks up the lexical struct hierarchy looking for the closest parent field with the matching name. Inside `metadata: { ... }`, a bare `metadata.X` reference finds the inner field being constructed (self), not the outer `#Catalog.metadata`. Calling this "shadowing" is imprecise — it's a name collision in the lexical walk, and the inner field self-embeds rather than masking a distinct outer field.
3. **The silent-pass production trap is real.** With `#transformers` hidden and no public reader (the real `core/catalog.cue` shape), both `cue vet` and `cue vet -c` pass silently on a broken pattern. The bug is invisible to the typical CI regimen and only surfaces at kernel-time materialize.

**Implications for D19 + the future SPEC authoring guide:**

1. Either `_md: metadata` mirror OR `M=metadata: {...}` label-alias is structurally sound for reading outer catalog metadata across the nested pattern-constraint boundary. The two forms are interchangeable; D19's choice of the mirror form is stylistic (the mirror is arguably more discoverable because it shows up as a named field in the schema; the label alias is more compact).
2. The bare `metadata.X` form and the `metadata: M={...}` value-alias form are both unsound. The bare form fails silently in production mode; the value-alias form fails loudly at vet time.
3. CI for `core/catalog.cue` cannot rely on plain `cue vet` or `cue vet -c` to catch a bad `#transformers` pattern constraint when `#transformers` is hidden. A dedicated probe is needed — either a kernel-time materialize test in `library/`, or a fixture that defines a concrete catalog with a known-good stamping and asserts on `cue eval --all` output.
4. The closest-parent-field-walk explanation belongs in the SPEC's `#Catalog` authoring caveat as the canonical way to describe why the mirror / label-alias forms are required.

D19 Source line gains experiment citation.
