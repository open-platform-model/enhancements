// Core-schema delta for enhancement 0000 (template).
//
// schemas/ exists ONLY when this enhancement adds or changes definitions
// in opmodel.dev/core (config.yaml `core_schema: true` — `task vet`
// enforces the iff-rule in both directions). Compilable CUE that is NOT a
// core-schema delta — decision procedures, kernel-behaviour contracts,
// CLI command contracts, taxonomies — lives in contracts/ instead
// (`task new:contracts ID=NNNN`).
//
// This file is the proposed delta, written so it can be referenced from
// the markdown documents and *tested* (see examples.cue). Author guidance:
//
//   - Keep the package name `schema`.
//   - Open the file with a delta manifest: one comment line per definition,
//     marking it `NEW` or `CHANGED vs core@vN` with a one-line summary of
//     what changes. Reviewers should be able to read the manifest and know
//     the blast radius without diffing core.
//   - Import the published `opmodel.dev/core@vN` for unchanged types the
//     delta references where practical (add the dep to cue.mod and run
//     `cue mod tidy` from this directory; reads resolve from GHCR
//     anonymously). Fully restate the definitions being changed — CUE
//     cannot "edit" an imported closed definition, and the restatement IS
//     the proposal.
//   - Mark unresolved fields with `// OQN:` comments pointing at the
//     corresponding Open Question in ../03-decisions.md; tighten them as
//     decisions land.
//   - examples.cue carries concrete instances that unify against this
//     delta — that companion file is what makes `cue vet ./...` a real
//     test instead of a syntax check. Required, with spec.md, from the
//     draft → accepted gate.
//   - spec.md carries the specification changes (core SPEC.md four-part
//     format per construct).
package schema
