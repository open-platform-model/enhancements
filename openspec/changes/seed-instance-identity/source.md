# Source note: seed-instance-identity

This is a seed. It records behaviour the core schema ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `instance-identity`. Full seed (6 requirements, 12 scenarios). Written 2026-10-11 from `core` at commit `f3b7ecd`. The origin is decision 0010:D41 (archived entry 0010); no live entry changes it (0012, 0025 and 0027 mention instance identity and restate it).

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, field path or file path. `#ModuleInstance` is a published CUE definition and is named (V19, D 21:30 Q5).

| Requirement here | Source requirement in the repo's spec | Code read |
| --- | --- | --- |
| An instance declares its own FQN | `core` `openspec/specs/instance-identity/spec.md` at `f3b7ecd`, "An instance declares its own FQN" | `src/module_instance.cue:50` (the FQN), `src/module.cue:45` (the module's registry path) |
| Instance identity derives from the instance FQN | same file, "Instance identity derives from the instance FQN" | `src/module_instance.cue:57` (the UUID), `:63-64` (the labels), `src/pins/identity_pins.cue:179` |
| The identity formula is fixed | none; the spec does not state it | `src/types.cue:255` and the comment above it ("must remain immutable across all versions"); `src/pins/identity_pins.cue:208`, the absolute UUID pin `b6a249c2-6d12-5422-ae0b-ecf44cbbf8bf` |
| Instance identity survives every module upgrade | same file, "Instance identity survives every upgrade of the module it deploys" | `src/pins/identity_pins.cue:175-176` (release and major bump), `:95-96`; third scenario: the 0010:D41 consequence list, see below |
| Instance identity still separates what it must | same file, "Instance identity still separates modules and namespaces" | `src/pins/identity_pins.cue:257-262` |
| An instance FQN cannot take a module path | same file, "An instance FQN cannot be built from a module path" | `src/types.cue:165` (`#PackagePathType & _p[0]`), `src/pins/identity_pins.cue:516-535` (the refusal, kept as a comment case) |

The spec's first requirement, "A module exposes its major-free registry path", is not in this seed. See "Left out".

## Where spec and code differ

- The spec has no requirement that the identity formula is fixed. The code states it twice: the comment on the OPM namespace UUID (`src/types.cue:252-254`) and the absolute pins (`src/pins/identity_pins.cue:186-208`). The seed adds "The identity formula is fixed" from the code. I recomputed the pinned UUID: a version 5 UUID of `opmodel.dev/modules/postgres:postgres-prod:prod` under `11bc6112-a6e8-4021-bec9-b3ad246f9466` is `b6a249c2-6d12-5422-ae0b-ecf44cbbf8bf`, and the module's own UUID for `opmodel.dev/modules/postgres@v2` is `a48f489f-ebfc-579a-8d48-d658c12d3f2a`, as pinned.
- The scenario "Two majors under one name and namespace share an identity" is not in the spec. It follows from the code (the FQN has no major) and is stated as a consequence of 0010:D41 (`archive/0010/03-decisions.md`, D41, "Consequences"). The seed adds it so that the shipped limit is visible: two majors of one module cannot run side by side under one name and namespace.
- The spec's survival requirement names the operator's prune step. The seed keeps only that the ownership label depends on a stable UUID and does not describe the operator.
- The spec lists the rejection as a conflict "against the already-computed value" and says the path type is only a backstop. The code agrees (`src/module.cue:45`, `src/types.cue:165`). The seed states the outcome (a structural refusal, a conflict) and not which of the two mechanisms fires.
- No other difference found. The library does not compute an instance identity: it leaves the UUID to the schema (`library` `opm/internal/synth/instance.go:32-37`, at `a87fdda`).

## Left out

- "A module exposes its major-free registry path". The seed `artifact-identity` (branch `refactoring-enhancements/p4-seed-artifact-identity`, `c439247`) holds the requirement of the same name, with the scenario "Two majors share one registry path". This seed reads that value and does not restate it. Check at the join that the two seeds are both kept.
- The decomposition of a module path into registry path, major and import path (`#ArtifactRef`): `artifact-identity` holds it.
- The wiring of the instance name, namespace, UUID and cluster domain into each component, and the names and DNS variants computed from them (`src/module_context.cue`, `src/module_instance.cue:79-84`): `resource-naming` (row 18 of the capability map) and the context blocks in `transformer-inputs` (row 19) own it.
- What the operator and the CLI do with the ownership label (skipping a delete when the owner label disagrees, adoption, the stored previous identity): ownership and inventory behaviour, which live entry 0012 owns (`explore/T4.1.md` question 4). No requirement here describes it.
- The instance's `name` label, `clusterDomain` and the module's labels copied onto the instance: not identity.
- The module's own FQN and UUID (they move on a major bump): `artifact-identity` holds the FQN rule. This seed states only that the instance's UUID does not move on a major bump (the clause that the module's UUID does is gone, see Consolidation).
- The `opm-secrets` injection removal and the instance's `components` map in the same file: not identity.
- Library-internal placement: nothing observed by a consumer.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- The clause "while the module's own UUID changes" is gone from the scenario "A major bump does not move the UUID": `artifact-identity` holds the module identity ("Module identity distinguishes majors and nothing finer").
