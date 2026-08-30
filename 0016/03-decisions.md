# Design Decisions: Initialize a Module Instance Package from a Published Module

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent**: never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** How that stays true depends on the entry's `status`:

- While the entry is **`draft`**, decisions are living text: a changed choice is an **in-place edit** to the existing `DN`, and the log never contains two conflicting decisions. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* (marked as previously adopted) before overwriting; a mere sketch may be replaced outright. A decision retracted outright keeps its number as a one-line tombstone (`### DN: (retracted, YYYY-MM-DD)`).
- Once **`accepted`**, decision bodies are **protected**. A change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields. Existing bodies are edited only through the `enhancement-compaction` skill, which weaves stacked reversals into the decisions they reverse (lower number survives, vacated number keeps a tombstone), at latest in the mandatory pass immediately before the `implemented` flip.
- **`implemented`** entries are frozen; **`superseded`** entries are stubbed via compaction.

Either way the log stays safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific: `"User decision YYYY-MM-DD"`, a URL, or a file path, so the provenance of a choice never gets lost. A decision revised in place or by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line; *Alternatives considered* always survives revision and compaction, because it is what stops a rejected option being re-litigated later.

---

## Decisions

### D1: A new CLI command scaffolds an on-disk instance package from a published module reference

**Kind:** contract

**Decision:** The CLI gains an init command for module instances: the user names a published module (its module path) and an instance name and namespace, and the command acquires that module from the registry and writes a complete, standalone on-disk instance package: `cue.mod/module.cue`, `instance.cue`, `values.cue`. That is the same shape `LoadInstancePackage` consumes and `opm instance build`/`apply` accept. The acquired artifact is the module being deployed, never a template: init generates the package from what the module declares (D5 fixes the surface, D9 the generated module file).

**Alternatives considered:**

