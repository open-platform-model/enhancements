# Problem Statement — CUE-Native CRD Schemas as Single Source of Truth

This document answers the question: "Why does this enhancement need to exist?"
Lead with observable facts. Reference existing code paths and definitions so
readers can verify the claims. Do not propose solutions here — that belongs
in `02-design.md`.

## Current State

OPM's Kubernetes custom resources are defined in two places, in two languages, with no machine link between them.

The canonical contract lives in `core/` as pure CUE. `core/src/module_instance.cue` defines `#ModuleInstance` (kind, metadata with deterministic UUID derivation, `#module` reference, `values`); `core/src/platform.cue` defines `#Platform` (metadata, `type`, `#registry` of `#Subscription`) and `#Subscription` / `#SubscriptionFilter`. These already carry Kubernetes-shaped metadata (name, namespace, labels, annotations) and `core/SPEC.md` already mandates that every `spec` surface be OpenAPIv3-compatible — no CUE templating (`for`/`if`) inside it — precisely so non-CUE consumers (Kubernetes CRDs, UIs, generated bindings) can read the schema.

The operator's API lives independently in `opm-operator/api/v1alpha1/` as hand-authored Go structs: `moduleinstance_types.go`, `modulepackage_types.go`, `platform_types.go`, `common_types.go`. From these, controller-gen (`sigs.k8s.io/controller-tools` v0.20.1) generates the CRD YAML in `config/crd/bases/*.yaml` and the deepcopy methods in `zz_generated.deepcopy.go`, driven by kubebuilder markers (`+kubebuilder:validation:MinLength`, `+kubebuilder:validation:Enum`, `+kubebuilder:subresource:status`, `+kubebuilder:printcolumn`, `+kubebuilder:resource:scope=…,shortName=…`, and one CEL rule `+kubebuilder:validation:XValidation` enforcing the `Platform` singleton name `cluster`). Three kinds ship in group `opmodel.dev/v1alpha1`: `ModuleInstance` (namespaced), `ModulePackage` (namespaced), `Platform` (cluster singleton).

Nothing connects the two. The Go `ModuleInstanceSpec.Module.Path` field and the CUE `#ModuleInstance` shape are kept aligned by a human reading both. There is no generator, no import, no test that fails when they diverge.

## Gap / Pain

The two definitions drift, and the drift is silent. A field added to `#ModuleInstance` in `core/` does not appear in the Go type or the CRD until someone hand-edits `opm-operator/api/v1alpha1/`. A validation tightened in CUE (a new pattern, an enum value) is not reflected in the CRD's `openAPIV3Schema`, so the API server accepts inputs the CUE contract rejects — the resource validates at admission but fails when the kernel evaluates it, turning a clean admission-time rejection into a confusing reconcile-time error.

Enhancement [0006](../0006/) raised the stakes. It made the operator's `ModuleInstance` CR a shared contract that the CLI imports and writes directly (its status subset, its `spec.owner` marker, its inventory). The hand-authored Go type is now a multi-consumer contract spanning `opm-operator/` and `cli/`. When it drifts from `core/`, the inconsistency is felt in two repos at once, and the "canonical" CUE schema is no longer the thing the running system actually enforces — the Go type is. That inverts the workspace's own stated invariant (`/CLAUDE.md`: `core/` is "the source of truth every downstream consumes").

The maintenance cost is a standing tax: every CRD-shaped change is authored twice, reviewed twice, and trusted to stay consistent by discipline alone.

## Concrete Example

Suppose `ModuleInstance` gains a `spec.values` constraint in `core/` — say `values` must be a struct (not a list or scalar), expressed in `core/src/module_instance.cue`. The author updates the CUE, `cue vet` passes, the change publishes as `opmodel.dev/core@v0.x`.

The operator's CRD is unaffected: `opm-operator/config/crd/bases/opmodel.dev_moduleinstances.yaml` still describes `values` as it did, because that YAML is generated from `ModuleInstanceSpec` in Go, where `Values` is `*RawValues` (an `apiextensionsv1.JSON` passthrough). A user applies a `ModuleInstance` with `values: [1, 2, 3]`. The API server admits it — the CRD schema says "arbitrary JSON." The operator picks it up, the kernel loads the published `core`, unification fails because `values` must be a struct, and the reconcile surfaces a CUE evaluation error deep in the render path instead of a crisp "spec.values must be an object" at `kubectl apply` time.

The fix today is to remember to hand-edit the Go type and re-run controller-gen — a step with no enforcement. The same hazard runs the other way: a kubebuilder marker added in Go (a new printer column, a tightened enum) has no representation in `core/`, so the canonical contract under-describes what the cluster enforces.

## User Stories

- As a **core schema author**, I want a change to `#ModuleInstance` to propagate to the operator's CRD and Go types automatically, so that the contract I publish is the contract the cluster enforces. Today: I edit CUE, then separately hand-edit Go in another repo and hope reviewers catch any mismatch.
- As an **operator/CLI contributor**, I want one definition of the API types to build against, so that a `core` schema change can't leave `opm-operator` and `cli` compiling against a stale shape. Today: the Go types are authored independently of `core`, and 0006 means a drift bites both repos.
- As a **platform operator applying resources**, I want invalid specs rejected at `kubectl apply` with a clear message, so that I don't debug a reconcile-time CUE error for something the schema should have caught. Today: the CRD's validation and the CUE contract are maintained separately and disagree.

## Why Existing Workarounds Fail

The current workaround is **discipline plus duplication**: author the shape in CUE, re-author it in Go, regenerate the CRD, and rely on review to keep them aligned. It fails on three counts. (1) It is unenforced — nothing breaks when the two diverge, so divergence is discovered in production, not in CI. (2) It is cross-repo — the CUE lives in `core/`, the Go in `opm-operator/`, the consumer in `cli/`; no single PR sees the whole contract, so review cannot reliably catch drift. (3) It scales badly — every CRD-shaped field is now three artefacts (CUE, Go, generated CRD YAML) maintained by hand, and 0006 added a fourth consumer (`cli`) that trusts the Go shape. The "canonical" CUE schema is canonical in name only; the artefact the running cluster enforces is the hand-authored Go type, which is exactly backwards from the workspace's source-of-truth model.

The inverse workaround — making Go the source of truth and deriving CUE from it (via `cue get go` or `cue get crd`) — is technically supported and is examined as an alternative in `05-risks.md`, but it formalises the inversion rather than fixing it: it would make `core/` a *derived* artefact of `opm-operator/`, contradicting `core/`'s role as the published contract upstream of every consumer.
