# Source note: seed-transformer-inputs

This is a seed. It records behaviour `core` and `library` ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `transformer-inputs`. Full seed (8 requirements). Written 2026-10-11 from `core` at commit `f3b7ecd` and `library` at commit `a87fdda`.

## Sources

All read at the commits named. The requirement text is rewritten at intent level: no Go symbol, file path or flag. No CUE definition is named in the requirements.

| Requirement here | Source requirement in the repo spec | Code read |
| --- | --- | --- |
| The instance context block is projected | `core` `openspec/specs/transformer-context/spec.md`, "The context's metadata blocks are projections of the other two inputs" (instance half) | `core` `src/transformer.cue:145-158` (the block's fields: name `:147`, namespace `:148`, fqn `:149`, uuid `:150`, version from the module metadata `:151`); `src/module_instance.cue:86` (the module metadata the version comes from); pin `_pinCtxInstanceFields`, `src/pins/platform_and_match_pins.cue:407-416` |
| The component context block is projected | same requirement (component half) | `core` `src/transformer.cue:159-167` (name from `#component.metadata.name`, `:160`); pin `_pinCtxComponentName`, `src/pins/platform_and_match_pins.cue:418-422` |
| Absent optional sources project as absent | `core` `transformer-context`, "Absent optional sources project as absent" | `core` `src/transformer.cue:152-157, 161-166`; pins `_pinCtxInstanceAnnotationsAbsent` and `_pinCtxComponentLabelsAbsent`, `src/pins/platform_and_match_pins.cue:440-446` |
| The runtime owes the runtime name alone | `core` `transformer-context`, "The runtime's only obligation is the runtime name" (without the stamping sentence); `library` `openspec/specs/transform-input-fill/spec.md`, "`#context` is projected by core; the kernel supplies `#runtimeName` only" | `core` `src/transformer.cue:203`; must-fail pin for a missing runtime name, `src/pins/platform_and_match_pins.cue:756-775`; `library` `opm/internal/renderstage/render.cue.tmpl:40` and `:526-528` (the glue fills the runtime name and nothing else of the context); `git grep BuildTransformerContext HEAD -- opm` finds nothing in `library` |
| Agreeing fills pass and divergent fills conflict | `core` `transformer-context`, "A staged runtime may fill identical values, and only identical values" (the unification outcome only) | must-fail pin for a divergent fill, `src/pins/platform_and_match_pins.cue:735-754` |
| A standalone context stays constructible | `core` `transformer-context`, "A standalone context value remains constructible" | `core` `src/transformer.cue:178-203` (the projection is in the `#transform` block, not on `#TransformerContext`) |
| The component input keeps every field class | `library` `transform-input-fill`, "`#component` is filled with every field class preserved" and "Matching and execution read one components value" (merged) | `library` `render.cue.tmpl:48` (`_components`), `:460` (matching reads it), `:527` (the pair binds `_components[p.component]`) |
| The instance input is the whole instance | `library` `transform-input-fill`, "`#moduleInstance` is filled with the whole evaluated instance" | `library` `render.cue.tmpl:526` (`#moduleInstance: instance`, the imported instance whole) |

## Left out

- Parity scenarios of the `library` spec ("Parity with unification on the names probe", "...on the instance probe", "Shipped transformers are unaffected", "No Go context mirror" read as an inspection of a package): they describe how a test proves the rule, and `render-parity` (T4.1b row 20) holds the harness. The rules they test are in requirements 4, 7 and 8.
- `library` "The instance fixture resolves `#instance`" (2 scenarios): it states how a library test fixture is authored. No consumer observes it.
- `core` "Transformer-visible values are unchanged" (scenario of the first requirement): a comparison with the context before the projection existed, history that the repos' specs keep.
- The migration rule in `core` "A staged runtime may fill identical values": "a runtime MUST stop filling the projected fields once the differential parity harness reports agreement". The staged migration is done: the kernel fills the runtime name alone (`render.cue.tmpl:526-528`). The unification outcome stays in requirement 5.
- The sentence of `core` "The runtime's only obligation is the runtime name" that the name "is stamped verbatim onto every rendered object as the managed-by label", and the label folds themselves: live entry 0012 owns label stamping and the render digest (`0012:D6`, runtime name filled by the frontend, labels composed in CUE). Requirement 4 states only that the name is required and runtime-supplied.
- The refusal of an empty runtime name at render: `seed-single-build-render` holds it ("Render inputs are source-carrying artifacts", scenario "An empty runtime name is refused"). Requirement 4 states the obligation, not the render-side refusal.
- The version of `core` (alpha.7) that the `library` spec names in "`#context` is projected by core": a stale pin, not behaviour.
- The folds of `#TransformerContext` (module and component label and annotation folds, the controller labels, the `transformer.opmodel.dev/` prefix filter in `src/transformer.cue:239-259`): no repo spec of this capability states them, and `0012:D6` owns label composition. Scenario 1 of requirement 1 only says they resolve.
- `0021`'s policy note `0021/policy/05-module.md:52` says the instance block's FQN "is filled today" with the module's FQN from a `library` Go file. At these commits that file is gone and the FQN is projected from the instance's own metadata (`src/transformer.cue:149`). The seed follows the code; the note is stale and is for 0021's conversion to settle.

## Overlap with other seeds

- `seed-single-build-render` holds the render-side rules: the empty runtime name refusal, matching in the build and its verdicts, failed pairs, concrete output. This seed holds what each input must carry into a transform. Requirement 7 states that matching and execution read one components value from the input side; the render seed states matching runs inside the one build and does not state the shared value. The sentence has no scenario of its own: the library scenario compared two values inside the build, which no consumer observes (T4.R13).
- `seed-render-parity` (T4.1b row 20) holds the harness and its probes. It was read after it was written: it states no input rule of this seed. Requirements 7 and 8 are the rules the probes test.
- `seed-instance-identity` holds how an instance derives its FQN and UUID. Requirement 1 says only that the context carries them.
- `seed-component-matching` (T4.1b row 13) holds the matching labels and which transformer matches which component. It was read after it was written: it states no rule of this seed, which starts after the match.

## Disagreements between spec and code

None that change a requirement. Code wins on one point: the `library` spec says the context comes from core's projection of `#moduleInstance` and `#component` at "core `v2.0.0-alpha.7`"; the code reads whatever core the platform carries. The seed names no version.
