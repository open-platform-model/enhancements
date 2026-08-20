// Concrete example instances for the target.cue delta — the test.
//
// A definitions-only file passes `cue vet ./...` no matter what it says;
// unification against concrete values is what actually validates the
// delta. This file is required (with spec.md) from the draft → accepted
// gate. Author guidance:
//
//   - Write at least one realistic instance per NEW or CHANGED definition,
//     unified against it: `example: #MyDef & {...}`.
//   - Pin computed/derived values with hidden assertion fields so a change
//     in behaviour breaks the build:
//       _assertDerivedName: example.name & "expected-value"
//   - Record must-fail cases as commented-out blocks carrying the exact
//     error text observed, so reviewers can re-run them by hand.
//   - Keep the package name `schema` — same package as target.cue, so
//     `cue vet ./...` from this directory evaluates both together.
package schema
