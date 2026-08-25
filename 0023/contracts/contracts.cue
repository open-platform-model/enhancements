// Contracts for enhancement 0023 — Artifact Provenance, Signatures and
// Platform Trust Policy.
//
// Non-core contracts: the claim kinds this entry attaches (#ClaimKind), the
// attachment contract (#Attachment, D1), and the verification verdict
// (#Verdict) the kernel returns and the CLI and operator surface. All
// provisional while the entry is open; fields gated on an Open Question
// carry an `// OQN:` marker pointing at ../07-questions.md.
package contracts

// #ClaimKind: what may be attached beside an artifact. The first two are
// committed scope; the last two are optional scope held by OQ1 and OQ2.
#ClaimKind: "provenance" | "signature" | "capability" | "advisory"

// #Attachment: how a claim is attached (D1). Always a referrer whose
// subject is the artifact's manifest digest; never a layer, never an
// annotation, never keyed by tag.
#Attachment: {
	kind:         #ClaimKind
	subject:      =~"^sha256:[0-9a-f]{64}$"
	artifactType: string // e.g. "application/vnd.in-toto+json" for provenance
	// OQ (experiment 01): whether the registry serves the referrers API or
	// only the sha256-<digest> fallback tag; the attachment is the same
	// manifest either way.
}

// #Verdict: the kernel's answer for one artifact against one policy.
#Verdict: {
	digest:  =~"^sha256:[0-9a-f]{64}$"
	found:   [...#ClaimKind]
	signer?: {issuer: string, subject: string}
	builder?: string
	level?:  1 | 2 | 3
	source?: {repository: string, commit: string}
	outcome: "verified" | "unverified" | "refused"
	reason?: string
	// OQ5: whether the transparency log was consulted.
	online: bool
}

_exampleVerdict: #Verdict & {
	digest:  "sha256:c6b0be463c8a32a136c98c102c0115799b7531064e7c185def655b9e646b20b1"
	found:   ["provenance", "signature"]
	signer:  {issuer: "https://token.actions.githubusercontent.com", subject: "https://github.com/open-platform-model/modules/.github/workflows/release.yml@refs/heads/main"}
	builder: "https://github.com/open-platform-model/modules/.github/workflows/release.yml@refs/heads/main"
	level:   2
	source:  {repository: "github.com/open-platform-model/modules", commit: "7c946b0"}
	outcome: "verified"
	online:  true
}
