// Concrete example instances for the target.cue sketch — the test.
//
// One platform accepting first-party artifacts signed by the release
// workflows of the open-platform-model organization, with a stricter
// per-subscription override. Every shape here is provisional (OQ3, OQ4,
// OQ5); the assertions pin the sketch's defaults so a change is visible.
package schema

firstParty: #PlatformTrustSurface & {
	trust: {
		signers: [{
			issuer:  "https://token.actions.githubusercontent.com"
			subject: "https://github.com/open-platform-model/*/.github/workflows/release.yml@refs/heads/main"
		}]
	}
	registry: "opmodel.dev/catalogs/opm@v2": {
		trust: {
			signers: [{
				issuer:  "https://token.actions.githubusercontent.com"
				subject: "https://github.com/open-platform-model/catalog_opm/.github/workflows/release.yml@refs/heads/main"
			}]
			level: 3
			mode:  "refuse"
		}
	}
}

_assertDefaultLevel: firstParty.trust.level & 2
_assertDefaultMode:  firstParty.trust.mode & "warn"
_assertOverride:     firstParty.registry["opmodel.dev/catalogs/opm@v2"].trust.level & 3
