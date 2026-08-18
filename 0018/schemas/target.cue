// Target schema for enhancement 0000 (template).
//
// This file is the canonical home for the CUE definitions the enhancement
// introduces or modifies. Schemas live as compilable CUE — never as fenced
// blocks inside markdown — so reviewers can vet them with `cue vet ./...`
// from this directory and experiments / fixtures can import them.
//
// Author guidance:
//   - Keep the package name `schema`.
//   - Sketch the target shape end-to-end; mark unresolved fields with
//     comments referencing the relevant Open Question (OQ#) in
//     ../03-decisions.md.
//   - As decisions land in 03-decisions.md, tighten the corresponding
//     fields here. The `accepted` graduation gate requires this file to
//     compile and capture the full target surface.
package schema
