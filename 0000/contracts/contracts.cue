// Contracts for enhancement 0000 (template).
//
// contracts/ is the optional home for compilable CUE that is NOT a
// core-schema delta: executable decision procedures, contracts over Go
// kernel behaviour, CLI command contracts, vocabularies/taxonomies —
// anything where CUE syntax buys precision but no opmodel.dev/core
// definition is being added or changed (that is schemas/, gated by
// config.yaml `core_schema`). Never required; when present, `task vet`
// requires it to be non-empty and to compile (`cue vet ./...` from this
// directory).
//
// Author guidance:
//   - Keep the package name `contracts`.
//   - State in a header comment what kind of contract this file is and
//     what the source of truth is (e.g. "mirrors Go types in
//     opm-operator/api/v1alpha1 — Go is authoritative").
//   - Mark unresolved fields with `// OQN:` comments pointing at
//     ../03-decisions.md, same convention as schemas/.
//   - Concrete values and assertion fields make compilation a real test —
//     the same principle as schemas/examples.cue.
package contracts
