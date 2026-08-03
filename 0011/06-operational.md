# Operational Concerns — Module and Catalog Publishing

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one, even briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Almost everything this entry adds is a refusal, and the refusals are the feature. Four, all emitted by the publish command before anything is pushed:

- **Incomplete identity (D4).** Names the field, the file that declares it, and that `--version` or `version set` clears it. Catches the condition measured to pass both `cue mod publish` and a default `cue vet`.
- **Coordinate disagreement.** The artifact's declared path against `cue.mod/module.cue`'s `module:` line, with both values printed.
- **Local override present (D6).** Lists each `replaceWith` entry next to the registry version that will be resolved in its place, so the author sees the substitution rather than a rule citation. For modules it names the allow flag; for catalogs it explains why there is none.
- **Version assertion failure (D3).** `--version` against a concrete identity field that says something else, with both values printed.

Publish also gains a **plan output** — the resolved path, the tag, the registry repository, and the gate outcomes — printable before the push. It is the human-readable form of `#PublishPlan` and doubles as the dry-run.

`opm catalog registry check` (D7) is a new read-side diagnostic in its own right: it reports what a published catalog actually contains, independently of anyone rendering against it.

Nothing here is a metric. Publishing is an interactive or CI-driven operation whose failures need to be *read*, not counted.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

For the CLI's own surface, additive: four new commands, no existing behaviour changed. The CLI has no external users, so no deprecation is owed on that axis.

The breaking part is not a schema change but a **coordinate migration**. D5 moves every published module from `opmodel.dev/modules/<name>` to `opmodel.dev/m/<owner>/<name>`, and since the declared path is also the artifact's identity, anything pinning an old coordinate breaks and every deployed instance's owner label changes. That is a migration with a window, not a version bump — see Rollback and Cross-Repo Coordination.

Two repos lose tooling they currently depend on: the catalog repos' `task publish` and the modules repo's `publish:smart` plus `versions.yml`. Both are internal, both are replaced in the same change, and neither is consumed outside its own repository.

Consumers of already-published artifacts are unaffected until the migration runs. Nothing in this entry changes how an existing artifact is read.

## Deprecation

**What gets removed and when? What replaces it?**

| Removed | Replaced by |
| --- | --- |
| each catalog repo's copy-and-stamp `task publish` | `opm catalog publish` |
| `identity/version_override.cue` generation | a committed version, written by `opm catalog version set` |
| `modules/Taskfile.yml`'s `publish:smart` | `opm module publish --version`, triggered by whatever OQ4 chooses |
| `modules/versions.yml` | nothing — the version is decided at release time and lives in the tag |
| the flat `opmodel.dev/modules/<name>` namespace | `opmodel.dev/m/<owner>/<name>` |
| `cli/pkg/module/module.go`'s `majorVersionTag()` / `ensureVPrefix()` | reading the declared path directly |

All removed in the same change as their replacement, with no transition period. The one exception that needs an explicit decision is the old namespace: whether the previous coordinates are republished as aliases for a window or hard-cut is OQ6.

`cue mod publish` is **not** deprecated and cannot be — it is CUE's own command and will keep working. This design does not attempt to prevent its use; it makes the correct publish the easy one and puts the guarantees consumers rely on on the read paths instead.

## Rollback

**If this lands and proves bad, what's the rollback story?**

The commands roll back cleanly: they are new, additive, and removing them restores the previous Taskfile-driven flow, which should be kept in git history rather than only in memory. Nothing about an already-published artifact depends on the command that pushed it.

The namespace migration does not roll back cleanly, and it is the part to be careful about. Artifacts republished under owner-scoped paths remain at those paths; reverting means either re-republishing under the old ones or leaving consumers pinned to coordinates the tooling no longer produces. Live instances deployed under the new identity carry the new owner label, so a rollback needs the same adoption pass the forward direction needs, run in reverse — and enhancement 0010 D18 fixes its shape: **relabel in place, never delete and recreate.** The operator sets no `ownerReferences`, so tearing a `ModuleInstance` down garbage-collects nothing; the old resources survive holding the old label and every subsequent prune silently skips them. The same positive check applies in both directions — remove a resource from the module, re-render, confirm it is actually deleted — because a skipped prune reports success.

Practical consequence: treat the command work and the namespace migration as separately revertible, and land them in that order — commands first, proven against a non-production registry, migration second.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

1. **`cli`** — build the commands and the gates. Nothing else moves until `opm catalog publish` and `opm module publish` exist and have been rehearsed against a non-production registry, including every refusal path.
2. **`catalog_opm`, `catalog_kubernetes`, `catalog_opm_experimental`** — switch `release.yml`'s publish job to the new command, delete the copy-and-stamp task. Catalogs go first because modules build against them, so a module cannot be republished correctly until a conforming catalog exists.
3. **`modules`** — replace `publish:smart` with whatever OQ4 chose, delete `versions.yml`, republish the fleet under the owner-scoped namespace.
4. **`opm-releases`** (sibling repo, not under the workspace root) — re-pin to the new coordinates.

The sequencing constraint sits outside this list and is narrower than "0010 and 0011 must land together": **step 3 must land in the same window as enhancement 0010's fleet republish (its own step 6).** Both change what a module's identity resolves to, and running them separately moves every artifact's identity — and therefore every deployed resource's owner label — twice, with two adoption passes instead of one.

What this does **not** constrain is the two entries, or steps 1 and 2 above. Either enhancement may be designed, sliced and landed first; the intermediate state is valid in either order, and 0010's steps 1–5 have no dependency on this entry at all. Enhancement 0010's [`04-graduation.md`](../0010/04-graduation.md) records the entry-level relationship as a **preference rather than a gate**, and its `06-operational.md` separates the two claims under *Where enhancement 0011 binds, and where it does not*. What the joint window buys is effort, not correctness.

One scheduling input this entry does not own: a dedicated central registry on **Zot** is planned to replace the current `ghcr.io/open-platform-model` arrangement. D5's namespace move rewrites every published coordinate, so doing it into GHCR and then moving hosts pays the republish cost twice — sequence the two together, or move hosts first.

The registry itself is a dependency neither repo owns. Before step 3, the central registry must exist, accept authenticated writes (OQ2), and enforce whatever tag-immutability policy OQ3 settles on. That is infrastructure work with its own lead time, and it gates the migration rather than the commands.
