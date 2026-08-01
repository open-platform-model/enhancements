package main

import "regexp"

// Level is D34's Kubernetes ladder: v1alpha1 → v1beta1 → v1.
type Level int

const (
	Alpha Level = iota
	Beta
	GA
)

var apiVersionRE = regexp.MustCompile(`^v[0-9]+(alpha|beta)?[0-9]*$`)

// ParseLevel classifies a contract's apiVersion. D34 keys D27's promise to the
// level: the additive-only rule — and therefore this gate — binds at beta and
// GA only. An alpha contract may remove a field, narrow a type, or change a
// default without refusal, because that is what its level promises.
func ParseLevel(apiVersion string) (Level, bool) {
	if !apiVersionRE.MatchString(apiVersion) {
		return GA, false
	}
	switch {
	case regexp.MustCompile(`alpha[0-9]*$`).MatchString(apiVersion):
		return Alpha, true
	case regexp.MustCompile(`beta[0-9]*$`).MatchString(apiVersion):
		return Beta, true
	default:
		return GA, true
	}
}

func (l Level) String() string {
	switch l {
	case Alpha:
		return "alpha"
	case Beta:
		return "beta"
	}
	return "ga"
}

// Enforced reports whether D27's promise binds at this level (D34).
func (l Level) Enforced() bool { return l != Alpha }
