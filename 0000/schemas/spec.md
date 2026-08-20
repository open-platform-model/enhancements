# Specification changes: {Enhancement Title}

<!--
This document pre-drafts the core/SPEC.md co-update that the core slice
will need at implementation time (the `core-schema-edit` skill gates that
co-update via pre-commit hook + CI). It is required, with examples.cue,
from the draft → accepted gate.

One section per NEW or CHANGED construct, in core SPEC.md's four-part
format. For a CHANGED construct, frame each part as a delta against the
current section ("changes vs SPEC.md §N.M"); for a NEW construct, write
the full section draft ready to lift into core/SPEC.md.
-->

## {#ConstructName} ({NEW | CHANGED vs SPEC.md §N.M})

### Definition

{One paragraph of prose. What the construct is and where it sits in the type system — or, for a change, how the existing definition's meaning shifts. No code.}

### Shape

{The CUE definition from `target.cue`, simplified for readability if helpful. For a change, show the changed fields with a one-line note each; the full surface lives in `target.cue`.}

### Constraints

{Bulleted list. RFC 2119 keywords (MUST, MUST NOT, SHOULD, MAY); observable behavior and invariants, not implementation details. For a change: added, removed, loosened, and tightened constraints, each called out as such.}

### Rationale

{Bulleted list. Each item leads with **"Why X."** and anchors in a consequence or class-of-bug the rule prevents. Vacuous rationale ("for flexibility," "for consistency") is rejected at review.}
