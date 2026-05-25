// Every entry MUST violate #CatalogFQNType. `cue vet ./negative/...` fails on
// every assignment — non-zero exit + at least one error per entry is the
// success criterion. Run with `2>&1 | grep -c .` to count errors.
//
// Note on overlap with #FQNType: a string like
// `opmodel.dev/catalogs/opm/transformer@1.0.0` is accepted by BOTH regexes
// (it's a valid 4-segment path under #CatalogFQNType and a valid
// path/name@version under #FQNType). The two types are structurally
// distinguished by usage, not by string shape. This experiment validates
// #CatalogFQNType's own boundaries — not the disjointness between the two
// regexes.
package negative

import "enhancements.opmodel.dev/0001/experiments/08-catalog-fqn-regex/schema"

cases: [string]: schema.#CatalogFQNType

cases: {
	major_only_legacy:   "opmodel.dev/catalogs/opm@v1"      // old MAJOR-only shape, retired by D5
	major_only_bare:     "opmodel.dev/catalogs/opm@1"       // missing minor + patch
	missing_patch:       "opmodel.dev/catalogs/opm@1.0"     // SemVer 2 requires 3 numeric components
	four_part:           "opmodel.dev/catalogs/opm@1.0.0.4" // SemVer 2 forbids 4 numeric components
	no_version:          "opmodel.dev/catalogs/opm"         // no @version suffix
	no_path:             "@1.0.0"                           // empty modulePath before @
	uppercase_in_path:   "opmodel.dev/Catalogs/opm@1.0.0"   // uppercase in path segment
	trailing_dash:       "opmodel.dev/catalogs/opm@1.0.0-"  // prerelease cannot be empty
	v_prefix:            "opmodel.dev/catalogs/opm@v1.0.0"  // SemVer FQN does not carry v-prefix
}
