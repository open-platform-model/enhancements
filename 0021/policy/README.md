# The OPM Versioning Policy (draft text)

One file per policy item, listed below; this index carries the universal rules every item inherits.

This document is the policy itself, as it would be published: the universal rules first, then one section per artifact class in scope (D4). Rules that accepted enhancements or repo documents already settled are **copied verbatim** into the class that owns them, each under a line naming its source (D3). The copy is the text a reader follows; the source is where its reasoning, alternatives and measurements live. Rules this entry adds are authored here and cite the decision that made them. Cells still decided by an Open Question say so inline.

Verbatim blocks keep their source's typography and voice; nothing inside a quoted block has been edited. Enhancement 0020 is cited rather than copied because it is still a draft and its bodies may move.

## Universal rules

- **U1: SemVer 2.0 everywhere, major in the path for CUE modules.** Branch builds keep the `-0.dev.` form and rank below every named channel; the tag format and ranking rule are copied under the core schema class below and apply to every CUE module class.
- **U2: One named surface per class; a release's bump is the maximum change class across its surface.** A release that adds one optional field and removes one required one is a major.
- **U3: Pre-stable means the promise is off, and the line says so.** A `0.x` major, an `-alpha.N` release line, and an alpha contract rung all permit breaking changes without a major bump. What they promise instead is that the label is honest.
- **U4: A version is declared by an author or a release tool, never predicted by publish.** Copied under the module class (0011 D15).
- **U5: A major is an import rewrite, and each class names what survives it.** For modules, `registryPath` survives so instance identity survives (0010 D41, D45, copied under modules). For contracts, the key changes and both levels may ship together (0010 D27). For the core schema, every consumer edits its imports.
- **U6: Enforcement is publish-side where the surface is mechanically comparable, convention where it is not, and a check command is always an aid.** Copied under the catalog contract class (0010 D35).
- **U7: No consumer window; producer-side seasoning where retirement exists.** 0010 D34 rejected consumer windows (copied under contracts); 0020 D6..D10 constrain the producer and are cited.

The stable bump table every SemVer carrier uses:

| Change class | Level |
| --- | --- |
| breaking (the surface stops accepting or providing something it did) | major |
| additive (the surface accepts or provides strictly more) | minor |
| fix (the surface is unchanged; behaviour within it is corrected) | patch |
| invisible (the published artifact is byte-identical) | none |

## Policy items

| # | Class |
| --- | --- |
| 1 | [core schema (`opmodel.dev/core`)](01-core-schema.md) |
| 2 | [catalog build (`opmodel.dev/catalogs/opm`, `opmodel.dev/catalogs/k8s`)](02-catalog-build.md) |
| 3 | [catalog contract (resources, traits, blueprints)](03-catalog-contract.md) |
| 4 | [transformer](04-transformer.md) |
| 5 | [module (`opmodel.dev/modules/<name>` and any third-party path)](05-module.md) |
| 6 | [CLI templates (`opmodel.dev/templates/<name>`)](06-cli-template.md) |
| 7 | [kernel library, CLI and operator (the tooling train)](07-tooling-train.md) |
| 8 | [CRDs (`opmodel.dev/v1alpha1`)](08-crd.md) |
| 9 | [documentation (`opmodel.dev`)](09-documentation.md) |
