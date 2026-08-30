# Design Decisions: Artifact Provenance, Signatures and Platform Trust Policy

This document records every significant design choice with its reasoning and the alternatives that were ruled out. Numbers are permanent; while the entry is `draft`, bodies are revised in place.

Only two decisions are recorded. The entry is held open on purpose: the questions in `07-questions.md` are answered by research and experiments first, and decisions accrete from their outcomes.

---

## Decisions

### D1: Provenance and signatures attach as OCI referrers to the artifact's manifest digest

**Kind:** contract

**Decision:** Every signed claim about a published catalog or module (build provenance, signature, and any optional claim this entry later admits) is a separate OCI artifact whose `subject` is the manifest digest the artifact's tag resolves to. Nothing is added to the CUE module manifest, its config blob or its layers. The claim's subject is always a digest, never a tag.

**Alternatives considered:**

- *A third layer or a config-blob payload.* Rejected: CUE's client refuses a module manifest that does not have exactly two layers, and treats the config only as a type tag.
- *Manifest annotations.* Rejected for signed claims: annotations are written by whoever pushes and carry no signature; they are the right place for unsigned hints (0022 D6) and nothing more.
- *A parallel tag (`v2.0.1.sig`, `v2.0.1.att`).* Rejected as the primary form: the referrers convention already defines the fallback tag (`sha256-<digest>`) keyed by digest, which is what makes a claim follow the artifact rather than the tag name. The fallback may still be what the registry actually serves (experiment 01).
- *A transparency log only, nothing in the registry.* Rejected: a consumer that resolves a tag has the registry in hand and may not have the log; the log is the discovery and audit channel, the referrer is the artifact-local copy.

**Rationale:** Referrers are the OCI-standard way to attach claims to a digest. CUE ignores them, and its mirror carries them forward. The SLSA and Sigstore tooling already produce and consume them. Attaching by digest is what makes the claim survive a re-pointed tag and what lets a verifier reject one.

**Source:** User decision 2026-08-25. Measured: `research/findings.md` (manifest shape, CUE `modregistry` `mirrorReferrers`, no referrers present today).

### D2: The trust policy is the platform's

**Kind:** scope

**Decision:** Whom to trust is declared on the platform, not on the artifact, the CLI or the cluster. A platform states the signer identities and builders it accepts, with a per-subscription override, and every artifact the platform materializes is verified against that statement before its content is used. The kernel performs the verification so that the CLI and the operator reach the same verdict; the operator enforces, the CLI reports.

**Alternatives considered:**

- *Policy in the CLI's configuration.* Rejected: the actor deciding what runs in a cluster is the platform, and a laptop setting does not travel to the operator.
- *Policy on the artifact (self-declared trust).* Rejected: an artifact cannot vouch for itself.
- *Cluster-wide admission policy outside OPM (a policy engine on the rendered objects).* Not chosen as the primary form: it sees rendered Kubernetes objects, not the OPM artifact that produced them, so it cannot check provenance of the source. It remains a complementary layer.

**Rationale:** The platform is where OPM already states what it consumes (subscriptions with exact versions, 0019 D5); adding whom it trusts beside what it pins keeps one place to read a cluster's supply-chain posture.

**Source:** User decision 2026-08-25. Enhancement 0019 D5, D6 (platform imports its catalog; operator generates the platform package).

Open Questions live in [`07-questions.md`](07-questions.md), the entry's question register.
