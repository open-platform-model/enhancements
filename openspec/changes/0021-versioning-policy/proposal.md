# 0021: OPM Versioning Policy

OPM publishes many versioned artifacts, and only the catalog contract says what its version promises. This entry writes one policy for all of them: what a version promises, which change moves which number, and which layer enforces it.

## Why

Every artifact carries a SemVer. Only the catalog contract has a written rule and a gate. The rest runs on unchecked convention. A module author who renames a config field ships a minor, and the instance that depends on it fails at its next render.

## What Changes

- A module's version is bound to its config schema. A break is a major, an addition a minor, a fix a patch.
- One policy covers nine artifact classes. Each answers the same five questions. Settled rules are copied under their source.
- A beta line breaks only as a declared change with a migration note, and reaches GA only when written exit criteria hold. The CLI compares `MAJOR.MINOR` when it checks the operator version.
- Release tags are immutable. A bad release is fixed by the next version. A released minor gets a lazy maintenance branch.
- The operator installs from a registry module on its own version train.

## What this is not

- Not a change to any version format, release tool or tag scheme in use.
- Not a support window for consumers.
- Not a built module gate. The gate is scaffolded, with its questions open.
- Not platforms, fixtures or contract promotion (enhancement 0020).

## Example

```cue
// web_app 1.3.0
#config: {database: url!: string, replicas: int | *1}

// web_app 1.4.0, released as a minor because the commit type was feat
#config: {db: url!: string, replicas: int | *1}
```

The instance still sets `database.url`, so it fails to render. Under this policy the rename is breaking, and the release is 2.0.0 on a new module path.

## Capabilities

- **New:** `module-compatibility`, `transformer-levels`, `beta-release-line`, `ga-exit-criteria`, `library-ga-bar`, `operator-version-ceiling`, `immutable-release-tags`, `release-branches`, `operator-install-module`

## Impact

- **Eight repos** change. Most release tooling and the install change already shipped.
- Not breaking: no published byte changes.

## Open questions

- Blocking: Is the stateful identity of a module's rendered output (volume claims, workload kind, service names, ports) a second compatibility surface beside the config schema? The options are the config schema only with a written "treat as breaking" rule, two surfaces with the second by written rule now, or both gated from the start. A look at the fleet's release history for identity changes that shipped as patches would settle it.
- Blocking: Does a module carry a maturity rung beside SemVer, or are SemVer with `0.x` and prerelease lines the whole ladder? A rung would add a field to the module metadata. Settled by whether any consumer needs to tell a stable `0.x` module from an experimental `1.x` one.
- Blocking: Is a change to a config default additive or breaking? A default never fails unification, but it moves the output of every instance that left the field unset. Contract defaults are immutable within a level, so consistency points to breaking.
- Blocking: What is the pre-stable form for modules in general: a `0.x` major, an `-alpha.N` line on `1.0.0`, or both? The operator module settled its own form (`v0` until GA). The fleet's v2 line will be cut under whichever rule stands.
- Not blocking: What does a module compatibility gate compare, and against which predecessor? The comparison is subsumption of the previous `#config` by the new one, with the predecessor found by the backward scan of the catalog gate. Open: a predecessor published outside the CLI, and the stateful surface if one is adopted.
- Not blocking: What does the gate refuse, and can the same comparison carry a gate for the core schema? It refuses when the authored bump is below the change class found. Definition subsumption on core is unmeasured. A throwaway comparison of two consecutive core releases would settle it.
- Blocking: How does a contract-level event move the catalog build number? Candidates per event: a new level beside its predecessor is a minor, a tombstone is a major or a minor, an alpha break is invisible, a transformer change follows the transformer's own surface. A decision that the build tracks the member set and never restates a contract level would settle it.
- Blocking: What is the CLI's compatibility surface? The candidate is command names and required arguments, flag names and defaults, exit codes and declared machine-readable output, with help text excluded. The definition blocks accept. Enforcement can wait.
- Not blocking: What is the kernel library's compatibility surface, given that only the CLI and the operator consume it? The question is whether OPM promises anything to a third party who embeds it. It turns on whether anyone outside the workspace does.
- Not blocking: Are platforms versioned artifacts? Nothing publishes a platform. If one is published, it becomes a class with a surface of its own.
- Not blocking: What does a module with an in-major `#config` break already in its history do at its next release? Either nothing, with the policy binding from then on, or a forced major. Measuring the fleet for past breaks would settle it.
- Not blocking: How does a core major cascade to catalogs and modules? Either the move is breaking for the mover's consumers, all the way down, or it is additive because the old major stays resolvable. It turns on whether a consumer on the old core major can use a catalog on the new one.
- Blocking: Do the kernel library, the CLI and the operator release on one version? The CLI and the operator share `MAJOR.MINOR` and release patches on their own (settled for that pair). The kernel's place and the mechanics of one train versus two kept aligned are open.
- Blocking: How is the documentation site versioned? The position is one docs version per shared CLI and operator `MAJOR.MINOR`, with pages stamped by the versions they were generated from. Open: how the main site picks the core it presents when the CLI's pin and the newest major differ. The build can wait.
- Not blocking: What replaces the kernel's migration ledger? Under one train it becomes an internal changelog section. Under three trains or two it is an API-diff tool at release, or the ledger with its claimed gate actually built.
- Not blocking: Can one component carry two levels of the same resource or trait at once? The per-level transformer rule assumes it cannot. A fixture component that declares both levels and a `cue vet` run would settle it.
