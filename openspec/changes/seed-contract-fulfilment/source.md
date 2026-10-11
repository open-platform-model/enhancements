# Source note: seed-contract-fulfilment

This is a seed. It records behaviour `core` and the kernel ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `contract-fulfilment`. Contract-side seed (6 requirements; the source has 7, see "Left out"). Written 2026-10-11 from `core` at commit `f3b7ecd`, with the render-side behaviour checked in `library` at `a87fdda` and the publish gate checked in `cli` at `09b0b812`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, field path or file path. The requirement names are shortened where the source name had more than 8 words.

| Requirement here | Source requirement in `core`'s spec | Code read |
| --- | --- | --- |
| A contract declares where its fulfilment comes from | `core` `openspec/specs/contract-fulfilment/spec.md` at `f3b7ecd`, "A contract declares where its fulfilment comes from" | `core` `src/resource.cue` and `src/trait.cue` at `f3b7ecd` (the closed two-value fulfilment field, default "catalog") |
| A blueprint declares no fulfilment | same file, "A blueprint declares no fulfilment" | `core` `src/blueprint.cue` at `f3b7ecd` (no field; a declared one is a field-not-allowed error) |
| A provider-fulfilled contract admits exactly one provider | same file, "A provider-fulfilled contract admits exactly one provider" (the inventory half; the render's refusal is left out) | `core` `src/platform.cue` at `f3b7ecd` (the provider count, the over-subscribed list and the routable flag; reported, never refused) |
| Every declared resource is a required demand | same file, "Every declared resource is a required demand" | `core` `src/component.cue` at `f3b7ecd` (no demand-side optionality marker); `library` `opm/kernel/render.go` at `a87fdda` (unresolved demands refuse; what the render does with them is the render capability's) |
| A trait states its own optionality | same file, "A trait states its own optionality, and the attachment may override it" | `core` `src/trait.cue` at `f3b7ecd` (optionality with no default); `src/component.cue` (no optionality field on a component). The last sentence of the source requirement, the effect of an unhandled trait, is left out |
| A catalog cannot pin a trait's posture | same file, "A catalog may suggest a posture but may not decide it" | `core` `src/trait.cue` at `f3b7ecd` (`#TraitOptionalGate`); `cli` `internal/publish/catalog_gates.go` at `09b0b812` (the publish pass unifies each trait's optionality against it; unstated or pinned refuses) |

## Where the code and the spec word it differently

- The spec names the count `#Platform.#contracts.providedBy` and its siblings. The requirement says only "the platform's contract inventory" and its over-subscribed and not-routable readings, so no internal field is named.
- The shipped behaviour counts providers per registry entry, which is a catalog path with its major, so two majors of one catalog are two providers. This is the text that enhancement 0026 (decision 9) changes to a count per resolution. The seed holds the shipped text.

## Left out

- Tombstones, promotion and levels of contracts. Enhancement 0020 owns them.
- Module traits and their fulfilment. Enhancement 0025 adds them; the spec at this commit does not state them.
- The per-resolution single-provider count and the resolved platform. Enhancement 0026 owns them.
- The secret-source interaction with the render's skip request. Enhancement 0013 owns it, and the spec at this commit does not state it.
- The platform contract inventory as a capability (`platform-contract-inventory`, 12 requirements): the brief keeps it out. Only the one-provider count it reports is stated here, because the first spec states it.
- The render-side rules, which belong to the seed `seed-single-build-render` (DECISIONS.md 2026-10-11 07:45), so each sentence has one holder:
  - the source requirement "A render's caller may skip unprovided provider-fulfilled demands" (the whole requirement, so this seed has 6 requirements, not 7). No archived entry backs the skip request: the library change that shipped it is marked "No enhancement" (`orchestration.md:38` of change `2026-09-29-render-skips-unprovided-provider-demands`). It is repo behaviour and stays out of every seed (DECISIONS.md 2026-10-11 12:30 and 14:45);
  - the render's refusal of an over-subscribed contract and the "zero providers is an unresolved demand" case;
  - the effect of an unhandled trait at render (a load-bearing one fails, an optional one is reported), the last sentence of the source requirement "A trait states its own optionality".
  The requirement "Every declared resource is a required demand" points to the render capability and does not mention the skip request.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- The reports of the provider count (the providers named per contract, the over-subscribed list, the not-routable verdict) are `platform-contract-inventory`'s (DECISIONS.md 11:20). "A provider-fulfilled contract admits exactly one provider" keeps the admission rule and the counting unit (an entry keyed by catalog path with its major: two majors are two providers, several transformers of one entry are one). Its four report scenarios and the optional-demand sentence are gone: the inventory seed holds them, and `catalog-contracts` holds that an optional demand is not provision.
- "Every declared resource is a required demand" keeps the demand and the ban on rendering the satisfied part of a partly satisfied component. That a render fails on an unsupplied demand is `single-build-render`'s; the scenario "An unsupplied resource fails the render" is gone. The caller's skip request is out of this seed (see "Left out"): no archived entry backs it.
