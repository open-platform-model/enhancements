# Design: OPM Versioning Policy

This document answers the question: "What is the proposed solution and how does it work?" Trade-off reasoning lives in `03-decisions.md`; unresolved choices live in `07-questions.md` and are cited by number where they shape this text.

## Design Goals

- A single document a module author, a catalog author, a platform operator or a kernel contributor reads to learn what OPM promises across a version of any artifact class, and which change moves which number.
- Every artifact class states the same five things in the same order: the version carrier, the compatibility surface, the bump rules, the pre-stable semantics, and the enforcement layer the rules reach.
- The module class gets a defined compatibility surface, so that a module's version carries a promise an instance can rely on and a gate can verify.
- Rules already settled by accepted enhancements and repo documents are carried verbatim under their source, so the policy is complete on its own page and the argument stays where it was made.
- The enforcement pattern that exists for catalogs is stated generally enough that extending it to another class is an implementation decision, not a design one.

## Non-Goals

- Changing any version format, release tool, tag scheme or filing convention already in use.
- A consumer-facing support or deprecation window (0010 D34 rejected it; 0020 D10 constrains the producer instead).
- Building the module compatibility gate or any other gate; this entry states what a gate for a class must check and leaves the building to the implementing change.
- Versioning enhancements or platforms; the first are not artifacts consumers pin, and platforms are consumers today (OQ11 records whether that changes). Documentation is a class (OQ15).
- Retroactively re-versioning anything already published.

## High-Level Approach

The policy is a matrix. Rows are artifact classes; columns are the five questions every class answers. A small set of universal rules sits above the matrix and applies to every row; a per-class section fills the cells. The universal rules are what makes the classes comparable; the per-class cells are where they differ.

```
                    carrier            surface                       bump rules        pre-stable          enforcement
                    ---------------    --------------------------    --------------    ----------------    -------------
core schema         CUE module semver  published definitions         stable table      alpha line (U3)     claim
catalog build       CUE module semver  member set + transformers     OQ7               alpha line (U3)     gate (0011 D9)
catalog contract    apiVersion ladder  the contract's shape          0010 D27 / D34    alpha rung (D5)     gate + match + aid
transformer         the build's        required/optional + render    the build's       the build's         convention (D6)
module              CUE module semver  #config (D2) [+ OQ1]          stable table      0.x / alpha (OQ4)   open (OQ5)
cli template        CUE module semver  the module surface, scaffold  the CLI's         the CLI's           gate at release
tooling train       Go module semver   kernel API / CLI surface /    stable table      alpha line          claim
  (kernel,cli,op)   one or three (OQ14)  controller behaviour
crd                 group/version      served schema + wire shapes   K8s ladder        v1alpha1            open (OQ9)
documentation      the train's (OQ15)  versions a page describes     n/a               n/a                 open
```

The "stable table" is the ordinary SemVer mapping, stated once and reused: a **breaking** change to the surface is a major, an **additive** change is a minor, a **fix** that leaves the accepted surface identical is a patch, and an **invisible** change (the published artifact is byte-identical) is no release at all. What differs per class is only what "the surface" is and what "breaking" means against it.

### Universal rules

- **U1: SemVer 2.0 everywhere, major in the path for CUE modules.** Already true for every class; stated so the policy has one precedence rule. Branch builds keep the `-0.dev.` form and rank below every named channel (`core/docs/publishing.md`).
- **U2: One named surface per class; a release's bump is the maximum change class across its surface.** A release that adds one optional field and removes one required one is a major.
- **U3: Pre-stable means the promise is off, and the line says so.** A `0.x` major, an `-alpha.N` release line, and an alpha contract rung all permit breaking changes without a major bump. What they promise instead is that the label is honest: a consumer who pins a pre-stable line has opted into breakage. The per-class cell states which form each class uses (OQ4 for modules).
- **U4: A version is declared by an author or a release tool, never predicted by publish** (0011 D15, inherited). release-please is a decider that hands a version to the artifact's writer; a repo without it authors the version directly. Either way the number is a claim.
- **U5: A major is an import rewrite, and each class names what survives it.** Two majors of one artifact are distinct to CUE and to the registry, both resolvable forever. For modules, `registryPath` survives so instance identity survives (0010 D41/D45). For contracts, the key changes and both levels may ship together (0010 D27). For the core schema, every consumer edits its imports.
- **U6: Enforcement is publish-side where the surface is mechanically comparable, convention where it is not, and a check command is always an aid** (0010 D35, inherited). A class whose surface can be compared by unification or by a typed diff earns a gate; a class whose surface is behaviour earns a written rule and a changelog section.
- **U7: No consumer window; producer-side seasoning where retirement exists.** A version never expires, a pin never moves on its own, and a key that stops shipping is declared and seasoned (0020 D6..D10), never silently gone.

### The enforcement ladder

Each rule reaches one of four layers, and the policy names which. This is the frame the compatibility-gate idea is scaffolded in.

```
convention   the rule is written, in the policy and in the owning repo's CLAUDE.md
     ↓
claim        a change states its own bump: a conventional-commit type, or an authored version
     ↓
gate         publish compares the declared surface against the predecessor build and refuses
             a version whose bump is below the change class it carries
     ↓
aid          a check command anyone may run against a published build; never required
```

