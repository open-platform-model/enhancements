// The D19 compatibility floor, as the kernel would apply it at materialize.
// Kept as plain CUE here so the rule is readable; the production comparison is
// Go, where library/opm/materialize/filter.go already uses a semver library.
//
// SCOPE: compares MAJOR.MINOR.PATCH numerically and IGNORES prerelease
// ordering, so "1.0.0-dev" reads equal to "1.0.0" here. Real semver sorts a
// prerelease BELOW its release — that gap is OQ17.
package platform

import "strings"
import "strconv"

#Triple: {
	v!:    string
	_core: strings.SplitN(v, "-", 2)[0]
	_p:    strings.Split(_core, ".")
	out: [strconv.Atoi(_p[0]), strconv.Atoi(_p[1]), strconv.Atoi(_p[2])]
}

#GTE: {
	have!: [int, int, int]
	want!: [int, int, int]
	out: [
		if have[0] != want[0] {have[0] > want[0]},
		if have[1] != want[1] {have[1] > want[1]},
		have[2] >= want[2],
	][0]
}

// #CatalogFloor: is the catalog the platform materialized new enough for a
// module that was built against `requiredVersion`?
#CatalogFloor: {
	requiredVersion!: string // module's builtAgainstCatalog
	resolvedVersion!: string // tag the platform materialized
	satisfied: (#GTE & {
		have: (#Triple & {v: resolvedVersion}).out
		want: (#Triple & {v: requiredVersion}).out
	}).out
}
