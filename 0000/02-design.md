# Design — {Enhancement Title}

This document answers the question: "What is the proposed solution and how
does it work?" Design Goals and Non-Goals together define the boundary of
the enhancement; the High-Level Approach should be understandable without
deep implementation knowledge. All trade-off reasoning lives in
`03-decisions.md`, not here.

## Design Goals

{Bulleted list of what the solution must achieve. These are the acceptance
criteria for the design — if the implementation meets all goals, the design
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
that follow.}

## Schema / API Surface

{Headline shapes only — the full schema lives in `schemas/target.cue`.
Reference specific definitions and explain the *role* of each new or changed
construct. Quote short CUE snippets where they clarify the structure; point
to `schemas/target.cue` for the full surface.}

## Integration Points

{File-by-file targets across the touched repos. Group by repo (core,
library, catalog, …). For each target, name the construct or function being
changed and the nature of the change (new field, renamed field, new
function, replaced function, removed field, etc.). This is the construction
roadmap for implementation.}

## Before / After

{Show concrete before-and-after comparisons. Use the same scenario(s) from
`01-problem.md`'s Concrete Example to create a clear narrative arc. CUE
snippets, YAML fragments, or side-by-side diffs all work.}
