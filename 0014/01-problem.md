# Problem Statement — Export a Deployed Instance as GitOps Manifests

This document answers the question: "Why does this enhancement need to exist?" It leads with observable facts and references existing code paths so the claims can be verified. Solutions belong in `02-design.md`.

## Current State

Enhancement [0006](../0006/) built the path a learner takes into OPM. The CLI applies an instance from a local `.cue` file, storing its inventory in the operator's `ModuleInstance` custom resource (D1) rather than in a Secret. `opm instance handoff` then transfers management of that instance to the operator: a gate chain, a single-field ownership flip, and a bounded wait judged by D40's inventory-stable criterion. It shipped and is live-verified — the transfer costs zero workload disruption.

The CLI's write to that CR is deliberately narrow. `ApplySpec` in `cli/internal/inventory/store.go:119` is the single writer for the CLI-owned spec, and the document it applies contains exactly four things: `spec.module` (path plus version), `spec.owner`, `spec.values`, and three metadata labels from `crLabels` (`store.go:311`), plus the render-provenance annotation when the render came from local bytes. Under server-side apply a manager's document is its complete declared intent, so that list is not a summary — it is the whole of what the CLI puts in the CR's spec.

The operator's `ModuleInstanceSpec` (`opm-operator/api/v1alpha1/moduleinstance_types.go:43`) declares four more fields the CLI never writes: `serviceAccountName`, `prune`, `suspend`, and `rollout`.

The GitOps form of the same instance exists today only as hand-written YAML. `opm-kind-demo/jellyfin/moduleinstance.yaml` is the reference example: a `Namespace`, a `ServiceAccount` named `opm-applier`, a `ClusterRoleBinding` granting it `cluster-admin`, and a `ModuleInstance` carrying `spec.module`, `spec.serviceAccountName`, `spec.prune: true`, and an inline `spec.values` block. A sibling `kustomization.yaml` lists the file, and one repo-level `OCIRepository` plus one Flux `Kustomization` under `opm-kind-demo/bootstrap/flux/` pull the whole bundle. Every byte of that per-app directory was typed by a human.

The CLI's instance surface is `apply`, `build`, `delete`, `diff`, `events`, `handoff`, `list`, `status`, `tree`, `vet` (`cli/internal/cmd/instance/`). None of them writes a committable document. `opm instance build` renders an instance file to the *workload* manifests — the StatefulSet, Service, PVC that OPM produces — which is the opposite direction from what a GitOps repo holds: a GitOps repo holds the `ModuleInstance` that asks the operator to produce those workloads, not the workloads themselves.

## Gap / Pain

**Handoff moves the manager. It does not move the definition.** After a successful handoff the operator owns the instance, and the only complete description of that instance is a live object in etcd. GitOps needs a file. Nothing in OPM produces one.

Reaching for `kubectl get moduleinstance jellyfin -n jellyfin -o yaml` and deleting the parts that look cluster-side does not close the gap, for three reasons that are each verifiable today:

