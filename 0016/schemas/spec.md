# Specification changes: Initialize a Module Instance Package from a Published Module

One CHANGED construct. This pre-drafts the core/SPEC.md co-update the core slice will make under the `core-schema-edit` protocol; the CUE shape lives in [`target.cue`](target.cue) as `#ModuleInitSurface`.

## `#Module` (CHANGED vs SPEC.md §3.2)

### Definition

`#Module` gains one new optional field, `initValues` (working name; final name and shape are OQ1), carrying the author-intended starting values for a freshly initialized module instance package: the content instance-init tooling renders into the generated `values.cue`. The existing `debugValues` field's meaning — concrete example values for testing and debugging — is unchanged; it additionally becomes the *documented fallback* template source for instance init when `initValues` is absent (D2). The two fields state different author intents: `initValues` is "what a new deployment of my module should start from"; `debugValues` remains "what I test with".

### Shape

Delta only — the rest of `#Module` is unchanged (full modeled slice in `target.cue`):

```cue
#Module: {
    // ... unchanged ...
    #config:     _   // unchanged
    debugValues: _   // contract unchanged; documented fallback init template source (D2)
    initValues?: _   // NEW, optional: author-intended init template (working name, OQ1)
}
```

### Constraints

- Added: `initValues` is OPTIONAL. The change is additive — a `#Module` without it MUST remain valid, so no published module is invalidated and consumers that never read the field are unaffected.
- Added: `initValues`, when present, is intended to satisfy `#config` and SHOULD do so. Whether the schema asserts this via unification, or leaves conformance to init-time reporting, is unresolved (OQ1; init-time handling of a non-conforming template source is OQ5).
- Added: instance-init tooling MUST use `initValues` when present and MUST NOT read `debugValues` in that case (D3); when `initValues` is absent it uses `debugValues` as the fallback template source (D2). The behavior when neither yields usable content is unresolved (OQ3).
- Added: `initValues` carries a CUE value, not a text template — rendering it into a generated `values.cue` MUST be serialization, never template expansion.
- Open (OQ1): whether `initValues` MUST be concrete or MAY carry defaults/optional parts that render as partially-filled scaffolding.
- Unchanged: `debugValues` keeps its existing constraint (`SHOULD satisfy #config`, validated at runtime by the schema fixture harness) with no tightening or loosening.

### Rationale

- **Why a dedicated field instead of reusing `debugValues` as the init source.** Reuse would silently rewrite `debugValues`' contract from "debug fixture" to "public onboarding surface" and punish authors whose debug values legitimately contain test-only content (throwaway hostnames, debug log levels, dummy credentials) they never want templated into a user's deployment file. Conflating "what a new deployment starts as" with "what I test with" in one field forces authors to compromise one intent to serve the other (D3).
- **Why a `#Module` field rather than a separate file in the OCI artifact.** A separate file introduces a second distribution channel with its own packaging and validation rules, invisible to CUE evaluation. A schema field travels with the module, is validated with the module, and is readable by every consumer that already decodes `#Module` (D3).
- **Why optional with a `debugValues` fallback.** `debugValues` is the only values-shaped, author-written, concrete content guaranteed to exist in already-published modules, so the fallback makes init useful against the entire existing fleet on day one with no republish; the optional field gives authors a clean upgrade path into curated init content at their own pace (D2, D3).
