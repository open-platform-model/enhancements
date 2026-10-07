<!-- MOCKUP EXCERPT: five of 36 decisions, shortened from 0013/03-decisions.md. See openspec/MOCKUP.md.
     The decision block is today's format, unchanged. Its shape is under review. -->

# 0013 decisions: Attribute-Declared Secret Fields

## Decisions

### D10: The secret field is typed `#Secret`; the attribute carries routing only

**Kind:** contract

**Decision:** A sensitive `#config` field is declared as `#Secret @opm(secret, …)`. The type carries only how the secret is supplied: a literal `{value}` or a reference `{ref, key}`. All routing (group, key, type) lives in the attribute. The deployer chooses the arm per environment.

**Requirements:** `0013:D10:R1`, `0013:D10:R2`, `0013:D10:R3` in [specs/secrets/spec.md](specs/secrets/spec.md)

**Alternatives considered:**

- **A field typed `string`, with no contract type.** Rejected: it removes the only slot where a deployer can say "this Secret already exists".
- **`string | #SecretRef`, a bare scalar for the common case.** Rejected: the value's kind would change during resolution, so a module with a referenced secret would only type-check with the kernel in the loop.

**Rationale:** The attribute carries what is the same in every environment and travels in the published module. The type carries what the deployer fills per environment, and CUE itself checks it.

**Source:** User decision 2026-07-27.

### D11: The kernel rewrites each secret value to a reference before render

**Kind:** contract

**Decision:** Before the component graph is built, the kernel rewrites every marked path to a reference, whichever arm the deployer wrote. A literal becomes a reference to the object the kernel creates. A reference passes through unchanged. The plaintext never enters the graph.

**Requirements:** `0013:D11:R1`, `0013:D11:R2`, `0013:D11:R3` in [specs/secrets/spec.md](specs/secrets/spec.md)

**Alternatives considered:**

- **An opaque handle plus a lookup table.** Rejected: machinery that existed only because the field was a string. A struct carries the object name inside the value.
- **Leave the literal and let the transformer read it.** Rejected: that is plaintext in the component graph.

**Rationale:** A literal says what the data is; a reference says where it lives. Once the kernel has placed a literal, it also has a location, so both forms converge before anything renders.

**Source:** User decision 2026-07-27.

### D13: Discovery keys on the type and the marker, and fails closed

**Kind:** contract

**Decision:** A `#Secret` field with no attribute is discovered with default routing. A field that carries the marker but is not typed `#Secret` is an error. The marker only overrides; it is never what keeps a secret safe.

**Requirements:** `0013:D13:R1`, `0013:D13:R2` in [specs/secrets/spec.md](specs/secrets/spec.md)

**Alternatives considered:**

- **Marker-only discovery.** Rejected: a `#Secret` field without the marker would be invisible, and its literal would reach the render as plain text.

**Rationale:** Forgetting an annotation must end in a loud error or a safe default, never in a silent leak.

**Source:** User decision 2026-08-13.

### D25: An authored instance package refuses literal secrets

**Kind:** contract

**Decision:** A literal secret value is accepted only from a values source the kernel assembles into the build itself: a `ModuleInstance` CR's values, or a values file given alongside an instance. An authored instance package refuses a literal at a marked path.

**Requirements:** `0013:D25:R1`, `0013:D25:R2` in [specs/secrets/spec.md](specs/secrets/spec.md)

**Alternatives considered:**

- **Allow them as a documented exception.** Rejected: it breaks the no-plaintext-in-the-render guarantee on one path.

**Rationale:** The kernel can keep plaintext out of the build only where it assembles the values itself.

**Source:** User decision 2026-09-30.

### D26: Exported instances encrypt the literal values at marked paths

**Kind:** contract

**Depends:** 0014:D1

**Decision:** When an instance is exported for GitOps, the `value` field of every literal at a marked path is SOPS-encrypted in the exported `ModuleInstance`. Everything else stays readable. This changes what 0014 promised: exported values are no longer written verbatim where a marked path holds a literal.

**Requirements:** `0013:D26:R1` (new), and `0014:D3:R1` (modified), in [specs/instance-export/spec.md](specs/instance-export/spec.md)

**Alternatives considered:**

- **Encrypt rendered Secret manifests.** Rejected: on the export path the committed artifact is the instance, not its manifests.

**Rationale:** Without this, the export path commits literals to git.

**Source:** User decision 2026-09-30.

## Risks

- **A literal in a custom resource is plaintext at rest.** Accepted and documented. A reference or a named source is the production recommendation.

## Rollout

Two waves. Wave 1 ships the literal and the reference. Named sources follow in wave 2 without changing what wave 1 shipped. Core releases first; the catalog, the kernel and the fleet follow.

## Open questions

- **OQ2: Is replacing a supplied arm with the resolved arm a clean value replacement?** Blocking: acceptance. Status: resolved-by-D16.