1. **The output carries state that must not be committed.** `status` (including the entire `status.inventory` entry list, the digest set, and the operator's conditions), `metadata.managedFields`, `resourceVersion`, `uid`, `generation`, `creationTimestamp`. Committing `status` to git means Flux will try to apply it; committing `managedFields` means committing the record of which field manager owns what, which is exactly what the next apply recomputes.

2. **The output is incomplete in ways that change behaviour, not just aesthetics.** A CLI-applied, handed-off instance has no `spec.serviceAccountName` and no `spec.prune`, because `ApplySpec` never writes them. `Record.Prune` in `cli/internal/inventory/record.go` documents the consequence in the code itself: the field has no CRD default, so it is false unless someone set it, and the operator then deliberately orphans the workloads on deletion. The missing service account is the same shape of problem: with `spec.serviceAccountName` empty the operator falls back to `--default-service-account` and then to the controller's own identity (`opm-operator/cmd/main.go:101`; `internal/reconcile/default_sa_test.go:103`). So the "just export the CR" document is one that silently applies as the controller and silently orphans on delete — while the hand-written demo document, in the same repo, does neither. Two files that look alike, describing materially different behaviour.

3. **The CR is not the unit that can be applied.** `spec.serviceAccountName: opm-applier` is a reference to a `ServiceAccount` in the instance's namespace, and that account needs a role binding wide enough to apply everything the module renders. The namespace, the account, and the binding are not part of the CR and do not exist as files anywhere. A GitOps repo containing only the CR either fails to reconcile or quietly runs with the controller's identity.

On top of all three: **nothing verifies the result.** The hand-assembled document is checked by applying it and watching what happens to a running workload. Handoff refused that standard for the ownership flip — it renders the published module, compares the digest against `status.lastAppliedRenderDigest`, and aborts before touching the CR when they disagree (`cli/internal/workflow/handoff/verify.go`). The conversion to GitOps changes who applies the instance from then on, and today it has a weaker safety story than the flip that preceded it.

## Concrete Example

An operator of a home cluster installs the CLI and deploys five modules from local instance files — Jellyfin, Seerr, a Garage node, K8up, and a small web app. Each `opm instance apply` writes a `ModuleInstance` CR with `spec.owner: cli` and applies the rendered workloads directly. Everything runs.

Two weeks in, they decide they want reconciliation and drift correction, so they run `opm operator install` and then `opm instance handoff` five times. Each handoff verifies the published module reproduces the deployed state, flips `spec.owner` to `operator`, and reports an inventory-stable reconcile: the operator adopted the resources, relabelled `app.kubernetes.io/managed-by`, and changed no workload. The cluster is now operator-managed. This is the path 0006 built, and it works.

Then they decide they want git to be the source of truth, and the path stops.

The five CRs in the cluster are the only record of what is deployed. To move them into a repo, the operator must, for each instance: dump the CR, delete `status` and the six metadata fields that must not be committed, notice that `prune` is absent and decide whether to add it, notice that `serviceAccountName` is absent and decide whether to add it, write a `Namespace` (the namespace already exists in the cluster and is not represented anywhere as YAML), write a `ServiceAccount`, write a `ClusterRoleBinding` and pick what to bind it to, write a `kustomization.yaml`, and hand-copy the `spec.values` block — which for Jellyfin alone is a nested twenty-line structure covering ports, storage classes, mount paths, and resource limits.

Nothing in that sequence is checked. If they mistype a storage class in the values block, the first thing that tells them is Flux applying the CR, the operator re-rendering the module against the mistyped value, and a PVC being replaced under a running StatefulSet. The original `jellyfin_instance.cue` on their laptop is not a safety net either: it is a different artifact (a CUE `#ModuleInstance`, not a `ModuleInstance` CR), it may have drifted from what is deployed if any apply used `-f` overrides, and re-authoring from it means trusting a file they last touched two weeks ago over the CR the handoff gate just verified.

## User Stories

- As a home-cluster operator who adopted OPM through the CLI, I want to move my running instances into a git repository so that the cluster is reconciled from source. Today: I hand-assemble four YAML documents per instance from a `kubectl get -o yaml` dump, with no check that what I wrote describes what is running.
- As a platform engineer evaluating OPM, I want the CLI-first path and the GitOps path to be the same path with one conversion step between them, so that a proof-of-concept is not thrown away when it graduates. Today: the conversion is manual transcription, so the proof-of-concept is effectively re-authored.
- As an application module author, I want to hand a colleague the exact manifests that reproduce my running instance so that they can review it in a pull request. Today: I can hand them a CR dump that is missing the fields governing apply identity and deletion behaviour, and they have no way to tell.

## Why Existing Workarounds Fail

**`kubectl get -o yaml` plus manual pruning.** Fails on all three counts above: it commits state that must not be committed, it produces a document whose absent fields change apply identity and deletion behaviour, and it produces one object where four are required. It is also unverified — the transcription is trusted, not checked.

**Re-authoring from the original instance file.** Substitutes a laptop artifact for the cluster's own record. It is the wrong source: the CR is what handoff verified and what the operator is reconciling, and the instance file may have drifted from it. It is also the wrong shape — turning a CUE `#ModuleInstance` into a `ModuleInstance` CR by hand is the same transcription problem in a different direction.

**Copying the demo directory.** `opm-kind-demo/jellyfin/` is a correct and complete example, and copying it is genuinely the fastest manual route. It also copies a `ClusterRoleBinding` to `cluster-admin` that the demo's own comment flags as a demo shortcut, and it still leaves the values block to hand-transcribe.

**Keeping the CLI as the applier and skipping GitOps.** Available, and legitimate for a single-operator cluster. It is not a workaround for the stated problem: the operator asked for reconciliation from git, which is precisely what the CLI does not provide.
