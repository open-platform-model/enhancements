// Every entry MUST satisfy #CatalogFQNType. `cue vet ./positive/...`
// succeeds iff every assignment unifies cleanly.
package positive

import "enhancements.opmodel.dev/0001/experiments/08-catalog-fqn-regex/schema"

cases: [string]: schema.#CatalogFQNType

cases: {
	plain_release:      "opmodel.dev/catalogs/opm@1.0.0"
	first_post_d23_tag: "opmodel.dev/catalogs/opm@0.1.0"     // D23 — first new-shape OPM catalog tag
	prerelease_short:   "opmodel.dev/catalogs/opm@1.4.0-rc.1"
	build_metadata:     "opmodel.dev/catalogs/opm@1.0.0+build.123"
	prerelease_dotted:  "opmodel.dev/catalogs/b@2.0.0-beta.1.alpha"
	two_digit_majors:   "example.com/x@10.20.30"
	single_segment:     "mycatalog@1.0.0"                    // single-segment "path" — catalog regex
	                                                         // accepts; #FQNType would reject (no slash)
	deep_path:          "opmodel.dev/a/b/c/d/e/f@1.4.0"      // multi-segment path; no name suffix
}
