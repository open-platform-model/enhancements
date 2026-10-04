# 04-struct-unions: Self-Service Kinds from Published Modules

Status: Concluded

## Hypothesis

Struct disjunctions in `#config` split into shapes a structural schema can serve with full agreement and shapes it cannot, and the real fleet uses only the first kind. Backs OQ20.

## Setup

- 19 union samples: string, int and bool discriminators; arms in definitions; shared fields; a type conflict; presence-only arms; a discriminator missing from one arm; scalar-or-struct; unions in list items and map values; open arms; nested and optional unions; an embedded base; a duplicated discriminator; two candidate discriminators, with and without a `@opm(ui, discriminator=...)` hint; a struct default `*{...} | T`.
- Encoders: the candidate encoder in CEL mode (A) and `oneOf`/`not` mode (B) from experiment 03, the experiment 01 walker, and `encoding/openapi`.
- The 20 real modules of experiment 01.
- Validation and fixtures as in experiment 02.

## Run

Harness not committed (see the index).

## Outcome

Two shapes are served, with one rule expressible as CEL or as `oneOf`/`not`:

- **Discriminated:** a field with a distinct concrete scalar value in every arm. Served as a flattened object with the discriminator required as an enum, plus a per-arm rule: required fields present, foreign fields absent, other constants equal.
- **Presence-discriminated:** every arm owns a field no other arm declares. `#Secret` is this case.

On the 16 served-shape samples (55 fixtures), A and B each agree on 54 with 0 false accepts. The one false refusal: CUE infers the discriminator from arm-specific fields, while the served schema requires it.

A struct default `*{concrete} | T` is not a union. All 3 union hits in the real corpus were such defaults (resources and nodeSelector in the two GPU plugin modules). Before reducing defaults first, the candidate refused 4 of 20 real modules; after, 20 of 20 encode with 0 refusals under A and B. The fleet has no true struct union today.

Two-arm unions in 8 unbounded lists fit the CEL budget.

The other encoders:

- The walker agrees on 33 of 51 run fixtures (15 false refusals, 3 false accepts). It keeps only the last arm's discriminator and loses cross-arm rules.
- `encoding/openapi` is non-structural on 15 of 19 union samples, because the discriminator is typed only inside `oneOf` branches, and gives one false accept.

Five shapes cannot be served and must be refused:

1. Arms declaring the same non-constant field with different types.
2. Mixed scalar-or-struct unions. Structurally inexpressible, and CEL on the untyped node is refused by CRD validation.
3. Two or more qualifying discriminators with no discriminator hint. With the hint it is served (3 of 3).
4. No discriminator, and some arm owns no field the others lack.
5. Open arms without a discriminator.

Hypothesis held. Candidate for OQ20: serve both shapes with the OQ19 mechanism, require the discriminator, reduce struct defaults first, and refuse the five shapes.
