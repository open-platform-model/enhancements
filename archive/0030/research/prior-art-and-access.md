# Prior art and access model: OPM Portal V1

Gathered 2026-10-04 by a research swarm for the portal design: nineteen reports, of which the three areas below carry claims this entry relies on. Each report read primary sources (cloned repositories, project docs, the GitHub API, the OPM repos) unless marked otherwise. This file is a snapshot; it is superseded by a new file, never edited in place.

Verified facts are stated plainly. Recommendations are marked **Recommendation** and are the researchers', not decisions; the decision log says which were adopted.

## Portals and dashboards (external)

- **Standalone Kubernetes package and dashboard UIs have a poor survival record.** Kubeapps was archived on 2025-08-25 (an SAP fork exists), the Kubernetes Dashboard on 2026-01-21 in favour of Headlamp, and Glasskube on 2026-06-17.
- **Kratix deprecated its Backstage-specific controller** in favour of a portal-agnostic Portal Controller, so adapters for Backstage, Headlamp or Port stay thin over one neutral read model.
- **Read-only cluster dashboards that draw a graph from status** (kro-ui, the Crossplane web UI, Headlamp plugins, the Radius dashboard) are the proven shape for a first release.
- **Two architectural camps.** Backend proxy with impersonation or token passthrough and Kubernetes RBAC as the boundary (Headlamp, Go and React; the Flux Operator web UI, Go and Preact, AGPL-3.0), versus controller-centric UIs with their own authorization and cache (Argo CD: Casbin, Redis).
- **The Flux Operator UI is the closest match.** It builds its graph from `status.sourceRef` and `status.inventory` and draws fixed columns in about 100 lines of client code, with no layout library. Its code is AGPL-3.0 and is not reused; only the pattern is.
- **Headlamp plugins run only in the browser.** The docs and backend code show no server-side plugin hook, and Headlamp shows raw Kubernetes objects. This is absence of evidence, not a verified limit.
- **Not verified:** the Flux UI's live transport (SSE, WebSocket or polling) and its multi-cluster support; Argo CD's streaming and impersonation behaviour was stated from background knowledge.
- **Recommendation:** define a portal-neutral read model as a documented API so Backstage, Headlamp and MCP adapters stay thin; build the API first and a thin UI on top, because the API is the durable contract.

## Access and identity

- **CVE-2026-23990** (Flux Operator web UI, affected 0.36.0 up to but not including 0.40.0, fixed in 0.40.0, CVSS 5.3, published 2026-01-21): an embedded UI that impersonates users and ends up with empty claims runs requests as the operator's own ServiceAccount.
- **opm-operator's manager role already holds cluster-wide impersonate** on users, groups and ServiceAccounts with no `resourceNames`, and write on ModuleInstances. A UI inside the manager process would inherit that blast radius.
- **The shipped viewer role covers ModuleInstances only** (get, list, watch, and get on status). None of the operator's twelve roles carries an aggregate-to-view, edit or admin label. Platforms, ModulePackages and TransformerRegistrations are unreadable to non-admins.
- **The operator has no redaction code.** Redaction of marked secret paths in diagnostics is a kernel contract (entry 0013), not an operator feature; whether the embedded library applies it to condition and event messages was not verified.
- **No Kubernetes floor is declared.** The operator README carries a boilerplate "v1.11.3+", envtest follows k8s.io/api v0.36, the CLI's kind image is v1.34.3, and the opm quickstart was tested on v1.36.1. ConstrainedImpersonation (KEP-5284) is alpha in 1.35, beta in 1.36 and planned stable in 1.38.
- **Recommendation:** run the portal as a separate Deployment with its own narrow ServiceAccount; use SubjectAccessReview-as-user, then read with the portal's ServiceAccount, which needs no impersonate grant; fail closed on empty identity with a regression test mirroring the CVE's empty-claims case; ship an unbound platform viewer role from the operator.

## Operator surface (OPM, read from source)

- Four CRDs in `opmodel.dev/v1alpha1` (ModuleInstance, ModulePackage, Platform, TransformerRegistration), all with a status subresource and Flux-style conditions; events through the events.k8s.io/v1 recorder.
- Owned objects are findable by inventory entries (group, kind, namespace, name, version, component) and by labels, but there are no ownerReferences, so the instance graph must come from the inventory.
- `Ready=True` means applied: the apply path does not wait on workload health.
- The CRDs carry no module display metadata (name, description, icon, config schema) and the inventory carries no per-object hash or health.
- **Recommendation:** compute per-object health in the portal backend with kstatus; raise a `Healthy` condition or per-entry health as a separate operator question.

The live capture in [experiment 01](../experiments/01-live-cluster-capture/) later checked these claims on a running cluster and corrected several; where they disagree, the experiment wins.
