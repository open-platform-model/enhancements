# Operational Concerns: Module Presentation Contract

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **Publish refusals** for an invalid card (naming the field), a card over the size line (naming the size), a missing or oversized asset (naming the path), a scripted SVG (naming the element), and a malformed hint on the module's own field (naming the field and the finding).
- **Publish warnings** for a hint finding on an inherited field, a hint whose vocabulary version is newer than the CLI knows, and a block key the CLI's core does not know.
- **Definition acceptance refusals** for a preset the projection refuses (naming the preset) and a per-field override that is not layout (naming the path).
- **Index publish refusals** for an entry whose card or digest disagrees with its member.
- No new metrics. A reader's view of an index shows the index's version, so staleness is visible.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

- **core:** additive. Four new definitions; no existing definition changes. A module without a card is unaffected (0031:D2:R6).
- **0022's block:** additive for readers by 0022:D1, and additive for the gate once 0022 admits keys it does not define. Without that, every core that predates the card would refuse a module carrying one.
- **The `@opm` namespace:** additive for authors. For readers, the amendment of 0013:D2 forbids acting on only the first `@opm` attribute; no library reader exists yet, so nothing breaks.
- **The first-party namespace:** one reserved name, `opmodel.dev/modules/index`, which no module uses.
- **opm-operator:** the definition gains an optional field.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. The 0013 secret reader, when it is written, reads every `@opm` attribute from the start.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Every layer is optional and additive. A card, hints and assets are ignored by a reader that predates them, so a module that carries them keeps rendering on every older CLI and operator. Rolling back the card gate in the CLI leaves cards unchecked, not modules unpublishable. An index is a module: rolling back means no longer publishing new versions of it, and readers fall back to explicit path lists. A definition's presentation is inert, so removing it changes only what a UI shows.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- **0022's open block before any card.** Until 0022's block admits keys it does not define, a card is refused at publish by the very core it ships with.
- **core before the CLI gate and before the module repos.** The CLI checks a card against core's card schema; a module repo may add a card only after a core release carrying the schema reaches it through its dependency update, and after a CLI release with the card and hint gates.
- **The library's attribute reader before the CLI's hint gate.** The hint gate needs every `@opm` attribute of a field with its origin.
- **The CLI's hint gate before catalog default hints.** A catalog type that carries hints must be checked by a gate that knows the vocabulary.
- **core's index schema before the index builder, and the builder before the first-party index.** The first-party index is published by the first-party modules' release pipeline, after the members it lists.
- **0027's definition before presentation.** The operator accepts `presentation` only on the definition 0027 delivers, and core's presentation shape embeds into 0027's core delta.
- **Any reader, including the portal, after the shapes it reads.** A reader built against a draft shape logs nothing against this entry.
