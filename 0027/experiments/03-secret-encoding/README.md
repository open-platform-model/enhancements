# 03-secret-encoding: Self-Service Kinds from Published Modules

Status: Concluded

## Hypothesis

A `#Secret` field in `#config` can be served in a structural schema that refuses exactly what CUE refuses, so a module declaring a secret is not refused as a served kind. Backs OQ19.

## Setup

- Three copies of core's `#Secret`: the beta.2 shape, the 0013 two-arm shape with the hidden secret tag, and the three-arm shape whose source arm is open (`{source, settings?, spec?}`).
- Secret samples: scalar, optional, deep, collection (list and map), many fields, a tag-less look-alike and the old shape. 55 value fixtures, judged by CUE as in experiment 02.
- Four candidate encodings, compared against `encoding/openapi` and the experiment 01 walker:
  - **A:** one flattened object with six optional keys (`value`, `ref`, `key`, `source`, `settings`, `spec`; the last two preserve unknown fields), plus eight small CEL rules: at least one of value, ref or source; three pairwise exclusions; ref and key require each other; settings and spec each require source.
  - **B:** the same object plus `oneOf` over the arms, each arm requiring its own fields and `not anyOf` the other arms' fields. No CEL.
  - **C:** an explicit discriminator field.
  - **D:** an opaque preserve-unknown object.
- CEL cost probes: 2 to 20 unbounded lists and maps of secrets, and bounded lists.

## Run

Harness not committed (see the index). Each candidate is emitted for each sample, validated as in experiment 02, and every fixture is dry-run against the served CRD.

## Outcome

Fixtures agreeing with CUE, by encoding:

- **B:** 55 of 55. No cost model, and every cost probe passed, including 25 unbounded lists. It is the shape upstream `encoding/openapi` already emits for the two-arm secret. Messages are poor: "must validate one and only one schema (oneOf)".
- **A:** 53 of 53 run, with the clearest messages ("value and ref are mutually exclusive", "ref requires key"). CRD admission fails once a module has 4 or more unbounded lists or maps of secrets: the estimated CEL cost exceeds the per-CRD limit (3 pass, 4 fail; scalar secrets are fine at 20). A single `exists_one` rule is 2.8 times over the per-rule budget. Bounding the lists with a maximum of 64 items removes the ceiling: 40 lists pass.
- **C:** rejected by analysis. It changes the values contract (0013:D10:R4 keeps the arm shapes) and core's closed arms refuse the extra field.
- **D:** 24 of 55, with 31 false accepts (two arms at once, ref without key, bad names, unknown fields). This is what the experiment 01 walker does today.
- `encoding/openapi` with expansion: 18 of 18 on the two-arm shape; with one fix for the open arm, 49 of 49 run. It fails to generate on the beta.2 shape.

Other findings:

- Recognising a secret field by core's hidden tag reports every scalar, map, list and nested-pattern secret path with no values present, and reports neither the tag-less look-alike nor the old shape. Recognition by shape would misfire on the look-alike.
- A field typed by an imported definition hides its disjunction arms and scalar bounds unless the value is evaluated first. Any encoder must evaluate before reading arms or bounds.
- None of the 451 API server refusals in experiment 02 echoed a literal secret value. The server echoes a value only on pattern or enum failures, so `value` must never carry a pattern, enum, format or length bound.
- All 13 secret sites in the current fleet are scalar fields, so neither A nor B meets the cost ceiling today.

Hypothesis held: a tag-recognised fixed flattened object serves `#Secret` with full agreement. B is the candidate for OQ19; A is an optional improvement where the CEL budget allows.
