# Enhancement 0011 — Module and Catalog Publishing

There is no OPM publish command. Every artifact in the registry today was pushed by `cue mod publish`, wrapped in a repo-local task that decides the version by its own rules — a content checksum for modules, a copy-and-stamp for catalogs — and neither wrapper reads what the artifact says about itself. This enhancement defines how an OPM artifact reaches a registry.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

Four commands over one pipeline. `opm module publish` and `opm catalog publish` decode an artifact, **derive** its coordinates from what it declares, run the gates, and push — never rewriting the artifact to fit a coordinate someone typed. `opm catalog version set` writes the version, separately, so a commit can sit between deciding a version and pushing one; `--version` on publish is the only other writer, filling a field the author left open or asserting one they made concrete. `opm catalog registry check` verifies a published catalog out of band.

Two gates carry the weight. Publish **refuses an artifact whose identity is not concrete** — measured, `cue mod publish` will happily push a tree with unfilled identity fields, and `cue vet` without `-c` exits 0 on the same tree. And publish **never honours `cue.mod/local-module.cue`**: a module may override that with an explicit flag, a catalog may not, because a module's divergence is scoped to one artifact while a catalog's propagates into the key space of everything built against it.

Underneath, a central registry that **hosts** rather than indexes — CUE has no per-domain autodiscovery, so a self-hosted path is unresolvable for anyone who has not edited their own configuration first — with owner-scoped module paths (`opmodel.dev/m/<owner>/<name>`) beneath reserved segments that keep module space, catalog space, and schema space distinguishable by path alone.

## Documents

The six split documents below are mandatory and always present.

1. [01-problem.md](01-problem.md) — No publish command; three answers to "what version is this"; publish is silent about a divergence it can see
2. [02-design.md](02-design.md) — One pipeline, two artifact types, coordinates derived and gates that reflect blast radius
3. [03-decisions.md](03-decisions.md) — Decision log + Open Questions
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)

Pure-CUE definitions live in [`schemas/target.cue`](schemas/target.cue), which states the publish decision — the plan, the gates, and the tag rule — as shapes that fail to unify when a rule is violated.

## Scope

### In scope

- `opm module publish` and `opm catalog publish`: one implementation, two entry points; coordinate derivation, the artifact-shape gate, and the push.
- `opm catalog version set <semver>`: the version writer, separate from the publisher, editing committed source in place and idempotently.
- `--version` on publish: filling an open identity field or asserting a concrete one, for flows where a release process supplies the version.
- The identity-completeness gate — publish refuses an artifact whose identity fields are not concrete.
- The local-override gate — `cue.mod/local-module.cue` is never honoured, its presence refuses the push, and the escape hatch exists for modules only.
- `opm catalog registry check`, and the equivalent verification when a catalog is added to a `#Platform` registry.
- Where published artifacts live: a central registry that hosts, with owner-scoped module paths under reserved namespace segments.
- Retiring the mechanisms this replaces — each catalog repo's copy-and-stamp publish task, `modules/Taskfile.yml`'s checksum-driven bump, and `modules/versions.yml`.
- The migration of the published fleet to the owner-scoped namespace.

### Out of scope

- **What identity *is*.** The shape of `metadata.modulePath`, the absence of a module version, the catalog's compatibility signal, and the major-keyed FQN belong to enhancement 0010. This entry writes those fields and pushes the artifact carrying them.
- **Read-side verification.** The checks a consumer performs at acquire and at materialize are 0010's. This entry's checks are producer-side and are deliberately not the guarantee — `cue mod publish` will keep working, so a check a publisher can route around is not one a consumer can rely on.
- **Signing, provenance, and attestation.** Out of scope regardless of how the credential question resolves.
- **Artifact discovery** — search, listing, or any index over what is published. It rests on this entry's addressing and namespace guarantees but is its own concern.
- **The CLI's platform-resolution modes** — synthesizing a `#Platform` from a module's catalog dependencies, and honouring `local-module.cue` during development. Adjacent through the same file, but a rendering concern rather than a publishing one.
- **The registry implementation itself** — hosting, storage, and access control as infrastructure. This entry states what publish requires of it.

## Deviations from Design

None at this stage. This entry is `draft`; deviations are recorded here when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary governing this multi-repo enhancement |
| `enhancements/0010/` | The identity half — defines the fields these commands write and the read-side checks that make them trustworthy |
| `cli/CLAUDE.md`, `cli/CONSTITUTION.md` | Repo-local rules governing the command implementation |
| `cli/pkg/loader/provenance.go` | `HasLocalModuleReplacement` — the `local-module.cue` detector the publish gate reuses |
| `cli/pkg/module/module.go` | `CanonicalModuleRef()`, `majorVersionTag()`, `ensureVPrefix()` — coordinate composition that collapses into a read |
| `library/opm/helper/loader/registry/module.go` | The registry loader publish decodes through; also 0010's module read point |
| `library/opm/materialize/enumerate.go` | Enumerates a subscription's published versions — what `opm catalog registry check` and the subscription-time check build on |
| `catalog_opm/Taskfile.yml` | The copy-and-stamp `publish` task this entry deletes; `catalog_kubernetes` and `catalog_opm_experimental` carry the same task |
| `catalog_opm/CLAUDE.md` | Documents today's publish-time stamping flow, including that the source tree is never mutated |
| `catalog_opm/src/identity/identity.cue` | The file `opm catalog version set` writes |
| `modules/Taskfile.yml` | `publish:smart` — the checksum-driven bump this entry retires |
| `modules/versions.yml` | The external version record this entry deletes |
| `modules/jellyfin/cue.mod/module.cue` | A published module's `module:` line and `deps` block — what publish checks the declared identity against |
| `releases/` | Per-environment `ModuleRelease` configs that pin published coordinates; re-pinned by the namespace migration |
