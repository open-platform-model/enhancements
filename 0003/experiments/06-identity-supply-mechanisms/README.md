# 06-identity-supply-mechanisms — OPM Module Publishing Workflow

Status: Concluded

Pins: the mechanism half of D23/D25 — how an artifact's identity gets into it. Directly tests the `@tag()` proposal and the `@opm()` marker-attribute proposal raised 2026-07-26.

## Hypothesis

An artifact's identity must be present **in its own committed bytes**, because CUE's dependency resolution is what carries it to consumers and OPM does not mediate that. Specifically: a `@tag()`-supplied identity is invisible to a transitive importer no matter what the top-level build injects, whereas a committed concrete value resolves correctly through an import with no tooling in the loop — and an inert `@opm()` marker attribute can sit alongside it without affecting evaluation.

The design goal driving this is **transparency, not brevity**: identity should live in a file developers can see, open, and read documentation about, rather than being generated behind their backs.

## Setup

Self-contained; nothing outside this directory is read or modified. One CUE module, three variants, each with a `cat` package imported by a `mod` package so every variant exercises a real transitive import.

- **`a_tag/`** — identity as `string | *"…UNSET…" @tag(modulePath)`, committed and visible. `mod` imports `cat` and reports both its own value and what it sees of the catalog's.
- **`b_committed/`** — identity as a committed concrete value carrying an inert `@opm(identity, owner=publish)` attribute.
- **`c_marker_plus_generated/`** — committed marker only (`ModulePath: string @opm(…)`), with the value arriving from a sibling generated file in the same package.

The `mod → cat` import is the whole point: it stands in for the real relationship where a module imports a catalog's `resources` package, which CUE resolves from the module's `cue.mod` deps without OPM's involvement.

## Run

```bash
bash run.sh
```

No registry required.

## Outcome

Observed 2026-07-26 with cue v0.17.1.

| Variant | module's own identity | what the **imported catalog** reports |
| --- | --- | --- |
| A, no injection | `…UNSET-MODULE@v2` | `…UNSET-CATALOG@v1` |
| A, `-t modulePath=example.com/real-module@v2` | `example.com/real-module@v2` | **`…UNSET-CATALOG@v1`** — unchanged |
| B, plain `cue`, no flags | `example.com/real-module@v2` | `example.com/real-catalog@v1` |

**Hypothesis held**, and the failure mode is sharper than predicted.

### 1. `@tag()` injection does not reach an imported package — at all

Injecting `modulePath` at the top level sets the value in the package being built and leaves the imported `cat` package on its default. The catalog reads `UNSET-CATALOG` whether or not anything is injected, so **every FQN it derives is built from a placeholder**, and no amount of tooling at the top of the build can fix it.

This **corrects a prediction made during discussion.** The anticipated failure was a *collision* — two artifacts declaring `@tag(modulePath)` both receiving the same injected string. That does not happen, because injection never propagates that far. The real failure is worse and quieter: the transitive dependency simply keeps its placeholder, and nothing reports that an injection was ignored.

The consequence for OPM: the kernel knows the coordinates it fetched an artifact by and can inject when loading that artifact *as the main module* — but a module always reaches its catalog through CUE's own dependency resolution, so the catalog's identity can never be supplied that way. `@tag()` is unusable as the value source for identity.

### 2. A committed value resolves correctly, with nothing in the loop

Variant B produces correct, distinct identities for both artifacts under plain `cue eval` with no flags, no injection, and no OPM tooling. `cue vet -c` passes on the committed tree. This is the property that makes it work: the value is in the bytes, so CUE's resolution carries it wherever the artifact goes.

### 3. `@opm()` attributes are inert and survive a round-trip

CUE ignores the unknown attribute for evaluation purposes — variant B vets and evaluates identically with or without it — and `cue def` preserves it verbatim:

```
ModulePath:  "example.com/real-catalog@v1" @opm(identity, owner=publish)
```

So a marker attribute is viable for its intended job: telling a reader that a field is tool-owned, and letting `opm` locate the fields it manages without hardcoding field names. It carries no value and cannot substitute for one.

### 4. The marker-plus-generated hybrid works, but forfeits the stated goal

Variant C resolves correctly when the generated file is present. With it absent — a fresh clone — `cue vet -c` reports exactly what you would want it to:

```
ModulePath: incomplete value string
resourceFQN: non-concrete value string in operand to +
```

That is a clean, legible failure rather than a missing-field error, which is the argument for the marker. But the value still lives in a file the developer did not write and does not see in git, which is precisely the "magic behind the scenes" this design is trying to avoid. C is technically sound and motivationally wrong.

### What this points at

The combination satisfying both the technical constraint and the transparency goal is **variant B**: a committed, visible `identity.cue` holding concrete values, marked with `@opm()` so it is clear the fields are tool-managed, and **written by `opm` commands the way `npm version` writes `package.json`** — the developer sees the file, sees the diff, and commits it. Nothing is hidden, artifact bytes equal source bytes, and transitive resolution works because the value is simply there.

That is a different mechanism from the one D25 currently records (generated into the artifact's own package, gitignored). Reconciling them is a decision, not an experiment, and is left to the design.
