# Open Questions — Kernel render path parity with pure CUE

## Open Questions

- **OQ1: Does anything still depend on multi-version-per-major catalog composition?** Status: resolved (no), ratified into D9.

- **OQ2: Can an evaluated `#ModuleInstance` participate in a CUE build as an importable package?** Status: resolved, ratified into D9.

- **OQ3: In a single build, MVS could override the version the platform names.** Status: resolved (the premise was wrong, measured by experiment 02), ratified into D9.

- **OQ4: Should sibling-component access through `#moduleInstance` be constrained?** Status: resolved-by-D11.

- **OQ5: Should `#TransformerContext` become a projection of the other two inputs?** Status: resolved-by-D12.

- **OQ6: What does the kernel-generated render module owe its own `cue.mod`, and what refuses a render when it cannot supply it?** Status: resolved-by-D5/D13.

- **OQ7: Should the kernel detect and refuse module-versus-platform skew, given that CUE reports nothing?** Status: resolved by D7 and D18.

- **OQ8: What is the unit of reuse once every render is its own build?** Status: resolved, ratified into D9 with D8 supplying the reuse answer (nothing built is shared between renders); measured by experiments 04, 06, 07 and 08.

- **OQ9: With enhancement 0015's `TransformerRegistration`, the effective transformer set is discovered at runtime. What regenerates the platform package, and what keys it?** Status: deferred-to-0015.

- **OQ10: With several catalogs in one build, whose requirements decide the shared paths, and where is a conflicting registration refused?** Status: resolved-by-D13 on the shared-path half (the platform's requirements, always); the refusal-site half is deferred-to-0015, filed there as its OQ7.

- **OQ11: Does publishing a `#Platform` mean anything, given that a published module cannot carry a build-local override?** Status: resolved-by-D6 (as revised 2026-08-20: publishing is disallowed, so the question dissolves).

- **OQ12: What may a long-lived render worker hold between renders?** Status: resolved-by-D8.

- **OQ13: ADR-002's shared materialized platform races under concurrent render. What replaces it?** Status: resolved-by-D8.

- **OQ14: Finalization reorders map-derived lists, so today's path and the collapse emit different bytes for the same input. Which ordering is the contract?** Status: resolved-by-D14.