- *Extend `opm module build --name/--namespace` (the synth path) with a `--write` flag.* Rejected: synth answers "does this module render?" and is deliberately fileless and ephemeral. Grafting file emission onto it conflates a validation tool with a scaffolding tool. Its output (an overlay inside the module's staged tree) is not the standalone committable package the user needs.
- *Documentation only: publish a canonical instance-package example per module.* Rejected: pushes the boilerplate burden onto every module author, and the copied example still carries stale pins and majors the moment either the module or core moves.

**Rationale:** The instance package is the unit everything downstream consumes (CLI build/apply, operator ModulePackage path, GitOps commits), yet nothing generates it (see `01-problem.md`). Generating it from the acquired artifact makes the boilerplate correct by construction.

**Source:** User decision 2026-08-13. Revised: 2026-08-24.

### D2: `debugValues` is the default template source for the generated `values.cue`

**Kind:** contract

**Decision:** When the module declares no dedicated init field (D3), init populates the generated `values.cue` from the module's `debugValues`. The command output names the source used, so a `debugValues`-scaffolded file is visibly that.

**Alternatives considered:**

- *Always start from an empty `values: {}` scaffold.* Rejected as the default: it discards author knowledge that already exists in every published module today and makes the first `opm instance build` fail out of the box for any module with required config.
- *Render `#config`'s defaults into `values.cue`.* Not chosen as the default: `#config` is a constraint schema (possibly non-concrete), so this produces a partial file at best; it remains a candidate fallback for modules with neither field (OQ3).

**Rationale:** `debugValues` is the only values-shaped, author-written, concrete content guaranteed to exist in already-published modules; using it makes init useful against the entire existing fleet on day one, with no republish required. Its known weakness, debug-only content the author never meant as a starting point, is exactly what D3 exists to fix.

**Source:** User decision 2026-08-13.

### D3: `#Module` gains an optional field carrying the author-intended init template, taking precedence over `debugValues`

**Kind:** contract

**Decision:** `#Module` gains a new optional field, `initValues` (shape fixed by D4), whose meaning is: the values a freshly initialized instance package starts from. When present, init uses it and never reads `debugValues`. `debugValues` keeps its existing contract (concrete example values for testing and debugging) unchanged.

**Alternatives considered:**

- *Reuse `debugValues` permanently as the init source, no core change.* Rejected: it silently rewrites `debugValues`' contract from "debug fixture" to "public onboarding surface", and punishes authors whose debug values legitimately contain test-only content (throwaway hostnames, debug log levels, dummy credentials) they never want templated into a user's deployment.
- *Ship the init template as a separate file in the OCI artifact rather than a `#Module` field.* Rejected: introduces a second distribution channel with its own packaging/validation rules, invisible to CUE evaluation; a schema field travels with the module, is validated with the module, and is readable by every consumer that already decodes `#Module`.

**Rationale:** Author intent for "what a new deployment starts as" and "what I test with" are different statements; conflating them in one field forces authors to compromise one to serve the other. An optional field with a `debugValues` fallback gives a clean upgrade path: existing modules work today, and authors opt into curated init content at their own pace.

**Source:** User decision 2026-08-13. Revised: 2026-08-24.

### D4: The field is `initValues?: _`, open and optional, with no schema-side `#config` assertion

**Kind:** contract

**Resolves:** OQ1

**Decision:** The new `#Module` field is named `initValues`, declared optional and open (`initValues?: _`), a direct sibling of `debugValues`. Core does not assert that it satisfies `#config`. Conformance is the author's stated intent (SHOULD), observed where the value is consumed: by `opm instance vet` on the generated package, and by a publish-time gate if 0011 adopts one. The field MAY be non-concrete.

Measured (experiment 04), the render path shapes the scaffold by field kind:

- a defaulted field renders as its default value;
- an undefaulted disjunction renders as the disjunction, leaving the user a choice their first vet will demand;
- an optional field is omitted from the file.

An author who wants a field to appear as a prompt therefore writes it as an undefaulted disjunction or a bare type, not as optional.

**Alternatives considered:**

- *Assert `initValues & #config` in the schema.* Rejected: it evaluates the module's config contract on every module load in every consumer (kernel, operator, docgen, publish) for a check only init cares about, and it would make a stale `initValues` invalidate the whole module rather than one scaffold.
- *A structured `init: {values: ...}` block that could grow siblings (author notes, hints).* Rejected: speculative surface with no second member in sight; a sibling can be added beside `initValues` later without breaking anything.
- *`instanceValues` / `exampleValues` as the name.* Rejected: `initValues` names the operation that reads it, mirroring how `debugValues` names its purpose.
- *Require concreteness.* Rejected: an undefaulted disjunction is exactly the "pick one" scaffold a first-time deployer wants, and the renderer already serializes it.

**Rationale:** Mirroring `debugValues` means authors learn no new concept, and keeping core free of a `#config` evaluation keeps the change purely additive in cost as well as in shape.

**Source:** User decision 2026-08-24. Measured: `experiments/04-nonconcrete-initvalues-render` (defaults resolve, disjunctions survive, optionals vanish through `Syntax(cue.Final(), cue.Concrete(false))`) and `experiments/06-initvalues-additive` (`initValues?: _` invalidates no existing module; `#Module` is closed, so a module setting the field needs a core pin that ships it). Revised: 2026-08-24.

### D5: `opm instance init` mirrors `opm module init`, takes a major-free module path, and floats to the highest core-compatible major when no version is given

**Kind:** contract

**Resolves:** OQ2

**Decision:** The command surface is modelled on `opm module init` parameter for parameter, substituting the instance for the module and the deployed module for the template:

```text
opm instance init [instance-name] [module-path] [--from <module-path>] [--version <vN | X.Y.Z>]
                  --namespace <ns> [--dir <dir>] [--module-path <path>]
```

**Naming and versioning.**

- `instance-name` is the identity of the thing being created (`metadata.name`, validated against the core name type); `--dir` defaults to it, as `module init` defaults the directory to the module path's leaf.
- `module-path` is the published module to deploy, given **without a major** (`opmodel.dev/modules/cert_manager`). It may also be given as `--from`; naming it twice is refused rather than ranked, as `module init` does for its template. A path carrying a major suffix is refused with a hint to use `--version`, so there is exactly one spelling. There is no bare-word shortcut: modules have no reserved official segment, so the argument must be path-shaped.
- `--version` selects within the path: `vN` floats to the newest release within that major; an exact SemVer pins that tag. "Newest release" is the publish-side rule, not `module init`'s: the newest stable tag, else the newest named prerelease, and never a development build (`X.Y.Z-0.dev.N.gSHA`). When `--version` is omitted, init walks majors from highest to lowest: it enumerates the published versions across all majors, takes the newest release in each, and selects the first major whose declared `opmodel.dev/core` dependency equals the core major this CLI build is bound to. A major that declares no `opmodel.dev/core` dependency at all (the pre-v2 lines of cert_manager and metallb, for instance), or that holds no selectable release, is skipped like any other mismatch. The report names the selection and every higher major it skipped, with the reason.

**Safety.**

- A failed init leaves no partial directory behind: the package is written completely or not at all, so a retry into the same `--dir` is never refused by init's own leftovers.

**Prompting and directories.**

- `--namespace` is required (a `#ModuleInstance` has one). When name or namespace is omitted and a terminal is attached, init prompts for it, as `module init` prompts for a missing module path; without a terminal the omission is a refusal.
- `--dir` refuses an existing directory, and refuses a directory that already holds a module or instance package. There is no repair mode: an instance package is three generated files, and re-running init is the repair.

**Exit codes.**

- Those of `module init`: 0 written, 2 refused, 3 registry unreachable.

**Alternatives considered:**

- *Path carries the major (`…/cert_manager@v2`), `--version` floats only within it.* This is the grammar every other command uses, and it was the entry's working shape. Rejected by the owner: a deployer arriving with only a module name should not have to know its major line to get started; the CLI knows which core line it speaks and can pick the newest module line that speaks it.
- *Highest published major regardless of core compatibility.* Rejected: a module major whose core dependency is newer than the CLI's produces a package the same CLI cannot build. Core-major compatibility is the one property init can check cheaply from the candidate's module file before acquiring it.
- *Separate `--version` flag plus a suffix on the path, both accepted.* Rejected: two spellings that can disagree.
- *Accept explicit OCI URLs.* Rejected: the module path decides the registry through `CUE_REGISTRY` routing (workspace registry policy); a raw URL bypasses that.
- *Name and namespace as flags only, never prompted.* Rejected: `module init` prompts when interactive, and the same ergonomics apply; scriptability is preserved because a missing terminal refuses instead of hanging.

**Rationale:** A deployer who has learned `opm module init` learns nothing new; the one deliberate departure (major on `--version`, not the path) buys "latest compatible line" as the default, which is the answer a first-time deployer wants, while keeping the selection explainable in the report.

**Source:** User decision 2026-08-24. Measured: `experiments/01-cross-major-enumeration` (one listing of a major-free path returns every major, sorted ascending; 8 versions over v0/v1/v2 for cert_manager, 47 for `catalogs/opm`), `experiments/02-core-major-probe` (the core dependency major is readable from a ~225-byte module-file blob without the 230 KB zip, about 0.7 s cold per major against GHCR; cert_manager v0 and metallb v0 declare no `opmodel.dev/core` dependency, which fixed the skip rule), `experiments/07-highest-stable-per-major` (`module init`'s selector returns a dev build on a dev-only major where the publish predicate returns nothing, which fixed the selection rule) and `experiments/08-moduleish-refusal` (a half-written package is refused on retry, which fixed the all-or-nothing rule). The CLI's core major is a build-time constant (`library/opm/schema/loader.go`, `DefaultSchemaModule`). Revised: 2026-08-24.

### D6: With no usable template source, init writes `values: {}` and warns

**Kind:** contract

**Resolves:** OQ3

**Decision:** When the module carries no `initValues` and its `debugValues` is not concrete, init still writes all three files; `values.cue` contains an empty `values: {}` and the report carries a warning naming the empty source and pointing at `opm instance vet` for the contract the user must now satisfy. A concrete non-struct `debugValues` (or `initValues`) is rendered verbatim: it is the author's stated value and `#config` may legitimately be a non-struct.

**Alternatives considered:**

- *Refuse unless an explicit `--empty` flag is given.* Rejected: it makes init useless for exactly the modules that most need scaffolding, and the user's next action is identical either way.
- *Render a best-effort skeleton from `#config` (field names, concrete defaults).* Rejected for this entry: `#config` is a constraint schema that may hold disjunctions and non-concrete parts, so rendering it well is the interactive-wizard feature listed under alternatives in `05-risks.md`, not a fallback. It can be added later without changing the ladder.

**Rationale:** The ladder stays a ladder (`initValues`, then `debugValues`, then empty) with the source always named; an empty scaffold is honest, and the warning tells the user what to do next.

**Source:** User decision 2026-08-24. Measured: `experiments/05-nonstruct-debugvalues` (a `#config: string` module with `values: "x"` evaluates through `#ModuleInstance` unchanged).

### D7: The package renderer lives in the CLI; library ships nothing for this entry

**Kind:** scope

**Resolves:** OQ4

**Decision:** Rendering the three-file package is CLI-side, beside the existing `opm module init` scaffolding, and reuses that command's acquire and version-resolution paths. `library` is not in `affects`: `synth.Instance` keeps its in-memory overlay renderer unchanged, and its documented refusal to fall back to `debugValues` stands. The instance-file shape therefore exists in two repos; the CLI's end-to-end test for init loads and builds the generated package through the real `LoadInstancePackage`, so a shape drift is a visible CLI test failure rather than a silent break.

**Alternatives considered:**

- *Export synth's renderer from library and add the `cue.mod/module.cue` generation there, so both frontends share one generator.* Rejected by the owner: init is a scaffolding concern of the same kind as `module init`, which is wholly CLI-side; the library kernel deliberately carries no file-writing or scaffolding policy, and one exported renderer would be the first.

**Rationale:** Keeps the kernel's scope (load, validate, match, execute) intact and keeps both scaffolding commands in one place with one set of conventions.

**Source:** User decision 2026-08-24.

### D8: Init does not validate the generated package; it tells the user how to

**Kind:** policy

**Resolves:** OQ5

**Decision:** Init writes the package and reports; it does not run the equivalent of `opm instance vet`. The report ends by naming the validation command for the generated package's `instance.cue` (the file, which is what `opm instance vet` and `build` take; experiment 03), as `module init` ends with `opm module vet`. A template source that does not satisfy `#config` therefore surfaces at the user's first vet or build, not at init. Whether publishing a module with a non-conforming `initValues` is a publish-time error is 0011's decision and is not made here.

**Alternatives considered:**

- *Vet after writing, keep the files, exit non-zero on failure.* Rejected: it doubles the command's runtime (a second full build of the package) to report what the next command reports anyway, and a failing vet on a freshly written scaffold reads as init having failed.
- *Vet and only warn.* Rejected: same cost, weaker signal.

**Rationale:** Init is a scaffolding step whose output is meant to be edited; validating a file the user is about to change is wasted work, and the sibling command already sets the "scaffold, then vet" convention.

**Source:** User decision 2026-08-24.

### D9: The generated module file pins the module exactly, carries core at the module's major, and names a local placeholder module path

**Kind:** contract

**Resolves:** OQ6

**Decision:** The generated `cue.mod/module.cue` declares the deployed module as a dependency, pinned to the exact resolved version, and `opmodel.dev/core` at the major the acquired module itself depends on, with the rest of the dependency closure complete. The file is equivalent to a tidied module file, so the package builds offline from the module cache with no further step. The package's own `module:` path is `instance.local/<instance-name>@v0` unless `--module-path` overrides it; the package is never published, so the path only has to be valid and unique within the user's tree. Pins never float: the report states the pinned version, and bumping it is the existing dependency-update tooling's job.

**Alternatives considered:**

- *Copy the acquired module's dependency list verbatim.* Rejected: the module's deps are its own imports, not the instance package's; the instance needs the module itself plus core, and whatever those pull in.
- *Write minimal deps and instruct the user to tidy.* Rejected: the first build would fail without a step the user has no reason to know about.
- *Require `--module-path`.* Rejected: nothing consumes the path, so demanding it is friction with no purpose.
- *Omit the `module:` line.* Rejected: a CUE module file without a module path is not a module CUE will resolve dependencies for.

**Rationale:** Correct by construction is the whole point of the entry; a package that needs a second command before it builds is not that.

**Source:** User decision 2026-08-24. Measured: `experiments/03-generated-package-builds` (the package for cert_manager v2.0.1 tidies to one added catalog pin, vets, fans 20 components, builds through `opm instance build` against a platform that implements its contracts, works offline, and never looks up `instance.local`).

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
