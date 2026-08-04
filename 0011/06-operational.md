# Operational Concerns — Module and Catalog Publishing

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one, even briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Almost everything this entry adds is a refusal, and the refusals are the feature. Four, all emitted by the publish command before anything is pushed:

- **Incomplete identity (D4).** Names the field, the file that declares it, and that `--version` or `version set` clears it. Catches the condition measured to pass both `cue mod publish` and a default `cue vet`.
- **Coordinate disagreement.** The artifact's declared path against `cue.mod/module.cue`'s `module:` line, with both values printed.
- **Local override present (D6).** Lists each `replaceWith` entry next to the registry version that will be resolved in its place, so the author sees the substitution rather than a rule citation. For modules it names the allow flag; for catalogs it explains why there is none.
- **Version assertion failure (D3, D12).** `--version` against a concrete identity field that says something else, with both values printed. Applies identically to modules and catalogs.
- **Tag/version disagreement (D18).** The tag being pushed does not name the artifact's declared version, with both values printed — the last unjoined pair in the plan, and the one that would otherwise publish bytes interpolating one version into every FQN while the registry serves them as another.
- **Derivation replaced by a literal (D12).** `metadata.version` or `metadata.modulePath` disagreeing with the identity package it should derive from — the case `core` cannot catch, because it has no way to reference an arbitrary module's identity package.

### The drafted messages

Every refusal follows one shape, in a fixed order: **condition → evidence → consequence → action**. `04-graduation.md` requires three of those; the consequence line is the fourth and is the one most easily dropped, so it is stated here rather than implied — a message that says what *would have been published* and what a *consumer would have resolved* distinguishes a caught defect from a broken pipeline, which is the risk `05-risks.md` records. Skip it only where it is genuinely self-evident.

Two supporting rules. **Disagreements print both values in aligned columns with the file that declares each** — six of these are "two things that must agree, don't", and a reader should never have to work out which side is wrong. And **the action is a command, not a description**.

**1. Incomplete identity (D4)**

```
error: opmodel.dev/catalogs/opm declares an identity field that has no value
  Version    src/identity/identity.cue:24   declared as `#VersionType`, never filled

  This artifact would publish, and every consumer would fail at evaluation with
  `incomplete value string` — a producer's mistake, discoverable only downstream.

  Supply it:  opm catalog version set 1.3.0
          or: opm catalog publish --version 1.3.0
```

**2. Coordinate disagreement (D16)**

```
error: opmodel.dev/catalogs/opm disagrees with itself about where it lives
  declared   opmodel.dev/catalogs/opm     src/identity/identity.cue:22
  cue.mod    opmodel.dev/catalogs/opm-x   src/cue.mod/module.cue:1

  cue.mod's `module:` line is what CUE resolves imports against — including this
  module's own `import id "opmodel.dev/catalogs/opm/identity"`. Publishing under
  either value leaves the other wrong.

  Fix whichever is wrong; publish will not choose for you.
```

**3. No `cue.mod` at all (D16, D20)**

```
error: no cue.mod/module.cue under ./src — this is not a CUE module
  Publish reads the module path from cue.mod and refuses to invent one.

  Initialise it:  opm mod init opmodel.dev/catalogs/opm@v1
```

**4a. Local override — catalog (D6)**

```
error: cue.mod/local-module.cue is present; a catalog cannot be published from a tree
       configured for local development
  opmodel.dev/core@v1 → ../../core  (would resolve to v1.0.0-alpha.3 when published)

  A catalog's dependency divergence propagates into the key space of every module
  built against it, so there is no override for this one.

  Remove the file and re-vet before publishing.
```

**4b. Local override — module (D6)**

```
error: cue.mod/local-module.cue is present; this module was validated against
       local checkouts, not against what a consumer will resolve
  opmodel.dev/catalogs/opm@v1 → ../../catalog_opm/src  (would resolve to v1.0.0-alpha.3)

  The replacements are ignored either way — CUE strips the file and the artifact
  always resolves as published. What is in question is whether what you tested
  matches what you are shipping.

  Remove the file, or publish anyway with --skip-override-check if the
  substitution above is immaterial.
```

**The flag is `--skip-override-check`, and the name was chosen against a measured misreading.** D6 never named it. An earlier draft used `--allow-local-overrides`, which the author read — correctly, from the words — as permission for the overrides to take effect. They never do: D6 ignores `replaceWith` entries unconditionally, and CUE strips the file when building the artifact, so nothing local is ever published or resolved. The flag names the **gate being skipped**, not a change in resolution behaviour, and a name that can be read the other way is a name that will be.

**5. Version assertion failure (D3, D12)**

```
error: --version disagrees with the version this artifact declares
  --version  2.4.1
  declared   2.4.0    modules/postgres/identity/identity.cue:18

  --version fills an open field or asserts a concrete one. It never overwrites a
  value someone decided.

  Change the flag, or:  opm module version set 2.4.1
