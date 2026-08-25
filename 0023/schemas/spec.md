# Specification changes: Artifact Provenance, Signatures and Platform Trust Policy

Provisional. One NEW construct is sketched; whether it lands in core at all is OQ3. This pre-drafts the core/SPEC.md co-update the core slice would make under the `core-schema-edit` protocol if it does; the CUE shape lives in [`target.cue`](target.cue).

## `#TrustPolicy` (NEW, home undecided: SPEC.md §3.4 `#Platform` or the platform package)

### Definition

`#TrustPolicy` is a platform's statement of whom it trusts for the artifacts it materializes: the signing identities it accepts, the builders whose provenance it accepts, the assurance level it requires and what it does on failure. It is declared platform-wide and may be overridden per subscription. It is consumed by the kernel's verification step and enforced by the operator; nothing in `core` evaluates it.

### Shape

```cue
#TrustPolicy: {
    signers!:  [...{issuer!: string, subject!: string}]
    builders?: [...string]
    level:     1 | 2 | 3 | *2
    mode:      "refuse" | *"warn"
    offline?:  bool
}
```

### Constraints

- `signers` MUST name at least one identity; an empty policy is not a policy (absence of the field means no verification, per OQ5's default).
- A per-subscription policy MUST fully replace the platform-wide one for that subscription, never merge (provisional; OQ3).
- Open: the identity vocabulary (OQ3), the builder vocabulary and reachable levels (OQ4), the default mode and offline semantics (OQ5).

### Rationale

- **Why on the platform.** The platform already states what it consumes (0019 D5); stating whom it trusts beside it keeps one place to read a cluster's supply-chain posture (0023 D2).
- **Why identities, not keys.** Keyless signing binds a signature to a workflow identity issued by an OIDC provider; the policy names that identity, and OPM operates no keys.
