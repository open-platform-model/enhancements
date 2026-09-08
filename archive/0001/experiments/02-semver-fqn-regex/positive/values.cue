// Every entry MUST satisfy #FQNType. `cue vet ./positive/...` succeeds iff
// every assignment unifies cleanly.
package positive

import "enhancements.opmodel.dev/0001/experiments/02-semver-fqn-regex/schema"

cases: [string]: schema.#FQNType

cases: {
	plain_release:      "opmodel.dev/modules/opm/container@1.0.0"
	prerelease_short:   "opmodel.dev/x/y@0.1.0-rc.1"
	prerelease_dotted:  "opmodel.dev/x/y@1.0.0-alpha.2"
	prerelease_numeric: "opmodel.dev/x/y@2.0.0-0"
	build_metadata:     "opmodel.dev/x/y@1.0.0-alpha.2+build.42"
	build_only:         "opmodel.dev/x/y@1.0.0+sha.abc123"
	two_digit_majors:   "opmodel.dev/x/y@10.20.30"
	hyphenated_name:    "opmodel.dev/x/sub-pkg/my-resource@1.0.0"
	deep_path:          "opmodel.dev/a/b/c/d/e/f/widget@1.4.0"
}
