// Core-schema delta for enhancement 0023 — Artifact Provenance, Signatures
// and Platform Trust Policy.
//
// Delta manifest (vs opmodel.dev/core@v2):
//
//   - #TrustPolicy — NEW (SKETCH, OQ3): the statement of whom a platform
//     trusts. Modeled standalone; whether it lands on #Platform in core or
//     in the platform package the operator generates is OQ3, and every
//     field below is provisional until the research and experiments in
//     07-questions.md conclude.
//   - #PlatformTrustSurface — the slice of #Platform this entry would touch
//     if OQ3 resolves to core: a platform-wide policy plus a per-subscription
//     override.
//
// Fields gated on an Open Question carry an `// OQN:` marker pointing at
// ../07-questions.md.
package schema

// #SignerIdentity: a keyless signing identity. OQ3: vocabulary; this is the
// Sigstore certificate-identity pair (OIDC issuer plus a subject pattern).
#SignerIdentity: {
	issuer!:  string // e.g. "https://token.actions.githubusercontent.com"
	subject!: string // exact or pattern, e.g. "https://github.com/open-platform-model/modules/.github/workflows/release.yml@refs/heads/main"
}

// #BuilderIdentity: who produced the provenance. OQ4: the builder id
// vocabulary depends on which generator is used.
#BuilderIdentity: string // e.g. "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v2.0.0"

// #AssuranceLevel: the SLSA build level the policy requires. OQ4.
#AssuranceLevel: 1 | 2 | 3

// #TrustPolicy: what a platform accepts. OQ3 (shape and home), OQ5 (mode
// default and offline verification).
#TrustPolicy: {
	signers!: [...#SignerIdentity]
	builders?: [...#BuilderIdentity]
	level: #AssuranceLevel | *2
	mode:  "refuse" | *"warn"

	// OQ5: whether verification may proceed without the transparency log.
	offline?: bool
}

// #PlatformTrustSurface: the slice of #Platform this entry touches IF OQ3
// resolves to core. Everything else on #Platform is unchanged and elided.
#PlatformTrustSurface: {
	// Platform-wide default.
	trust?: #TrustPolicy

	// Per-subscription override, keyed as the platform's registry map is
	// (module path with major, 0019 D5). OQ3: whether prefix keys are allowed.
	registry?: [string]: {
		trust?: #TrustPolicy
		...
	}
}
