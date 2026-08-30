# Risks, Drawbacks, Alternatives: CUE Testing and Conformance

## Risks and Mitigations

- **Diagnostic churn drowns real drift.** `cue vet` prints source positions under each message, and those point into `core`'s sources, which shift every release; verbatim comparison would fail on every core bump for reasons that are not behaviour. **Mitigation:** D2 records message lines, and the implementing change decides how positions are excluded (OQ4); a control case whose message is known-stable detects an over-aggressive filter.
- **Export formatting drift masquerades as render drift.** A `cue` release can change YAML/JSON export formatting (key order, quoting) without changing values. **Mitigation:** compare a canonical form for render cases where the implementer chooses to, and record formatting-only cells as explained drift; the failure is loud rather than silent either way, which is the intended posture.
- **The matrix grows faster than the corpus.** Four axes multiply; a full product is not runnable per PR. **Mitigation:** the policy (D3) is per-cell determinability, not per-PR exhaustiveness; the implementing change picks the cells a release runs (the new version against its predecessor on each axis) and leaves the full product to a scheduled run.
- **The negative idiom passes on incomplete values.** A "must reject" assertion is satisfied by a value that is merely unresolved. **Mitigation:** D6's pairing rule, and concrete evaluation in the in-package check so an incomplete value fails there too.
- **Upstream `k8s.io` snapshots do not name a Kubernetes release.** A claim like "conformant with Kubernetes 1.32" cannot be derived from the module. **Mitigation:** OQ2 decides whether the axis is the snapshot version (honest and mechanical) or a maintained mapping table (useful and a maintenance cost).
- **The suite hardens the current behaviour, including defects.** Recording a cell makes today's output the expectation, defects included. **Mitigation:** that is the point of a regression record; a defect fix is intentional drift, explained in the release and recorded. The suite never decides what is correct, only what changed.

## Drawbacks

- A second place to update when behaviour changes on purpose: the release that changes it also records the new cell. The reviewed diff is the account of the change, so the cost buys the changelog's evidence.
- A Go runner for a pure-CUE subject, if CUE's testscript convention is adopted (OQ4 covers the runner choice): the runner's `go.mod` pins the script tooling and never `cuelang.org/go`, but it is still Go in a suite about CUE.
- Test files beside definitions may ship inside published modules (OQ8), or must be kept in a sibling package that cannot see hidden fields. Either costs something.
- Per-cell records are repetitive by design; most cells are identical to their predecessor.

## Alternatives

- **Make `library`'s schematest the conformance suite.** It already asserts against the published core with exact messages. **Why not:** it pins one core and one CUE per Go module, is the kernel's test suite, and reports schema drift as Go fixture failures one repo away from the cause.
- **A canary per incident** (the `cueregression` pattern). **Why not:** it detects only shapes someone was already burned by, in Go, and does not accumulate into a record.
- **Rely on the demo cluster.** Apply the rendered fleet to `opm-kind-demo` per release. **Why not:** it tests admission, not schema behaviour, cannot see refusal text, and finds a rename by replacing an object.
- **Type the raw family's inputs against upstream instead of checking outputs.** **Why not:** it changes the raw module's dependency rule and still says nothing about what a transformer emits.
