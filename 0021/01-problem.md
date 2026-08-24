# Problem Statement: OPM Versioning Policy

This document answers the question: "Why does this enhancement need to exist?" It leads with what each artifact class promises today, measured against the repos, and then names the gaps between them. It proposes nothing; that belongs in `02-design.md`.

## Current State

Every published OPM artifact carries a SemVer, and every one is released by tooling. What differs between classes is whether anything defines what a version *means*, and whether anything checks it. Measured 2026-08-24 across the workspace:

**Core schema** (`opmodel.dev/core`, one CUE module). Major in the module path; the main channel ships `v2.0.0-alpha.N` prereleases under release-please's `prerelease` mode, with a protected `v1` maintenance branch pinned to patch releases. `core/CLAUDE.md` carries a table mapping conventional-commit types to bump levels and defines "breaking" by example: removing or renaming a definition, tightening a published constraint. A `feat!:` advances the alpha counter within the major; crossing a major is a deliberate act that edits the module path and forces the version in one commit. Branch builds carry `-0.dev.<ct>.g<sha>` and rank below every named channel (`core/docs/publishing.md`). Nothing compares a release against its predecessor.

**Catalogs and their contracts** (`opmodel.dev/catalogs/opm`, `opmodel.dev/catalogs/k8s`). Two independent axes, settled by enhancement 0010: the catalog *build* carries a SemVer `catalogVersion` decided by release-please and written through `opm catalog version set` (0011 D15); each contract member carries its own `apiVersion` on the Kubernetes ladder (`vNalphaM`, `vNbetaM`, `vN`), and inside one level a beta or GA contract is additive-only (0010 D27/D34). That promise is enforced at publish by a level-aware comparison against the predecessor build (0011 D9/D23) and at match by unification; a check command exists as an aid (0010 D35). Transformers carry no `apiVersion` and are keyed by the build (0010 D44). The raw `k8s` family mirrors upstream's API version at adoption (0010 D48). Enhancement 0020 adds promotion between levels and tombstoned retirement. This is the one class with a written promise and a gate.

**Modules** (`opmodel.dev/modules/<name>`, and any third-party path). SemVer authored in an identity package, major in the module path; `fqn` distinguishes majors and nothing finer, and `registryPath` is major-free so an instance's identity survives a major bump (0010 D41/D45, restated in `core/src/module.cue`). The workspace fleet is released by release-please from conventional commits scoped per module, and `opm module publish` refuses an already-published version and predicts nothing (0011 D15). `#Module.#config` is the value schema instances unify against, and the schema comment requires it to be OpenAPIv3-compliant. The publish path's compatibility walk is documented in the CLI as "zero-valued for modules" (`cli/internal/publish/publish.go`). No document in any repo defines what a breaking module change is.

**Platforms**. `#Platform` names each catalog build it materializes as a scalar `version` (`core/src/platform.cue`); the `platforms` registry prefix is reserved and nothing is published under it. Platforms are consumers of versions today, not versioned artifacts.

**Kernel, CLI, operator** (`library`, `cli`, `opm-operator`, Go modules). All three run release-please in `prerelease: alpha` mode with `bump-minor-pre-major: false`; all three Go module paths carry no major suffix. The CLI's compatibility surface (commands, flags, exit codes, machine-readable output) and the kernel's (its exported Go API, which `cli` and `opm-operator` embed) are stated nowhere. The operator serves one CRD group version, `v1alpha1`, with no storage-version or conversion policy written down.

**Module instances**. Not versioned. An instance is values against a module's `#config` at a resolved module version.

## Gap / Pain

**Gap 1: modules have a version and no promise.** The bump level of a workspace module release is whatever commit type the author chose. `feat(name):` yields a minor whether it added an optional field or renamed a required one. A third-party author has no rule to follow at all. The consequence lands on the instance: values that unified yesterday fail at the next resolve, or a rendered resource changes identity underneath running state. Nothing in the tooling can say "this is a major" because nothing defines the surface a major is measured against.

