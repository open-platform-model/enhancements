# Open Questions: OPM Portal V1

**This file is the single canonical location for Open Questions.** An `## Open Questions` block anywhere else in the entry fails `task vet`.

`OQ` numbers are permanent, never reused, never renumbered, like `DN` and `DN:Rn`. A vacated number keeps a one-line tombstone. Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, `deferred-to-implementation`, or `answered`. Each unresolved entry also carries `Blocking:` (`acceptance` with the reason inline, `deferrable`, or `implementation`).

The questions below came out of the portal design and were then checked against the live capture ([experiment 01](experiments/01-live-cluster-capture/)); three were reframed by what the capture showed (OQ11, OQ12, OQ18).

## Open Questions

### Access and identity

- **OQ1: Which identity model follows V1 in-cluster: SubjectAccessReview-then-read, impersonation, or token passthrough?** Status: open. Blocking: deferrable. D6 settles V1 on SubjectAccessReview-then-read, which keeps users out of the API server's audit log and puts the record in the portal's own access log. Impersonation (classic, then ConstrainedImpersonation once the cluster floor is 1.36 or later) puts users in the audit log at the cost of an impersonate grant; token passthrough works only where the API server trusts the portal's issuer. The question becomes binding when V2 adds writes.
- **OQ2: What is the minimum Kubernetes version the portal supports?** Status: open. Blocking: acceptance: the supported range is a promise every installer relies on, and D9's event selectors and OQ1's ConstrainedImpersonation depend on it. OPM declares no floor today (tested 1.34 to 1.36). The capture verified `regarding.*`, `reason` and `type` field selectors on events.k8s.io/v1 at 1.36 only. Resolving it means naming a floor and checking the selectors there.
- **OQ6: Who may read the cluster-scoped Platform and TransformerRegistrations, and do the operator's viewer roles aggregate into the built-in `view` role?** Status: open. Blocking: acceptance: decides what D11:R4's operator role grants and whether every namespace viewer can see platform state. Aggregation into `view` would also expose `spec.values` on ModuleInstances to every namespace viewer, which D8 avoids in the portal but not in `kubectl`. Either way, values a module renders into non-Secret objects are already readable by every namespace viewer, in the portal and in `kubectl` alike (D8).
- **OQ8: Does the operator's embedded kernel redact marked secret paths in condition and event messages?** Status: open. Blocking: acceptance: if it does not, D8 needs a requirement that the portal redacts messages, or must state that it shows them verbatim. Entry 0013's diagnostics rule defines the redaction; the research found no redaction code in the operator and did not verify whether the embedded library applies it.

### Status and history

- **OQ3: Should the operator report workload health (a `Healthy` condition or per-entry health), or does health stay a consumer concern?** Status: open. Blocking: deferrable. D3 computes health in the portal and needs nothing from the operator. The capture shows why the question exists: the operator's Ready stayed True through a ten-minute image-pull failure. An operator condition would let the CLI and other consumers share one answer; it would also be a health wait the operator has deliberately not built.
- **OQ9: Is a one-hour event feed enough, or should the portal or the operator persist events or extend status history?** Status: open. Blocking: deferrable. D9 shows events as an expiring feed. The operator keeps at most ten status history entries (five were present in the largest snapshot), so a run of ten failed retries pushes every earlier entry out and older history is lost too.
- **OQ19: Should the operator record render warnings durably in status, not only as events?** Status: open. Blocking: deferrable. Catalog skew and unhandled optional traits are emitted only as `RenderWarning` events and vanish with the event lifetime; D9:R5 labels this on the instance page. A non-gating condition or a bounded warning list on the instance would make them durable.

### Graph and data the operator does not record

- **OQ4: What shape should the Platform's contract inventory take in its status?** Status: open. Blocking: deferrable. A per-catalog list of defined and provider-fulfilled contracts would let the Platform view draw which catalog defines which contract and which provider fulfils it. Not needed for V1, which shows the Platform's `ContractsFulfilled` condition as text.
- **OQ5: Should each inventory entry record the transformer that produced it, and is that part of the inventory contract?** Status: open. Blocking: deferrable. It would give a transformer-to-object provenance edge. V1 draws none (D4).
- **OQ12: Should rendered objects and pod templates carry the instance uuid and namespace labels?** Status: open. Blocking: deferrable. Reframed by the capture: ReplicaSets and Pods already carry `module-instance.opmodel.dev/name` and `component.opmodel.dev/name`, but not the uuid label and not a namespace label, so a Pod cannot be tied to its instance across namespaces by label alone. V1 walks ownerReferences instead (D10), so this is a convenience for other consumers, not a V1 need.
- **OQ16: Should the portal draw Flux Kustomization to ModuleInstance edges from Flux labels?** Status: open. Blocking: deferrable. Flux labels on ModuleInstances were not observed on a live cluster; the capture had no Flux installed.
- **OQ18: How should provider-contract demand be recorded, and for which owners?** Status: open. Blocking: deferrable. Reframed by the capture: `status.requiredContracts` lists every contract the render used (15 for cert-manager, 7 for podinfo), mostly catalog-fulfilled, so it is not demand even for operator-owned instances. Candidates: the operator records per-entry fulfilment, or a separate provider-contract list. Separately, the CLI writes no contracts into the status it owns and ModulePackage status has no such field. Until one exists, D4:R3 holds and the Platform view draws no requires edges.

### Scope of what is shown

- **OQ7: Should a later version show values, and how?** Status: open. Blocking: deferrable. D8 hides them in V1. Options: show them to users who may read Secrets in every namespace the inventory renders a Secret into, or have the kernel expose a secret-aware projection of values that UIs can show. Either needs the module's config schema to find secret leaves.
- **OQ11: Should CLI-owned instances be shown, or hidden?** Status: resolved-by-D3. The capture showed a CLI-owned instance carries an inventory the CLI wrote and `Ready=Unknown/ManagedExternally`, so the portal shows it read-only with health from that inventory (D3:R6).

### Product and distribution

- **OQ10: When does the read API leave `v1alpha1`, and who may depend on it before then?** Status: open. Blocking: acceptance: D2 promises additive changes within a version, and adapters (Headlamp, Backstage, an MCP server) need to know what that promise is worth before they build on it. Candidates: a declared stability point after which a removal needs a new version served beside the old one for at least one minor release.
- **OQ13: Where is the portal published as an OPM module, if it is?** Status: open. Blocking: deferrable. V1 ships binaries, an image and an install manifest. Packaging the portal as an OPM module needs a module path (first-party modules space or the portal's own) and registry coverage.
- **OQ14: Does opm-portal join the release cascade as a consumer of opm-operator, or stay a leaf with manual pin bumps?** Status: open. Blocking: deferrable. It starts as a leaf: the operator Go module pin moves by hand.
- **OQ15: Is a multi-cluster hub a goal, or never?** Status: open. Blocking: deferrable. V1 has no cluster parameter in its paths; a hub would add a parallel route set rather than change the existing one.
- **OQ17:** withdrawn before acceptance: it asked about `orca` in the repo vocabulary, which is outside this entry and already answered in the enhancements README (`orca` is reserved).
