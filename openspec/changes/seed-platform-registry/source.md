# Source note: seed-platform-registry

This is a seed. It records behaviour that ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `platform-registry`. Full seed (7 requirements). Written 2026-10-11 from `core` at commit `f3b7ecd`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, file path or field path. The published CUE definition `#Platform` is named, as the design allows. Each scenario was also run with `cue` v0.17.1 on a copy of `core` `src/` at `f3b7ecd`, except the two scenarios that need transformer fixtures (read from the code) and the two that state an absence of fields (read from the definition).

| Requirement here | Source requirement in the repo's spec | Code read |
| --- | --- | --- |
| A registry entry carries its catalog by import | `core` `openspec/specs/platform-registry/spec.md` at `f3b7ecd`, "A registry entry carries its catalog by import" | `src/platform.cue:28-43` (the entry definition: enable switch, embedded catalog), `:180` (the registry) |
| Entry identity is derived, never authored | same file, "Entry identity is derived, never authored" | `src/platform.cue:41-42` (version and transformers derived from the catalog); `src/catalog.cue:98-101` (the version is required and has no default, so an unstamped catalog leaves the entry's version incomplete: `src/platform.cue:36-41`). The seed states the incomplete readout only; it states no render rule |
| A registry key must match its catalog | same file, "The registry key binds to the embedded catalog's module path" | `src/platform.cue:180` (key bound to the catalog's module path); `src/types.cue:75` (a module path needs a major) |
| Composed transformers are derived from enabled entries | same file, "Composed transformers are a derived fold over enabled entries" | `src/platform.cue:185-189` (comprehension over enabled entries) |
| One registry entry per catalog path | same file, "One registry entry per catalog path" | `src/platform.cue:180`; `src/types.cue:75`. The registry is one map keyed by module path (`:180`), so two declarations under one key are CUE unification: one entry, a conflict where they disagree |
| A platform carries no reverse index | same file, "A platform carries no reverse index" (both scenarios) | `src/platform.cue:158-337` (no matching index declared), `:79` and `:269-276` (the readiness index, implementation names only); `src/pins/platform_contracts_pins.cue:697-709` (a declared index is inert) |
| Catalog selection depends on committed source only | same file, "Catalog selection is a pure function of committed source" | `src/platform.cue:28-43` (the entry has no lockfile, maturity or flag field) |

Reference only, nothing seeded from it: `library` `openspec/specs/platform-artifact/spec.md` at `a87fdda`. It describes the Go artifact the kernel builds from a platform, and its shape gate. Its "Platform acquisition from a directory" scenario on an incomplete registry entry agrees with the second scenario of the first requirement here.

## Where the repo spec and the code differ

The code wins in each case.

- "A platform carries no reverse index": the repo spec says a declared index "is refused as an input", and in the same sentence that closedness does not reject it. The code and its pin agree with the second statement: the field is accepted and nothing reads it (`src/pins/platform_contracts_pins.cue:697-709`; run again here, the platform with a declared index evaluates). The seed says the declared index is inert.
- "A registry entry carries its catalog by import", third scenario: the repo spec says validation fails. Run here, an entry with only an authored version passes `cue vet`, because definitions are not checked for completeness, and its version reads as incomplete on evaluation. The seed says incomplete.
- "One registry entry per catalog path": the repo spec says a platform cannot express two builds of one catalog. The key is a module path with its major (`src/types.cue:75`), so entries of two majors of one catalog are two entries; run here, a platform with two majors holds both, and the library spec has a platform that enables two majors. The seed says one build per major and states that majors are different entries. This is a reading of the code, not of the spec text.

## Left out

- The contract inventory and its over-subscription and collision reports. The readiness index is named only to say matching does not read it. The inventory belongs to the capability `platform-contract-inventory`, which this map does not seed.
- The authored `#Platform` of admission entries and the move of today's shipped value to `#ResolvedPlatform`. A live entry owns both (0026). The requirements here name `#Platform` as it ships today; the entry modifies them.
- Mechanism sentences of the repo spec: how the fold is written (a comprehension, never unifying one entry's map into another), the date of the closedness measurement, and the history of the removed subscription capability.
- The `library` kernel artifact: the typed platform, its acquisition from a directory and its recorded inventory. They describe the library, not what a platform declares.

sampled: 2026-10-11 18705155
