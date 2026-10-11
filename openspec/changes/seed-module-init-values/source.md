# Source note: seed-module-init-values

This is a seed. It records behaviour `core` ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `module-init-values`. Full seed (3 requirements, the three of the source spec). Written 2026-10-11 from `core` at commit `f3b7ecd`. The consumer side was read in `cli` at `09b0b812` only to place the boundary (see "Left out").

## Sources

All read at the commit named. The requirement text is rewritten at intent level. The `Source: 0016:...` lines of the source spec are not carried over: 0016 is archived, and a bare decision citation is not allowed in a requirement.

| Requirement here | Source requirement in `core`'s spec | Code read |
| --- | --- | --- |
| A module may declare initValues | `core` `openspec/specs/module-init-values/spec.md` at `f3b7ecd`, "A module may declare initValues" | `core` `src/module.cue` at `f3b7ecd` (`initValues?: _`, an optional regular field of the closed `#Module`, beside `debugValues: _`); `src/pins/module_init_values_pins.cue` (the concrete, the non-concrete, the absent and the misspelled-sibling cases) |
| initValues is not checked against #config | same file, "initValues is not checked against the config contract" (name shortened to stay within 8 words) | `core` `src/module.cue` (no constraint ties `initValues` to `#config`); pins file (`_pinInitNonConforming`) |
| initValues is inert for debugValues and identity | same file, "initValues is inert for debugValues and identity" | `core` `src/module.cue` and `src/module_instance.cue` (no field reads `initValues`; `#ModuleInstance` reads `#module.metadata` and unifies `#config`); pins file (`_pinInitBoth`, `_pinInitSameModuleUUID`, `_pinInitSameModuleFQN`, `_pinInitSameInstanceUUID`, `_pinInitSameInstanceFQN`, `_pinInitSameInstanceLabels`) |

## Where the code and the spec word it differently

- None. The source spec says an instance whose module sets `initValues` "SHALL evaluate exactly as" one whose module does not, and the requirement keeps that rule whole. The pins check validity, the instance `metadata.uuid`, `metadata.fqn` and `metadata.labels` (with a count), not every field, so the scenarios show the rule through identity and labels. No code reads `initValues` outside `#Module` itself (`git grep initValues HEAD -- src` finds only `src/module.cue` and the pins file), so the wider rule is not contradicted.
- The source spec and the code agree on the optional, open, unchecked and identity-inert field.

## Left out

- What a tool does with `initValues`: `opm instance init` reads it first, falls back to `debugValues` only when it is absent, and renders non-concrete content as a default or a prompt. That is the seed `seed-instance-init` (row 32 of the capability map; the `cli` spec `instance-init`). `SPEC.md` section 3.2 of `core` also states it as a tooling rule ("Tooling that initializes an instance package MUST read `initValues`..."), but the `core` capability spec does not, and one rule lives in one seed. Requirement 2 says only that a mismatch "surfaces where the value is consumed".
- "A module that sets `initValues` requires a core release that ships the field" (`SPEC.md` section 3.2). It follows from `#Module` being closed (requirement 1) and is a release-line fact, not a separate behaviour.
- The rationale of `SPEC.md` (why a dedicated field, why not a separate file in the artifact, why no unification with `#config`). It belongs in the design of a later entry, not in a requirement.
- Behaviour a live entry owns: none found. Enhancement 0022 names `initValues` once, as a field a later entry may project from the zip, and states no requirement on it. Enhancement 0027 (`07-questions.md`, open question 29) lists the module's `initValues` as a candidate to prefill an order: an open question, not behaviour.
- Anything of 0006 that 0021 changed: none touches this capability.
- Library-internal placement rules no consumer observes: none. The library reads `debugValues` through the module but nothing reads `initValues`.
