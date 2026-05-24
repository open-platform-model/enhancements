// Every entry MUST violate #FQNType. `cue vet ./negative/...` fails on every
// assignment — non-zero exit + at least one error per entry is the success
// criterion. Run with `2>&1 | grep -c .` to count errors.
package negative

import "enhancements.opmodel.dev/0001/experiments/02-semver-fqn-regex/schema"

cases: [string]: schema.#FQNType

cases: {
	major_only_legacy:  "opmodel.dev/x/y@v1"        // old MAJOR-only shape, retired
	major_only_bare:    "opmodel.dev/x/y@1"         // missing minor + patch
	missing_patch:      "opmodel.dev/x/y@1.0"       // SemVer 2 requires 3 numeric components
	four_part:          "opmodel.dev/x/y@1.0.0.0"   // SemVer 2 forbids 4 numeric components
	trailing_dash:      "opmodel.dev/x/y@1.0.0-"    // prerelease cannot be empty
	missing_prerelease: "opmodel.dev/x/y@1.0.0-+a"  // empty prerelease before build
	v_prefix:           "opmodel.dev/x/y@v1.0.0"    // SemVer FQN does not carry v-prefix
	no_at:              "opmodel.dev/x/y/1.0.0"     // version separator must be @
	leading_zero_path:  "opmodel.dev/x/Y@1.0.0"     // uppercase in name segment
}