```

**6. Tag/version skew (D18)**

```
error: the tag would not name the version this artifact declares
  tag        v1.3.0
  declared   1.2.0    src/identity/identity.cue:24

  Published this way, every transformer FQN would interpolate 1.2.0 while the
  registry served the artifact as 1.3.0.

  Publish at v1.2.0, or:  opm catalog version set 1.3.0
```

**7. Derivation replaced by a literal (D12)**

```
error: modules/postgres/module.cue states a version its identity package does not
  metadata.version   2.4.0    modules/postgres/module.cue:12
  id.Version         2.4.1    modules/postgres/identity/identity.cue:18

  Derive it:  version: id.Version
```

**8. Already published (D19)**

```
error: opmodel.dev/modules/postgres@v2 already holds v2.4.1
  A published tag names fixed bytes permanently. Publishing cannot replace it, and
  this command will not silently do nothing.

  Bump and retry:  opm module version set 2.4.2
```

**9. Compatibility violation (D9)**

```
error: opmodel.dev/catalogs/opm would break a contract it already published
  #BackupTrait  v1beta1   compared against opmodel.dev/catalogs/opm@1.2.0

    spec.retention        field removed
    spec.schedule         default changed ("daily" -> "hourly")
    metadata.labels.tier  domain narrowed

  At v1beta1 and above a contract may gain fields and options, never lose them,
  and a default may not move. Modules compiled against 1.2.0 match on this key.

  Make the change additive, or ship it alongside at a new apiVersion (v1beta2).
```

The path-located violation lines are measured rather than invented — `experiments/03-d27-compat-gate`'s field-wise walk produces exactly this form.

**10. Non-conformant identity package (D8, D21)**

Not a hand-written message. The identity package is unified against `core`'s `#IdentityPackage` and **CUE's own error is surfaced**, because a procedural expected-versus-found check is a second statement of the contract and the two drift. A renamed `Version` field, a wrong type, and a wrong constraint are three different failures and CUE distinguishes them; a field-presence check reports only the first.

### Two implementation constraints these impose

**Position information must reach the refusal site.** Messages 1, 2, 5, 6 and 7 print `file:line`, which means the loader has to carry it rather than discarding it after decode. Worth recording now instead of discovering it when the messages come out bare.

**Exit codes need a scheme, and D19 makes it matter.** A sweep must distinguish "the filter selected nothing" from "publish failed". D19 rejected having the sweep tolerate an exit code, so nothing depends on a *specific* number today — but the moment someone reaches for that, D19's rejected alternative is the argument against it.

Publish also gains a **plan output** — the resolved path, the tag, the registry repository, and the gate outcomes — printable before the push. It is the human-readable form of `#PublishPlan` and doubles as the dry-run.

`opm catalog registry check` (D7) is a new read-side diagnostic in its own right: it reports what a published catalog actually contains, independently of anyone rendering against it.

Nothing here is a metric. Publishing is an interactive or CI-driven operation whose failures need to be *read*, not counted.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

For the CLI's own surface, additive: four new commands, no existing behaviour changed. The CLI has no external users, so no deprecation is owed on that axis.

**There is no coordinate migration.** An earlier revision of this section described D5 moving every published module to `opmodel.dev/m/<owner>/<name>`, breaking every pin and changing every deployed instance's owner label. **D13 removed that**: first-party modules keep `opmodel.dev/modules/<name>`, so no published coordinate is rewritten and nothing pinning one breaks. What remains is D17's bounded cleanup — legacy `v1alpha1` repositories (gated on the v0 → v1 fleet migration), one hyphenated test module, a test namespace to relocate, and one detritus repository.

Two repos lose tooling they currently depend on: the catalog repos' copy-and-stamp `task publish`, and the modules repo's checksum-driven `publish` plus `versions.yml`. Both are internal, both are replaced in the same change, and neither is consumed outside its own repository.

Consumers of already-published artifacts are unaffected until the migration runs. Nothing in this entry changes how an existing artifact is read.

## Deprecation

**What gets removed and when? What replaces it?**

