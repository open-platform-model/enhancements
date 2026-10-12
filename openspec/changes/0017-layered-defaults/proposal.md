# 0017: Layered Defaults

A component field can take its value from four places: the deployer, the config schema, the blueprint and the transformer. None holds a default reliably today, and two defaults that meet cancel out. Each layer gets one job.

## Why

Trait schemas cannot default, because they cannot see the Kubernetes kind that carries the field. Blueprints force every composed field present, so a field with no default leaves the component non-concrete, and a fresh module fails to render. Config defaults cancel against a second default. A transformer fallback never runs, because its field is never absent. Seven modules restate Kubernetes defaults.

## What Changes

- Trait and resource schemas publish bounds and never mark a default.
- A blueprint narrows a field to what its kind accepts and marks at most one default per field, on a leaf.
- The kernel turns validated config into plain values before composition, so a config default beats a blueprint default.
- Core projects an optional trait's field as absent until set, so a fallback can run.
- The order is instance values, config defaults, blueprint defaults, transformer fallbacks. CUE produces it.

## What this is not

- Not an in-language precedence feature. CUE's own layering stays unused.
- Not a default in a trait.
- Not a change to the v1 lines.
- Not the audit of every blueprint field. Catalog_opm issue 40 tracks it.
- Not the CLI gates for the layer rules. A later slice builds them.

## Example

```text
opm inst build .   before: unresolved disjunction "RollingUpdate" | "Recreate" | "OnDelete"
                   after:  a Deployment with the blueprint's RollingUpdate strategy
```

An author who writes `updateStrategy: type: "Recreate"` wins. `"OnDelete"` fails vet and names the blueprint line.

## Capabilities

- **New:** `default-precedence`, `config-finalization`, `primitive-bounds`, `blueprint-defaults`, `trait-optionality`, `plain-cue-compatibility`
- **Modified:** `render-parity`

## Impact

- **Module authors** delete hand-set strategy and restart lines.
- **Catalog authors** state each kind's menu and default in its blueprint.
- **Five repos** change: core, library, catalog_opm, cli and modules. The change is breaking: an optional trait's field renders absent, and a config default that breaks a constraint now errors.

## Open questions

- Blocking: Do the first-party workload blueprints keep their `updateStrategy` defaults for good, or drop them once optional traits render absent? Both are correct under the contract. The answer sets the catalog change and the expected render diff of the module cleanup. A restart policy needs no default either way, because narrowing it to its one legal value makes it concrete.
- Not blocking: How does the CLI detect an author-marked default on a component field? An author's `*` and one that arrives through a `#config` reference look the same without provenance. A feasibility spike comes first. The kernel removes the collision either way.
- Blocking: What is the kernel's exact finalize mechanism? Candidates are a recursive default walk and an export-and-rebuild. It must keep unset optional fields absent, report config-shaped errors and pass secret values through. An experiment settles it, not argument.
- Not blocking: Should a vet gate warn when a module relies on kernel-only default resolution? Such a module renders in the kernel but not under plain CUE export. This likely shares the detection work of the second question.
- Blocking: Does the core change land before the catalog defaults, or after? Catalog first unblocks the template now but shifts rendered output twice. Core first shifts it once.
