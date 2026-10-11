# Source note: seed-component-matching

This is a seed. It records behaviour `core` ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `component-matching`. Full seed (6 requirements, 14 scenarios). Written 2026-10-11 from `core` at commit `f3b7ecdb09cff58c97c157e1b62cd0a6e87da51d` and `library` at `a87fdda`.

## Sources

The requirement text is rewritten at intent level: no file path, Go symbol or field path. Names of published CUE definitions (the primitives, the component, the transformer) are not used in the text, which says "resource", "trait", "blueprint", "component" and "transformer". Line numbers are at the commits above.

| Requirement here | Source requirement in the `core` spec | Code read |
| --- | --- | --- |
| Matching labels are a field of their own | `core` `openspec/specs/component-matching/spec.md`, "Matching identity lives in its own field" | `src/resource.cue:100`, `src/trait.cue:65`, `src/blueprint.cue:82`, `src/component.cue:116` (the field on each); `src/transformer.cue:8-12, 86` (the required labels select on it); `src/component.cue:41` (descriptive labels stay the component's own); `library` `opm/internal/renderstage/render.cue.tmpl:204-209` (the label rung reads the component's matching labels) |
| A component's matching labels are its primitives' union | same file, "A component's matchLabels is the wholesale unification of its primitives'" | `src/component.cue:100-116` (the union over the three attachment maps, each guarded by "declared"); `src/pins/platform_and_match_pins.cue:143-149` (a union of two keys), `:589-593` (a conflict names the key) |
| A required matching key survives the union | same file, "A required matching field survives the unification" | `src/component.cue:68-91` (why the union embeds and never iterates), `src/pins/platform_and_match_pins.cue:57, 102-105` (a required key and the blueprint that answers it), `:667-686` (the recorded error) |
| Core names no matching key | same file, "`core` does not name the matching vocabulary" | `grep -rn LabelWorkloadType core/src` finds nothing; `src/transformer.cue:72-78` (the key is the declaring catalog's); `SPEC.md:129` (the constant was deleted); `library` `opm/internal/renderstage/render.cue.tmpl:205-209` (the label rung reads `comp.matchLabels[k] & v` for each required label, so a key a catalog declares on a primitive takes part in matching with no core change: scenario "A catalog adds a key without a core release") |
| Matching labels are never rendered | same file, "Match labels are not rendered" | `src/transformer.cue:205-215` (the omission is deliberate), `:239-248` (the component labels the transformer receives come from the component's descriptive labels only); `src/pins/platform_and_match_pins.cue:341-346` |
| A component adds no matching labels | same file, "A component's matching identity is exactly what it attaches" | `src/component.cue:119-131` (the size check); `src/pins/platform_and_match_pins.cue:624-672` (the two recorded refusals); `src/component.cue:126-131` (`len(matchLabels) == len(_matchLabelsFromPrimitives)`: an unanswered required key does not count in the union, so setting it on the component makes the sizes differ; pin `_failInlineAnsweredMatchLabel`, `src/pins/platform_and_match_pins.cue:652-672`, and the scratch run, bullet 2 below) |

Behaviour checked by running `cue` 0.17.1 in a scratch copy of `core` (never in the `core` tree, nothing committed):

- A component with a key no primitive declares fails on the derivation check.
- A component that answers a required key inline, with no blueprint attached, fails on the same check.
- A bare container with the required key unanswered fails on export with "field is required but not present".
- A component of primitives that declare no matching labels has an empty set and evaluates.
- A component that sets an unrelated descriptive label keeps it as its own.

## Where spec and code differ

The code wins; the seed follows it.

- The spec says a component that declares a matching key "MUST fail". The code compares the size of the declared set with the size of the union (`src/component.cue:130`). A component that restates a key an attached primitive already declares, with the same value, adds nothing and is accepted (run in the scratch copy: the output is the union, unchanged). The requirement therefore says a label the component "adds" is refused. Restating with a different value is a conflict, as for any two primitives.
- The spec says a required key left unanswered is reported when "evaluation" runs. The recorded error is a concrete export, not `cue vet` (`src/pins/platform_and_match_pins.cue:667-679`). The requirement says "evaluating the component reports".
- The code comments in `src/resource.cue:100`, `src/trait.cue:65`, `src/blueprint.cue:82` and `src/transformer.cue:85` still give the example key `core.opmodel.dev/workload-type`. The fixtures and `SPEC.md:129` give `opm.opmodel.dev/workload-type`. The requirements name no key spelling.

## Left out

- Which transformers a component matches, and how the label rung compares values by unification (the label predicate covers every admitted label type; unmatched components with their missing labels): held by `seed-single-build-render` (on branch `refactoring-enhancements/p4-seed-single-build-render`: "Matching runs in the build and yields data", "The label predicate covers every admitted label type"). This seed holds what the component and the primitives declare, not what the kernel does with it.
- The match predicate as a token set (`label:<key>=<value>`) and the report of two transformers whose predicates are subsets of each other: capability `platform-contract-inventory`, a separate seed (T4.1b row 15).
- Optional labels of a transformer: one field in `core` (`src/transformer.cue:90`) with a comment; `grep` finds no spec, test or reader of it in `core` or `library`. No behaviour to state.
- The map names 0010:D14 and D26 beside D36. D14 (a subscription names one catalog build) is gone with the subscription; D26 (provenance excluded from the match comparison before unification) is kernel behaviour held by `seed-single-build-render`. Only 0010:D36 traces to this capability.
- Aspects and module traits, which carry matching labels too: owned by live 0025 (0025:D11 R4 derives an aspect's labels from its traits; 0025:D12 gives module traits the same field; 0025:D13 matches module transformers on them) and 0027:D11 R2 (the offering trait declares none). Stated nowhere here.
- The name rule of rendered kinds, the fulfilment of contracts and the keying of primitives, which sit beside matching in the same files: other capabilities (`resource-naming`, `contract-fulfilment`, `primitive-keying`).
