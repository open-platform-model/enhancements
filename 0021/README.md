# Enhancement 0021: OPM Versioning Policy

OPM publishes six kinds of versioned artifact: the core schema, catalogs and the contracts inside them, modules, the kernel library, the CLI and the operator with its CRDs. Each one carries a SemVer today, each one is released by tooling, and for exactly one of them, the catalog contract, OPM has written down what a version promises and built a gate that checks it. Everything else runs on convention: a commit type chosen by whoever wrote the commit, read by release-please, verified by nobody. This entry writes the policy down once, for every class, and states for each class what a consumer may rely on across a version, which change moves which number, and whether that rule is a gate or a convention.

See [`config.yaml`](config.yaml) for the metadata contract; it is the sole source of metadata and no parallel metadata table lives in this README.

## Summary

**One policy, many classes** (D1). Versioning rules are not invented here; they are collected, and the entry is the place a module author, a catalog author or a kernel contributor reads to learn what OPM promises. Rules that accepted entries already settled (0010 D27/D34 for the contract ladder, 0011 D15 for authored versions, 0020 for promotion and retirement) are inherited by reference rather than restated (D3), so this entry cannot drift from them.

**A module's version is bound to its `#config` schema** (D2). The configuration contract is the one input surface an instance depends on, and it is already required to be OpenAPIv3-shaped, which makes it mechanically comparable. A change that stops accepting values the previous release accepted is a major; a change that accepts more is a minor; a change that accepts the same is a patch. Whether the rendered output's stateful identity forms a second surface is the entry's first blocking question (OQ1).

**Enforcement is layered, and the layers are named** (02-design.md). Convention says the rule, a claim states which bump a change carries (a commit type, an authored version), a gate verifies the claim against the predecessor at publish, and a check command is an aid that anyone may run and nobody must. Catalogs already have all four layers; modules have the first two and a gate that is explicitly zero-valued; core and the Go artifacts have the first two only. The module compatibility gate is scaffolded here as design intent with its questions attached (OQ5, OQ6), not decided.

## Documents

1. [01-problem.md](01-problem.md): what each artifact class promises today, measured per repo, and the four gaps between them
2. [02-design.md](02-design.md): the policy as a matrix of classes and rules, and the enforcement ladder
3. [03-decisions.md](03-decisions.md): D1..D3
4. [04-graduation.md](04-graduation.md): gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md): risks, drawbacks, high-level alternatives
6. [06-operational.md](06-operational.md): operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md): Open Questions OQ1..OQ13

Compilable CUE lives in [`contracts/`](contracts/): the artifact-class taxonomy and the policy matrix as data, so a per-class rule that is missing or contradictory fails `cue vet` rather than a reader.

## Scope

### In scope

- The enumeration of versioned artifact classes and, for each, its version carrier, its compatibility surface, its bump rules and its pre-stable semantics.
- The universal rules that hold across classes: SemVer, authored versions, major-as-import-rewrite, the enforcement posture, the deprecation posture.
- The module compatibility surface (D2) and the questions that complete it (OQ1..OQ4).
- The compatibility gate as the enforcement pattern, generalized from the catalog gate to any class whose surface is mechanically comparable, scaffolded with its open questions (OQ5, OQ6, OQ8..OQ10).
- Where the policy is published so that a third-party author can read it.

### Out of scope

- Not a change to any version format, release tool or tag scheme already in use: SemVer 2.0, release-please, the `-alpha.N` release lines, the `-0.dev.` branch tags and the `<kind>/<apiVersion>/` filing all stay as they are.
- Not a consumer-facing support window. 0010 D34 rejected one and 0020 D10 constrains the producer instead; both stand.
- Not a maturity ladder for modules unless OQ2 decides one.
- Not the promotion and retirement mechanics of catalog contracts; 0020 owns them.
- Not the version-set and publish command surfaces; 0011 owns them, and this entry only adds refusals they may raise.

## Deviations from Design

None at this stage.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/docs/publishing.md` | The tag scheme and branch-build ranking rule this policy inherits |
| Enhancement 0010 (D4, D27, D34, D35, D41, D45) | Contract keys, the additive-only promise per level, enforcement posture, identity across a major |
| Enhancement 0011 (D9, D15, D23) | The catalog compatibility gate, authored versions, predecessor selection |
| Enhancement 0020 | Contract promotion and retirement on the ladder |
| [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) | The precedence and prerelease rules every carrier follows |
| [Go modules: v2 and beyond](https://go.dev/blog/v2-go-modules) | Prior art for major-in-path, which CUE modules adopt |
| [Kubernetes API versioning](https://kubernetes.io/docs/reference/using-api/#api-versioning) | Prior art for the contract ladder and for CRD versioning |