Catalog contracts reach all four (0010 D27, 0011 D9/D23, 0010 D35). Modules reach the first two today and a zero-valued third; OQ5 asks what the gate compares and OQ6 what it refuses. Core reaches the first two; OQ6 asks whether definition subsumption can carry a gate. The Go artifacts reach the first two, and their surfaces are behaviour, so U6 leaves them there unless OQ8..OQ10 find a comparable slice (the CRD schema is one; a command's flag set may be another).

### The module surface (D2)

A module's compatibility surface is its `#config` schema, and compatibility is subsumption: a release is non-breaking when every `values` the previous release accepted, this release accepts. This gives an unambiguous classification for the cases an author actually faces:

| Change to `#config` | Class |
| --- | --- |
| Add an optional field, or a field with a default | additive |
| Loosen a constraint (widen a disjunction, drop a bound) | additive |
| Add a required field | breaking |
| Remove or rename a field | breaking |
| Tighten a constraint, change a field's type | breaking |
| Change a default | OQ3 |
| Documentation only; the accepted value set is unchanged | fix |

Two things the table does not settle are the entry's blocking questions: whether the rendered output's stateful identity (volume claims, workload kind, service names) forms a second surface (OQ1), and whether a default change is additive, since it never fails unification but moves the output of every instance that left the field unset, which is exactly why 0010 D27 made contract defaults immutable within a level (OQ3).

### The tooling train (OQ14)

The kernel library has two consumers, the CLI and the operator, and both are first-party. The CLI embeds an operator install manifest at a pinned version and refuses to apply when the operator is newer than itself. Three release trains for three binaries whose only compatibility relationships are with each other is where the sweep found the most unverified claims: a migration ledger asserting a gate that does not exist, a skew ceiling that is one-directional, a pinned manifest nothing checks. One train removes the relationships instead of gating them:

```
today                                       one train
-----                                       ---------
library  1.0.0-alpha.14 ──┐                 opm  X.Y.Z  =  library + cli + operator + CRDs served
cli      1.0.0-alpha.13 ──┼─ three pins,         one version, one changelog, one release PR
operator 1.0.0-alpha.12 ──┘  hand-synced         kernel API: internal to the train (OQ16)
                                                 skew ceiling: same number on both sides
docs     v0.1 (flat)                             docs: versioned against X.Y (OQ15)
```

What it costs is coupling: a fix in one binary cuts a release of all three, and the three repos either merge or release from one manifest. What it settles beyond versioning is the documentation's version axis (class 9): a page states the train version it describes and the schema and catalog versions that train pins, which is one number for a reader instead of three.

### Where the policy is authored (candidate, pending decision)

The policy source lives beside the rule: one CUE file per class in the owning repo (`core` one, `catalog_opm` three, `modules` one, `cli` two, `library` one, `opm-operator` two, `opmodel.dev` one), each an instance of a shared `#Policy` schema whose universal rules and bump table are imported, never restated. Every rule is a struct carrying its strength (must/should/may), its enforcement layer, its source and, for a gate, its enforcer; the schema refuses a MUST nothing enforces unless the reason is stated. The Markdown page is generated from the CUE by `cue eval` with no generator binary, and kept fresh by regenerate-and-diff in `task check`, as `INDEX.md` already is. Repo `CLAUDE.md` files point at the CUE source and the generated page. Validated by `experiments/01-policy-as-cue/`, outcome 2026-08-25: renders, stays fresh, and all three label-overstates-enforcement invariants are refused at vet. Where the shared schema lives is open (a `core` subpackage is the candidate).

## Schema / API Surface

No core definition changes. The policy text lives in [`policy/`](policy/), one file per class. The taxonomy of artifact classes, change classes, bump levels and the policy matrix live in [`contracts/policy.cue`](contracts/policy.cue) as data, with the unresolved cells marked `// OQN:`. Compiling it is the completeness check: a class with no carrier, no surface or no enforcement layer does not vet.

## Affected Surfaces

- **`opmodel.dev`**: gains the published policy, one page per reader can find, with the per-class sections and the universal rules. This is the surface a third-party author reads; it is the primary deliverable.
- **`core`**: its versioning table becomes a per-class section of the policy, with "breaking" defined against the published definitions rather than by example. No schema change.
- **`catalog_opm`**: its rules are already 0010/0011/0020's; the policy adds the answer to OQ7 (how a contract-level event moves the build number), which is the one rule a catalog release today decides implicitly.
- **`modules`**: module authors gain the `#config` rule (D2) and the answers to OQ1..OQ4; the fleet's release convention becomes a stated policy rather than a `CLAUDE.md` paragraph.
- **`cli`**: `opm module publish` may gain a refusal, the module compatibility gate (OQ5, OQ6), following the catalog gate's shape: predecessor selected as 0011 D23 does, comparison against the declared surface, refusal naming the change and the level it demands. The check command may gain a module mode as an aid (0010 D35).
- **`library`**: the compatibility comparison generalizes from catalog members to any declared surface; the kernel's own exported API gains a stated surface (OQ10).
- **`opm-operator`**: gains a stated CRD versioning policy on the Kubernetes ladder (OQ9) and a stated surface for controller behaviour.

## Before / After

**Before.** `web_app` renames `#config.database` to `#config.db` under `feat(web_app):`. release-please cuts `1.4.0`; publish succeeds; the platform's `@v1` instance fails at its next render with `field not allowed`. The PVC rename ships as a patch and orphans a claim. Neither outcome violates any written rule.

**After.** The policy says the rename is breaking on the module surface (D2), so the release is `2.0.0` on `opmodel.dev/modules/web_app@v2`; the instance keeps resolving `@v1` at `1.3.x` until its owner edits the import and migrates its values, and its identity survives the move because `registryPath` does not change. If OQ5/OQ6 land the gate, a `1.4.0` claimed over that change is refused at publish, naming `database` as removed and `major` as the level demanded. Whether the PVC rename is also a major is what OQ1 decides; either way the policy says so, and the author can read it before the commit rather than the operator after the apply.
