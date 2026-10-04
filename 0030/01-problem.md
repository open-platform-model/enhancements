# Problem Statement: OPM Portal V1

OPM has no way to see, in one place, what it runs in a cluster. Everything a person can learn today comes from `kubectl` against four custom resources, read one at a time, plus the CLI's own tree and status commands for the instances the CLI applied. Nobody can look at a cluster and answer "what does this Platform offer, what runs on it, and is it working?" without already knowing how the operator writes its status.

## Current State

The opm-operator writes everything a viewer would need into the Kubernetes API, spread over four kinds in group `opmodel.dev/v1alpha1`:

- **Platform** (cluster-scoped singleton `cluster`): the catalogs it subscribes to, the resolved registry, and conditions such as `ContractsFulfilled`.
- **ModuleInstance**: one deployed module. Its status carries conditions (`Ready`, `Reconciling`, `Stalled`), an inventory of every object the render applied (group, kind, namespace, name, component), the contracts the render used, a short history of reconcile attempts, digests of the last apply, and failure counters.
- **ModulePackage**: a pre-rendered module delivered from a Flux source, with a similar status.
- **TransformerRegistration** (cluster-scoped): a provider's claim to implement contracts, with acceptance and activation verdicts as conditions.

Rendered objects carry the labels `module-instance.opmodel.dev/name` and `.../uuid`, but no ownerReference back to their instance, so the instance-to-object relation exists only in the inventory. Events are recorded through events.k8s.io/v1 by the controller `opm-controller`.

The CLI shows one instance at a time from a terminal. The operator ships one viewer role, for ModuleInstances only. No OPM repo designs or ships a web UI; the only UI-adjacent statement in the workspace is core's rule that a module's config schema must stay expressible in OpenAPI so that "web UIs rendering forms" can read it.

## Gap / Pain

**Nothing shows the whole picture.** The Platform, its catalogs, the providers that registered, the instances that run and the objects each one owns are four lists and a join the reader does in their head. The relation that matters most, instance to its objects, is not even visible to generic Kubernetes UIs, because the operator sets no ownerReferences.

**The obvious status is misleading.** `Ready=True` on a ModuleInstance means the render applied, not that the workload runs. On a live cluster, an instance whose new Pod could not pull its image stayed `Ready=True` for the whole ten-minute progress deadline, and the Deployment stayed `Available=True` with it (measured, [experiment 01](experiments/01-live-cluster-capture/)). A UI that shows the operator's Ready as a green light lies for ten minutes.

**Generic dashboards do not know OPM.** Headlamp, the Kubernetes Dashboard or Argo CD's tree draw ownerReferences and label selectors. They cannot draw module to component to object, cannot tell a refused registration from a pending one, and cannot read the inventory.

**Access is all or nothing.** The operator's only viewer role covers ModuleInstances. A non-admin cannot read the Platform, ModulePackages or TransformerRegistrations at all, and no role aggregates into the built-in `view` role.

## Concrete Example

A platform team installs cert-manager as a ModuleInstance from `opmodel.dev/modules/cert_manager@v2`. On a default operator install it fails: the operator's ServiceAccount cannot patch CRDs. Here is what each audience sees today.

```
kubectl get moduleinstances -A
NAMESPACE      NAME           READY   ...
cert-manager   cert-manager   False

kubectl get moduleinstance cert-manager -n cert-manager -o yaml
  ... 14.6 KB: 42 inventory entries (once it applies), 15 required contracts,
  five history entries all repeating the same Forbidden message,
  failureCounters {apply: 4, drift: 4, reconcile: 4}
```

The team fixes the ServiceAccount and the instance goes Ready. A developer then breaks podinfo's image tag in another namespace:

```
podinfo ModuleInstance      Ready=True   ReconciliationSucceeded    (stays True)
podinfo Deployment          Available=True                          (for ~600 s)
podinfo-...-cc5ql Pod       0/1 ImagePullBackOff                    (from the first second)
```

To learn that podinfo is broken, the developer must know to skip the instance, skip the Deployment, and list Pods. To learn which cluster objects cert-manager owns, they must read the inventory by hand, because no object points back. The drift counter on the healthy cert-manager climbs anyway, because the operator's drift check runs under the wrong identity (opm-operator issue 209), so the one number that looks like health is not.

## User Stories

- As a **platform team operator**, I want to see the Platform's catalogs, the providers that registered and whether each registration was accepted, so that I can tell what this cluster offers. Today: three kinds, read separately, with verdicts encoded in condition reasons.
- As an **application developer**, I want to open my instance and see its components, their objects and their Pods with honest health and recent events, so that I find a broken rollout in seconds. Today: `Ready=True` hides the break and the instance-to-object relation is only in the inventory.
- As a **tool author** (Headlamp plugin, Backstage adapter, an MCP server), I want a stable, documented read API over OPM state, so that I can build on it without re-deriving the joins. Today: the only interface is raw custom-resource status, which is `v1alpha1` and portal-unaware.

## Why Existing Workarounds Fail

- **`kubectl` and the CLI** show one object at a time and cannot join instance, inventory, Pods and events into one view.
- **A generic Kubernetes UI** follows ownerReferences, which OPM does not set, and does not understand registration verdicts or the applied-versus-healthy split.
- **Reading the raw status** puts the operator's internal shape in front of every consumer. That shape is `v1alpha1`, may still change, and keeps gaining conditions and reasons; every consumer would re-derive the same joins and break on the same changes.
- **Granting cluster-admin to see everything** works and is the wrong answer: a portal for many teams has to show each person what their own RBAC allows.
