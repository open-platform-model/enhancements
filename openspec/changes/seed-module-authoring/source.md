# Source note: seed-module-authoring

This is a seed. It records behaviour the cli ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `module-authoring`. Full seed (21 requirements, 54 scenarios; the fixes of review T4.R25 added two requirements, "Init never leaves a partial scaffold" and "A consistent tree needs no repair"). Written 2026-10-11 from the cli at commit `09b0b812`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, flag or file path.

| Requirement here | Source requirement in the cli's spec | Code read at `09b0b812` |
| --- | --- | --- |
| Version set changes only the version value | `authoring-commands`, "version set writes in place, idempotently, offline" (first half) | `internal/cueedit/cueedit.go` (`SetIdentityVersion`, `spliceVersion`); test case "open field gains a unification" in `cueedit_test.go` |
| Setting the declared version writes nothing | same requirement (no-op, offline, argument) | `internal/cmdutil/versionset.go` (`RunVersionSet`); `internal/cueedit/cueedit.go` (`CheckVersion`) |
| A non-conformant identity file is refused | same requirement (refusal half) | `internal/cmdutil/versionset.go` (`versionSetRefusal`) |
| Official templates are published modules | `template-modules`, "Templates are published modules in a reserved segment" (first part) | `.github/scripts/publish-templates.sh`; `.github/workflows/pr.yml` (dry-run step); `internal/publish/gates.go` (segment shape); `.github/scripts/publish-templates.sh:274-279` (the module path must be the segment, the template's name and its major), `:296-307` and `:339-340` (the gate accepts exactly one refusal, that the registry already holds this version, and goes on to the identical-tree check), `:367` (published through module publish) |
| A failing template stops the release | same requirement (gates and release) | `publish-templates.sh` (gate phase, then publish phase); `.github/workflows/release.yml` ("Require the published templates") |
| A template is exactly its published module | same requirement (tree, bump and version rules) | `publish-templates.sh` (`zip_holds_tree`, `same_as_published`, the version checks in `gate`) |
| A template identity is a plain literal | same requirement (second paragraph) | `templates/{minimal,standard,advanced}/identity/identity.cue:14` (`Version: "1.0.4"`, a quoted literal), `templates/{minimal,standard}/module.cue:28` and `templates/advanced/module.cue:32` (`version: id.Version`, a plain reference) |
| Init scaffolds by fetch and re-identification | `template-modules`, "init scaffolds by fetch and re-identification" | `internal/scaffold/scaffold.go` (`Run`, `Reidentify`, `ValidateNewModulePath`): `:202-204` resets the identity version to `InitialVersion` (0.1.0) through the writer that keeps the form it finds, and the official templates hold plain literals; `internal/cmd/module/init.go` (`runScaffold`) |
| Init never leaves a partial scaffold | split out of the row above (review T4.R25 finding 3); the cli spec's scenarios on both rules | `internal/scaffold/scaffold.go:164-166` (target directory exists: refused), `:169`, `:174`, `:179` (`os.RemoveAll(dest)` after a failed copy, re-identification or derive check) |
| A clone source must derive its metadata | none (code only) | `internal/scaffold/scaffold.go:282-305` (`assertDerives`: compares the metadata modulePath with the new path and the metadata version with 0.1.0, so a donor whose literal is 0.1.0 passes the version check) |
| Shortcut expansion is syntactic and never falls back | `template-modules`, "Shortcut expansion is syntactic and safe" | `internal/scaffold/ref.go:99-135` (`ParseTemplateRef`: `:122` a reference with a slash or a dot is a literal module path); `internal/cmd/module/init.go:182-197` (`pickTemplateRef`: naming the template twice is a validation refusal) |
| Template list prints the official set offline | `template-modules`, "template list" | `internal/cmd/module/template.go:44-65` (the list reads the baked table `scaffold.Official`, touches no registry, and writes a table, JSON or YAML) |
| Init refuses honestly when it cannot fetch | `template-modules`, "init scaffolds by fetch..." (offline sentence) and "Shortcut expansion..." (prompt sentence) | `internal/scaffold/scaffold.go` (`ResolveTemplateVersion`); `internal/cmd/module/init.go` (`promptModulePath`, `initError`) |
| Init repairs a tree behind a second confirmation | none in the cli's spec (its Purpose and one scenario mention repair); decision 0011:D20 | `internal/scaffold/repair.go` (`DetectRepair`, `Describe`); `internal/cmd/module/init.go` (`runRepair`, `confirm`: `:312-320` a non-terminal input is refused with "Rerun with --yes to consent up front") |
| A consistent tree needs no repair | split out of the row above (review T4.R25 finding 7) | `internal/cmd/module/init.go:262-265` ("Nothing to repair ..." and the module vet pointer) |
| Repair never invents identity | none in the cli's spec; decision 0011:D20 | `internal/scaffold/repair.go` (`resolveRepairPath`, `planCueMod`, `planIdentity`, `statedVersion`) |
| Scaffold layout is one package, no values file | `template-modules`, "Module tree layout" (scaffold half) | `templates/*` trees; `internal/scaffold/scaffold.go` (`RenamePackageClauses` call in `Reidentify`) |
| Login stores the credential where push reads it | `registry-login`, "Login writes where the push reads" (file half) | `internal/dockercfg/dockercfg.go` (`Path`, `Upsert`) |
| Login verifies the credential before writing | same requirement (verify half) | `internal/cmd/registry/login.go` (`login`, `probeCredential`, `runLogin`) |
| Login resolves its host | same requirement (host half) | `internal/cmd/registry/login.go` (`parseHostArg`, `reportResolution`, `resolveTarget`) |
| Login is interactive only | same requirement (non-interactive scenario) | `internal/cmd/registry/login.go` (`runLogin`, `promptCredential`) |

Decisions in the archived entry 0011 behind these rules: D3 and D8 (version commands), D11 and D24 (login), D12 (identity package, `init` templating), D20 (repair), D25 (templates). The text was read in `archive/0011/03-decisions.md`.

## Where the code wins over the spec

1. Repair version. The spec's scenario "Scaffold identity is a literal" says a tree scaffolded or repaired by init declares version 0.1.0. The code does so only for a scaffold. Repair that creates a missing identity file takes the version from the tree's own metadata and refuses when it states none (`repair.go`, `statedVersion`). The seed follows the code.
2. Repair scope. Decision 0011:D20 lists a third repairable item, missing metadata wiring. The code repairs only the module declaration and the identity file (`DetectRepair` doc comment). The seed does not claim the wiring.
3. Default major. The spec says that no suffix selects the CLI's default major. The code gives a default major only to an official template; any other reference with no suffix floats over all majors (`ParseTemplateRef`). The seed says "an official template takes its default major".
4. The reserved name `index`. The spec says the name is reserved within the templates segment. No code refuses it: the path shape allows any name (`internal/publish/gates.go`, `firstPartyShape`). The seed leaves the reservation out.
5. Offline repeats. The command's help text says that after any successful fetch the module cache serves repeats offline, and the spec implies it ("requires a reachable registry for an uncached template"). The code lists the template's published versions from the registry on every run, an exact tag included (`scaffold.go:66-110`, `ResolveTemplateVersion`), so an unreachable registry refuses even for a template fetched before. The seed states the code. Review T4.R16 found this.
6. Defaulted form. A comment on the initial-version constant says the scaffold is written in the defaulted form. The code resets the version through the same writer, which keeps the form it finds, and the official templates hold plain literals. The seed states only that the CLI never introduces a default arm.
7. Things the code does that the spec is silent on, stated in the seed: a rejected credential and an unreachable registry are two different failure kinds, both leaving the file untouched (`login.go:131-139, 305-308`); the new module path must carry an explicit major and a snake_case leaf, and an existing target directory is refused (`ValidateNewModulePath`, `runScaffold`); an open version field gains a unification; a version with a leading v is refused; a credential file that is not valid JSON is refused; an existing file keeps its permissions; the host suffix for plain HTTP; the warning when the docker auth variable is set; empty username or secret refused; template list in JSON and YAML; the tidy check in the template gates; the scaffold cleanup on failure; the derive check on the clone source.

## Left out

- Behaviour a live entry owns: none. The capability map lists no live entry that touches this capability (`explore/T4.1b.md`, row 28).
- The publish pipeline. The version option of publish, coordinates, gate order, the kind-segment and namespace gates, the module-configuration agreement (including the refusal that points at module init), the kernel-loader gate and the registry-failure messages belong to `seed-artifact-publishing`. Requirement "Official templates are published modules" says only that templates pass those gates; it does not restate them. The sentence of the spec that a template loads through the kernel's module loader is that seed's gate, so it is not repeated.
- The identity file contract. What the identity file holds, that it is committed with real values, and that tooling writes its two fields in place belong to `seed-artifact-identity`. Requirement "Version set changes only the version value" states what the writer preserves, not what the file is.
- The hint to run registry login after a refused credential: owned by `seed-artifact-publishing` (publish) and `seed-platform-contract-gates` (platform check). This seed states the login command only.
- The rest of module vet (what it checks and prints) is not module authoring and no seed holds it. The seed keeps the scenario "No values.cue is required" of "Module tree layout" (module vet validates with the debug values and reports no missing values file), because no other seed would hold it.
- The pull request check of the cli repository (it runs the template gates in dry-run mode, `.github/workflows/pr.yml:184`) and the release step "Require the published templates", which builds no binary while a template fails (`release.yml:106-169`). These are the cli's own CI, not behaviour a consumer sees. The seed states the effect: no official template version is published unless every template passes, and the cli release stays a draft.
- Published-module resolution and instance init (`opm instance init`): `published-module-resolution` and `instance-init` seeds. Template version selection here is its own (a major suffix or exact tag on the template reference, not the instance-side version option); the seed does not claim they are one grammar.
- The reservation of the name `index` and the statement that only the cli's release publishes in the templates segment: a policy with no mechanism (see above, point 4).
- Decision 0011:D11's open authentication mechanism and the `docker-credential-opm` helper: not shipped.
- Everything of 0006 that 0021 changed, and library-internal placement rules: none touch this capability.

## Where this capability touches the other seeds

- `artifact-publishing`: version commands write the field that publish reads and fills; the template release runs the publish gates; repair is what publish points to for a missing module declaration; login is what a refused credential points to. No rule is said in both.
- `artifact-identity`: the identity file fields the version commands, scaffold and repair write.
- `registration-acceptance`, `transformer-registration`, `contract-fulfilment`, `single-build-render`, `platform-registry` and `platform-module-generation`: no touch.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- The premises that publish never skips a published version and that published versions are immutable are `artifact-publishing`'s ("A published version is never replaced"). They are gone from "A failing template stops the release" and "A template is exactly its published module"; the rules that follow from them stay.
