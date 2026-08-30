# Design: {Enhancement Title}

Design Goals and Non-Goals together define the boundary of the enhancement.
The High-Level Approach should be understandable without deep
implementation knowledge. All trade-off reasoning lives in
`03-decisions.md`, not here.

## Design Goals

{Bulleted list of what the solution must achieve. These are the acceptance
criteria for the design: if the implementation meets all goals, the design
is satisfied. Phrase goals as outcomes the design produces, not as features
it ships.}

## Non-Goals

{Bulleted list of what is explicitly out of scope for this enhancement.
Non-goals prevent scope creep and set expectations. Items listed here may
become goals in a follow-up enhancement.}

## High-Level Approach

{Describe the core idea in plain language. What is the shape of the
solution? How does it fit into the existing architecture? A reader should
understand the design direction after this section, even without the details
that follow. An ASCII diagram of the shape (layers, components, data flow)
often lands the idea faster than prose alone. See `enhancement-diagrams`.}

## Schema / API Surface

{Give headline shapes only; the full compilable surface lives in
`schemas/target.cue` (when `config.yaml.core_schema: true`) or in
`contracts/` (non-core CUE). For each new or changed construct:

- Reference the specific definition and explain its *role*.
- Quote short CUE snippets only where they clarify structure; point to the
  CUE files for the full surface.

Delete this section if the enhancement defines no schema or contract
surface at all.}

## Affected Surfaces

{Per repo, state which *contracts* change and what a consumer observes
differently: a schema shape, a command's semantics, a refusal rule, a
naming guarantee. Keep it intent-level only.

- No file paths, no line numbers, no function names. The construction
  roadmap belongs to the OpenSpec changes in the target repos, written
  when the code in front of the implementer is current, and logged in
  this entry's `delivery.yaml` as each one lands.
- A name that reaches a key, a demand string, or a command's surface is
  part of the published contract and belongs here; the file that holds it
  does not.

An ASCII component/dependency diagram can make cross-repo wiring easier to
follow than separate bullet lists.}

## Before / After

{Show concrete before-and-after comparisons. Use the same scenario(s) from
`01-problem.md`'s Concrete Example to create a clear narrative arc. CUE
snippets, YAML fragments, an ASCII diagram, or side-by-side diffs all work.}