| Removed | Replaced by |
| --- | --- |
| each catalog repo's copy-and-stamp `task publish` | `opm catalog publish` |
| `identity/version_override.cue` generation | a committed version, written by `opm catalog version set` |
| `modules/Taskfile.yml`'s checksum-driven `publish` | `opm module publish`, triggered by the authored version (D15) |
| `modules/versions.yml` | nothing — the version lives in the module's own `identity/identity.cue` (D12) |
| `cli/pkg/module/module.go`'s `majorVersionTag()` / `ensureVPrefix()` | reading the declared path directly |

All removed in the same change as their replacement, with no transition period. **The namespace is not on this list**: D13 keeps first-party paths as they are, so there are no old coordinates to alias or hard-cut. D17 records the cleanup that does remain and its ordering.

`cue mod publish` is **not** deprecated and cannot be — it is CUE's own command and will keep working. This design does not attempt to prevent its use; it makes the correct publish the easy one and puts the guarantees consumers rely on on the read paths instead.

## Rollback

**If this lands and proves bad, what's the rollback story?**

The commands roll back cleanly: they are new, additive, and removing them restores the previous Taskfile-driven flow, which should be kept in git history rather than only in memory. Nothing about an already-published artifact depends on the command that pushed it.

**The part that does not roll back is any artifact that was published**, which is a property of D10 rather than of this entry: a tag names fixed bytes permanently, so a release made under the new flow stays. That is the intended behaviour and the reason the rehearsal against a non-production registry is a gate rather than a nicety.

An earlier revision of this section described rolling back a namespace migration and the relabelling pass it would need. **D13 and D17 remove it** — no coordinate moves, so there is no reverse migration to run. Enhancement 0010 D18's holding survives where it belongs, as an input to the separate v0 → v1 fleet migration: **relabel in place, never delete and recreate.** The operator sets no `ownerReferences`, so tearing a `ModuleInstance` down garbage-collects nothing; the old resources survive holding the old label and every subsequent prune silently skips them. Its positive check travels with it — remove a resource from the module, re-render, confirm it is actually deleted — because a skipped prune reports success.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **`cli`** — build the commands and the gates. Nothing else moves until `opm catalog publish` and `opm module publish` exist and have been rehearsed against a non-production registry, including every refusal path.
2. **`catalog_opm`, `catalog_kubernetes`, `catalog_opm_experimental`** — switch `release.yml`'s publish job to the new command, delete the copy-and-stamp task. Catalogs go first because modules build against them, so a module cannot be republished correctly until a conforming catalog exists.
3. **`modules`** — delete the checksum-driven `publish` and `versions.yml`, add each module's `identity/identity.cue` and the `metadata` wiring that derives from it (D12), and republish the fleet. Coordinates do **not** change (D13).
4. **`opm-releases`** (sibling repo, not under the workspace root) — no re-pin is needed for a coordinate change, because there is none. It re-pins only to pick up new module versions, which is an ordinary release rather than a migration step.

**The joint window with enhancement 0010 has dissolved into a single operation.** An earlier revision recorded step 3 and 0010's step 6 as two fleet-wide coordinate rewrites needing one shared window, to avoid moving every artifact's identity — and therefore every deployed resource's owner label — twice. D13 removed the coordinate rewrite from this entry, so what remains is 0010's step 6 republishing the fleet with its new identity shape, with this entry contributing only that those republishes go through `opm module publish` rather than the checksum task. One event, one pass, nothing to schedule against anything.

Neither entry blocks the other, which was always true at the entry level. Either may be designed, sliced and landed first; the intermediate state is valid in either order, and 0010's steps 1–5 have no dependency on this entry at all. Enhancement 0010's [`04-graduation.md`](../0010/04-graduation.md) records the relationship as a **preference rather than a gate**, and its `06-operational.md` separates the two claims under *Where enhancement 0011 binds, and where it does not* — that section's fleet-republish half is superseded by D17 and should be read alongside it.

One scheduling input this entry does not own: a dedicated central registry on **Zot** is planned to replace the current `ghcr.io/open-platform-model` arrangement. It no longer shares a window with a namespace move, because there is none. It does gate two things this entry depends on, both of them decided rather than open: the registry must accept authenticated writes (D11) and enforce tag immutability (D10). The second matters more than it looks — D15's authored-version trigger leans on an immutable tag to mean "already released", and GHCR cannot enforce it, which D10 accepts deliberately. Until the cutover, that trigger is a convention rather than a guarantee.

**The cleanup D17 records has its own ordering, and it is the opposite of a migration's.** The legacy `opmodel.dev/<name>/v1alpha1` repositories must *wait* for the v0 → v1 fleet migration, because the deployed fleet still pins them; the hyphen rename, the `test/*` relocation and the detritus deletion are independent of everything and may run at any time.
