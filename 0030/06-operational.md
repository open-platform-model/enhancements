# Operational Concerns: OPM Portal V1

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **Problem documents.** Every API error is an RFC 9457 problem document with a `code` from D2:R6's set. `forbidden` (the user lacks RBAC) and `not_readable_by_portal` (the portal's role lacks it) are distinct, so an operator can tell a user problem from an install problem.
- **Access states inside responses.** Items the user may not read are `forbidden`, items the portal may not read are `notReadable`, and health results built over either are `partial` (D3:R4, D7:R3).
- **Freshness.** Health documents carry `evaluatedAt` and `live`, so a polled object never passes for a watched one (D3:R5).
- **Per-user access log in milestone 2.** One structured line per authorized read and per denial: principal, verb, resource, namespace, name, decision, request id (D6:R7). This is the only record of who read what, because the API server's audit log sees the portal's ServiceAccount.
- **Startup diagnostics.** In local mode the portal logs which OPM kinds the kubeconfig's identity cannot list cluster-wide and falls back to the namespaces given (D5:R5). In-cluster it refuses to start without identity prefixes unless the API server trusts its issuer (D6:R6).
- **Health endpoints** for liveness, readiness and version, outside the versioned API.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

No existing consumer breaks. `opmodel.dev/core` is untouched. The opm-operator gains viewer roles, an addition. The portal is new: its releases start at `0.1.0` and stay `0.x` until the read API declares stability (OQ10); its API starts at `v1alpha1`, where changes are additive and a breaking one is marked as such in the release notes (D2:R2). Leaving alpha adds a new path version served beside the old one.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. The portal adds a view; `kubectl`, the CLI's tree and status commands, and the operator's status stay as they are.

## Rollback

**If this lands and proves bad, what's the rollback story?**

The portal writes nothing to the cluster and keeps no state beyond in-memory sessions, so rollback is deletion: stop the local binary, or delete the in-cluster Deployment, its ServiceAccount, its role and binding. Nothing the operator manages changes. The operator's viewer roles are unbound by default and harmless to leave in place; removing them only takes away read access an administrator granted.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- **opm-operator before milestone 2's exit.** The viewer roles (D11:R4) must be released before the in-cluster portal can show a non-admin the Platform, ModulePackages or registrations. Milestone 1 needs nothing from the operator: it reads today's status with the user's own access.
- **opm-operator before any requires edge.** D4:R3 holds until the operator records provider-contract demand (OQ18). The same holds for transformer provenance (OQ5) and a Platform contract inventory (OQ4).
- **A published provider fixture and an operator release on library v1.0.0-beta.4 or later before the released-operator registration rerun.** The fixture (opm-operator PR 212) must be published under `testing.opmodel.dev` by its repo's CI, and the released v1.0.0-beta.5 refuses every rendered claim (opm-operator issue 210), so the acceptance criterion on registrations waits for both.
- **The portal pins one operator version.** The operator API module it imports and the operator its end-to-end tests install move together, by hand, until the portal joins the release cascade (OQ14).
- **opmodel.dev after the portal's first docs publish.** The site includes the portal's documentation bundle only once the portal has published one; adding it is a site change that names the bundle.
