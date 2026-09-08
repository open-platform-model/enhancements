// Package filter expresses the planned kernel filter-resolution semantic
// against Masterminds/semver — the library the kernel will actually ship.
// Three-step: range → allow append → deny subtract.
package filter

import "github.com/Masterminds/semver/v3"

// Filter mirrors the planned core/platform.cue #SubscriptionFilter shape.
type Filter struct {
	Range string
	Allow []string
	Deny  []string
}

// Resolve returns the selected version subset in deterministic order: every
// in-range version preserves its input position, then `allow` appends any
// not-already-present, then `deny` filters the combined list.
func Resolve(input []string, f Filter) ([]string, error) {
	rangeConstraint, err := semver.NewConstraint(f.Range)
	if err != nil {
		return nil, err
	}

	step1 := make([]string, 0, len(input))
	for _, v := range input {
		parsed, perr := semver.NewVersion(v)
		if perr != nil {
			return nil, perr
		}
		if rangeConstraint.Check(parsed) {
			step1 = append(step1, v)
		}
	}

	step2 := append([]string{}, step1...)
	for _, v := range f.Allow {
		if !contains(step2, v) {
			step2 = append(step2, v)
		}
	}

	out := make([]string, 0, len(step2))
	for _, v := range step2 {
		if !contains(f.Deny, v) {
			out = append(out, v)
		}
	}
	return out, nil
}

func contains(haystack []string, needle string) bool {
	for _, v := range haystack {
		if v == needle {
			return true
		}
	}
	return false
}
