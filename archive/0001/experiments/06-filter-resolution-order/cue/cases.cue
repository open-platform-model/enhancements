// Canonical case: input list `[1.0.0, 1.1.0, 1.2.0, 1.3.2, 1.4.0, 2.0.0]`,
// filter `{ range: ">=1.0.0 <2.0.0", allow: ["2.0.1"], deny: ["1.3.2"] }`.
// Expected resolution: `[1.0.0, 1.1.0, 1.2.0, 1.4.0, 2.0.1]`.
//
// CUE unification of `expected` against `resolved.out` fails this file if
// the order or contents differ.
package filter

canonical: {
	resolved: #resolve & {
		input: {
			in_range: ["1.0.0", "1.1.0", "1.2.0", "1.3.2", "1.4.0"]
			allow: ["2.0.1"]
			deny: ["1.3.2"]
		}
	}

	// Expected output unified against resolved.out — failure = order or
	// contents mismatch.
	expected: ["1.0.0", "1.1.0", "1.2.0", "1.4.0", "2.0.1"]
	check:    resolved.out & expected
}
