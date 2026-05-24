// CUE expression of the filter resolution order: range → allow → deny.
//
// Concession: CUE cannot natively parse SemVer range strings ("">=1.0.0 <2.0.0").
// The experiment expresses the range semantic as an explicit `in_range` list,
// pinning ORDER independent of parser. The Go side proves the same order
// against Masterminds/semver, where the range string IS parsed.
package filter

import (
	"list"
	"strings"
)

#VersionType: string &
	=~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#Filter: {
	// `in_range` substitutes for a parsed range — the abstract input.
	in_range: [...#VersionType]
	allow: [...#VersionType] | *[]
	deny: [...#VersionType] | *[]
}

#resolve: {
	input!: #Filter
	out: [...#VersionType]

	// Step 1: start with in_range
	_step1: input.in_range

	// Step 2: append any allow entry not already in step1
	_step2: list.Concat([_step1, [for v in input.allow if !list.Contains(_step1, v) {v}]])

	// Step 3: subtract any deny entry
	out: [for v in _step2 if !list.Contains(input.deny, v) {v}]
}

// Helper to render the resolved list as a sorted string for test comparison.
_join: {
	in: [...string]
	out: strings.Join(in, ",")
}
