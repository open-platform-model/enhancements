// The in-build form of compile/module.go's hard gate, in its own package so
// the fixture's diagnostics stay independently readable.
//
// `cue vet` of THIS package refuses at resolvedGate with "conflicting values
// false and true" — the fail-closed refusal, expressed in-build. Measured
// alongside it: with the gate failing, `cue eval -e diagnostics` on this same
// package is ALSO refused (the CLI validates the whole instance before
// answering any expression), and probe/ measures whether the Go API's
// LookupPath can still read `diagnostics` off the built value. Those two
// readouts are what decide where the gate can live.
package gate

import (
	m "experiments.opmodel.dev/0019/match-in-one-build/broken/missing"
)

diagnostics:  m.diagnostics
resolvedGate: m.resolved & true