**Gap 2: the rules that exist are scattered.** The catalog promise lives across two accepted enhancements and one draft; the core rules live in a repo `CLAUDE.md` and a publishing design doc; the module conventions live in a third `CLAUDE.md`. Measured 2026-08-24, the public docs site carries no page a consumer can read to learn what OPM promises across a version of anything. "What does a version mean in OPM" has no single answer and no single address.

**Gap 3: the classes do not say how they relate.** A catalog build is a SemVer and a contract level is a ladder rung, and 0010 D34 is explicit that they are independent axes; but nothing states what a contract-level event does to the build number. Does shipping a new `apiVersion` bump the minor? Does a tombstone bump the major? A core major is an import rewrite for every catalog and module; nothing states whether a catalog that moves to the new core major must itself bump major. Each of these has an answer someone has assumed; none is written.

**Gap 4: enforcement is uneven, and the unevenness is invisible.** Catalogs have a gate. Modules have a gate that deliberately does nothing. Core and the Go artifacts have a commit-type convention and a changelog. A consumer cannot tell, from the artifact, which kind of promise stands behind its version.

## Concrete Example

A workspace module `web_app` at `1.3.0` declares:

```
#config: {
    database: url!: string
    replicas:  int | *1
}
```

Its author reorganises configuration and lands `feat(web_app): group connection settings under db`:

```
#config: {
    db: url!: string
    replicas: int | *1
}
```

release-please reads `feat`, cuts `1.4.0`, and the release workflow publishes it. A platform's instance depends on `opmodel.dev/modules/web_app@v1` and resolves the newest v1 on its next dependency update:

```
author commit          release-please        registry           platform instance
feat(web_app): ...  →  1.3.0 → 1.4.0     →  web_app@v1 = 1.4.0  →  values: database: url: "..."
                       (minor, by                                     ↓
                        commit type)                                  field `database` not allowed
                                                                      instance fails at render
```

Every step behaved as designed. The only thing missing was a rule saying that a change which stops accepting `database.url` is a major, and a check that the claimed minor was in fact one.

A second variant is worse because it is silent. The same author renames the module's persistent volume component from `data` to `storage` in a `fix(web_app): clearer component name` commit. `#config` is untouched; the release is a patch; the instance's values still unify. On the next apply the StatefulSet's volume claim template has a new name, a new claim is created, and the old claim with the data is orphaned. No document today says which of these two changes, if either, is the breaking one.

## User Stories

- As a **module author**, I want a rule that tells me which version to bump for a given change so that my releases carry a promise my consumers can rely on. Today: the only rule is the conventional-commit type I pick, and nothing checks it against what I changed.
- As a **platform operator**, I want to know what a version bump of a module, a catalog or the core schema can and cannot do to my running instances so that I can decide how to pin. Today: for catalog contracts I can read 0010 D27; for everything else the answer is in the changelog after the fact.
- As a **kernel or CLI contributor** implementing a compatibility check, I want one policy that names each class's surface so that I build the gate against a stated rule. Today: the catalog gate was built against 0010 D27; a module gate would have to invent its own definition of breaking.

## Why Existing Workarounds Fail

- **Pin exact versions.** A consumer who pins `1.3.0` is safe from the rename and also from every fix. Exact pins are how a fleet stops receiving patches, and they move the whole problem to whoever has to bump them by hand.
- **Read the changelog.** The changelog says `feat: group connection settings under db`, which is true and says nothing about compatibility. A changelog records what the author claimed; it cannot record what the author did not know was breaking.
- **Repo-local conventions.** `modules/CLAUDE.md` can tell a workspace author to bump major on a `#config` break, and did not until now; it cannot reach a third-party author, and a convention nothing checks is what 0010 D27 rejected for catalogs on exactly this argument.
