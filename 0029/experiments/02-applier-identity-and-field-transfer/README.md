# 02-applier-identity-and-field-transfer — Gated Ownership Transfer from CLI to Operator

Status: Concluded

## Hypothesis

A SubjectAccessReview of the operator's effective applier identity over every
`status.inventory` entry predicts whether the operator's first reconcile after a
CLI-to-operator flip succeeds. When that identity can apply, the first reconcile
is inventory-stable (0006:D40). The field ownership left behind by `opm-cli` after
the transfer is recorded, along with whether it strands a later field removal.

The claim has three parts:

- **(a)** On a stock install the flip strands the instance, which is why cli PR 196
  removed handoff. A SAR of the effective identity predicts the first reconcile's
  outcome exactly. The effective identity is `spec.serviceAccountName`, else
  `--default-service-account`, else the controller SA.
- **(b)** With a capable identity, the first reconcile gives Ready=True, the same
  entry set, revision+1, nothing pruned, stable UIDs, and changes only the
  managed-by label (`opm-cli` -> `opm-controller`).
- **(c)** Fields the CLI owned become co-owned or move to `opm-controller`. What stays
  with `opm-cli`, and whether that strands a later field removal, is the open part.

## Setup

**Environment (2026-10-04)**

| Item | Value |
| --- | --- |
| kind | v0.32.0, node `kindest/node:v1.34.3`, cluster `opm-handoff-id` (deleted at the end) |
| opm CLI | built from cli `ae60f007` (release 1.0.0-beta.7 tree) with `go build -C cli -o <scratch>/exp-0029-02-opm ./cmd/opm`; it reports version `dev`, so the operator-version ceiling gate is skipped with a warning |
| opm-operator | v1.0.0-beta.5, built from opm-operator `f568db6` with `go build -C opm-operator -o <scratch>/exp-0029-02-manager ./cmd`. This is the same tree as the embedded install image `ghcr.io/open-platform-model/opm-operator:v1.0.0-beta.5` |
| Registry | `opm-registry` (registry:2) at `127.0.0.1:5000`; only `testing.opmodel.dev` is routed to it, `opmodel.dev` resolves from GHCR |

**Deviation: the operator runs outside the cluster, as the controller ServiceAccount.**

Docker containers on this host had no egress on 2026-10-04. `curl https://ghcr.io/v2/` from
the kind node, from `opm-registry`, and from `opm-dev` all timed out. The host
itself reached GHCR. The firewall backend is iptables+firewalld.

The in-cluster operator therefore failed twice. First the image pull timed out. That was
worked around by `docker save --platform linux/amd64 | ctr images import` and a `ctr images tag`
to the pinned `@sha256:cd48…` reference. Then the operator crash-looped in `verifyCoreSchema`,
because it cannot list `opmodel.dev/core@v2` on GHCR. Mirroring `opmodel.dev/*` into the local
registry is forbidden by the workspace Registry Policy, and exposing a host proxy was denied.

`operator-as-sa.sh` therefore does three things:

- scales the in-cluster Deployment to 0;
- mints a token for `opm-operator-system/opm-operator-controller-manager`;
- runs the same beta.5 manager binary on the host against the kind API server, with that token.

Every API call carries the stock install's identity
(`kubectl auth whoami` prints
`system:serviceaccount:opm-operator-system:opm-operator-controller-manager`).
Impersonation (`internal/apply/impersonate.go`) and RBAC are unchanged. Only these differ:

- the process location;
- `--leader-elect=false`;
- the cache and platform dirs;
- `--registry=testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works`;
- the client-go default field manager for the operator's status *Update* (shows as
  `exp-0029-02-manager` instead of `manager`). The SSA field manager on workloads is the
  explicit `opm-controller` constant, so it is unaffected.

**Copied artefacts**

| File here | Copied from | Change |
| --- | --- | --- |
| `module/` (`testing.opmodel.dev/modules/experiments/handoff-id/multi@v0`, published v0.0.1, v0.0.2, v0.0.3) | opm-operator `test/fixtures/modules/podinfo` and `hello` (components, module, identity, `cue.mod`); `res.#Role` usage from `modules/metallb/components.cue` | Re-pathed. Renders a Deployment + Service (`web`), a ConfigMap (`extra`, gated by `#config.extra`), a ServiceAccount, and a cluster-scoped **ClusterRole + ClusterRoleBinding** (`reader-rbac`, grants get/list nodes). `#config.readerName` keeps the cluster-scoped names unique per namespace. v0.0.3 adds `#config.note`, an optional ConfigMap data key. |
| `instance/c1..c4/instance.cue`, `instance-v3/c5,c6` | cli `tests/e2e/testdata/operator-owned/instance.cue` | Registry-imported module (no `local-module.cue`), so no `source: local` annotation. One namespace per case. |
| `opm-config.cue` | cli `hack/opm-config.cue` | registry -> local `testing.opmodel.dev`, context -> `kind-opm-handoff-id` |
| `manifests/platform.yaml` | cli `hack/kind-platform.yaml` | none |
| `flip.sh` | the flip in cli `7ae153f7^:internal/workflow/handoff/handoff.go` + `internal/inventory/store.go` `ApplySpec` | One SSA as `opm-cli` (force) restating the CR labels, `spec.module`, `spec.values` and `owner: operator`. Optional args add `serviceAccountName` / `prune` to the same document. |

**Helpers written for the experiment**

| Script | What it does |
| --- | --- |
| `predict.sh` | The applier-identity gate prototype (see the case 1 notes). |
| `capture.sh` | Records each object's UID, resourceVersion, labels and managers. |
| `objdiff.py`, `fieldowners.py` | Diff object bodies and SSA field ownership. |
| `edit-values.sh` | A thin-editor-style spec edit. |
| `race.sh` | Case 4. |

## Run

Run these from a scratch dir. `S` is the scratch dir and `E` is this directory.

```bash
# 0. cluster, operator, platform, fixture
kind create cluster --name opm-handoff-id --image kindest/node:v1.34.3
(cd $E/module && $S/exp-0029-02-opm module publish . --config $E/opm-config.cue)   # v0.0.2 for c1-c4; v0.0.3 for c5/c6 (bump identity, republish)
$S/exp-0029-02-opm operator install --config $E/opm-config.cue --context kind-opm-handoff-id --timeout 300s
#   (image pull timed out: no container egress; see Setup)
kubectl --context kind-opm-handoff-id -n opm-operator-system scale deploy/opm-operator-controller-manager --replicas=0
kubectl --context kind-opm-handoff-id apply -f $E/manifests/platform.yaml
$E/operator-as-sa.sh $S/exp-0029-02-manager $S/exp-0029-02-op > $S/exp-0029-02-op.log 2>&1 &   # leave running
for c in c1 c2 c3 c4; do $S/exp-0029-02-opm instance apply $E/instance/$c/instance.cue -n $c --create-namespace --config $E/opm-config.cue; done

# 1. stock install, no SA anywhere
$E/predict.sh c1 multi                         # -> PREDICT FAIL (captures/c1-predict.txt)
$E/flip.sh c1 multi                            # strand
$S/exp-0029-02-opm instance apply $E/instance/c1/instance.cue -n c1 --timeout 40s --config $E/opm-config.cue   # recovery attempt 1
#   recovery attempt 2: reverse SSA flip (owner: cli as opm-cli), CLI apply, CLI delete, then strip the finalizer:
kubectl -n c1 get moduleinstance multi -o json | jq '{apiVersion,kind,metadata:{name:.metadata.name,namespace:.metadata.namespace,labels:.metadata.labels},spec:{module:.spec.module,values:.spec.values,owner:"cli"}}' \
  | kubectl apply --server-side --field-manager=opm-cli --force-conflicts -f -
$S/exp-0029-02-opm instance apply $E/instance/c1/instance.cue -n c1 --config $E/opm-config.cue
$S/exp-0029-02-opm instance delete multi -n c1 --force --config $E/opm-config.cue
kubectl -n c1 patch moduleinstance multi --type=merge -p '{"metadata":{"finalizers":null}}'

# 2. namespace-scoped applier; 2b. plus verb-only cluster RBAC (operator restarted to re-trigger the Stalled instance)
kubectl apply -f $E/manifests/c2-applier-namespaced.yaml; $E/predict.sh c2 multi applier; $E/flip.sh c2 multi applier
kubectl apply -f $E/manifests/c2b-applier-rbac-verbs-only.yaml; $E/predict.sh c2 multi; # restart operator-as-sa.sh

# 3. sufficient applier + prune: true; then drop an object
kubectl apply -f $E/manifests/c3-applier.yaml; $E/predict.sh c3 multi applier
$E/capture.sh c3 multi $E/captures/c3-before; $E/flip.sh c3 multi applier true; $E/capture.sh c3 multi $E/captures/c3-after
python3 $E/objdiff.py captures/c3-before-objects-full.yaml captures/c3-after-objects-full.yaml
python3 $E/fieldowners.py captures/c3-after-objects-full.yaml
$E/edit-values.sh c3 multi '.extra = false'    # prune of the formerly CLI-applied ConfigMap
#   3c (c5, module v0.0.3): CLI applies note -> flip -> operator applies note="" -> opm-cli release apply -> operator reconcile
#   3d (c6): flip that also drops extra -> prune of an object still labelled managed-by=opm-cli

# 4. race
kubectl apply -f $E/manifests/c4-applier.yaml; $E/race.sh $S/exp-0029-02-opm

# teardown
pkill -f exp-0029-02-manager; kind delete cluster --name opm-handoff-id
```

All observed output is under `captures/`. `captures/operator-log-excerpt.txt` is the
trimmed operator log.

## Outcome

### Case 1: stock install, no SA anywhere

**Prediction (`captures/c1-predict.txt`).** The effective applier is the controller SA. Every
entry is `get=no create=no patch=no delete=no`, except `get` on the ServiceAccount. That is
**PREDICT FAIL**.

**Flip.** The flip moved the generation from 1 to 2 and the operator added `opmodel.dev/cleanup`.
The reconcile ended with `Ready=False reason=ApplyFailed`:

```text
failed to apply resources: ClusterRole/multi-reader-c1 dry-run failed (Forbidden): ...
User "system:serviceaccount:opm-operator-system:opm-operator-controller-manager" cannot patch resource "clusterroles" ... at the cluster scope
```

What the strand leaves on the CR and the objects:

- `failureCounters` climb (apply 3, drift 3, reconcile 3 after about 30 s), and `nextRetryAt` keeps backing off.
- `status.inventory.revision` stays at 1.
- Every object is byte-identical to before (same UID and resourceVersion, `captures/c1-stranded-objects.txt`).
- With no SA, `markApplyFailure` classifies the error as **transient**: Ready=False/ApplyFailed, not Stalled. The operator retries forever on the bounded backoff.

This is the strand that removed handoff in PR 196.

**Recovery (reverse transfer is out of scope for 0029, so this records what it takes today):**

1. `opm instance apply` does **not** take the instance back. `ResolveOwnership` sees `owner: operator`
   and routes to the thin editor. It rewrites the spec, waits, and exits with
   `the operator did not reconcile the updated spec: Ready: False (ApplyFailed) ... The spec change is written — the operator will retry.`
   No CLI command can write `spec.owner: cli` or `spec.serviceAccountName`.
2. A reverse SSA as `opm-cli` (`owner: cli`) works at once. The operator logs
   `managed externally by the CLI` and Ready becomes Unknown/ManagedExternally.
   A following `opm instance apply` runs in executor mode
   (`applied 6 resources successfully (6 unchanged)`, inventory revision 2).
3. **The finalizer `opmodel.dev/cleanup` stays.** `opm instance delete multi -n c1 --force` deletes all six
   objects and prints `✔ Instance deleted`, exit 0, but the CR stays Terminating with the finalizer.
   `handleCLIOwned` returns early on deletion. Only
   `kubectl patch moduleinstance multi --type=merge -p '{"metadata":{"finalizers":null}}'` releases it.
   So a reverse transfer after a failed adoption needs three things: a raw SSA, a manual finalizer
   strip, and a CLI whose delete does not report success while the CR hangs.
4. The forward alternative is to write a capable `spec.serviceAccountName` with kubectl, as case 3 shows.
   It completes the adoption instead of undoing it. The CLI has no surface for that either.

### Case 2: named SA with a namespace-scoped Role only

**Prediction (`captures/c2-predict.txt`).** All four verbs pass on the Deployment, Service,
ServiceAccount and ConfigMap. They fail on the ClusterRole and the ClusterRoleBinding. That is
**PREDICT FAIL**, for exactly the two cluster-scoped entries.

**Flip with `serviceAccountName: applier`.** The reconcile ended with
`Stalled=True reason=ImpersonationFailed`: `ClusterRole/multi-reader-c2 dry-run failed (Forbidden) ... cannot patch resource "clusterroles"`.
A named SA makes the forbidden error **Stalled**, with a 30-minute recheck.

The prediction matched, with one asymmetry. The operator names only the **first** failing
object, and even the namespaced entries the SA could apply were not touched. Flux
`ApplyAllStaged` applies CRDs, Namespaces and ClusterRoles as stage 1 and aborts the
reconcile there (`captures/c2-stalled-objects.txt` is identical to `c2-before`). A gate
therefore has to report the whole SAR table. The operator's condition will only ever show
the first blocker.

### Case 2b: verb-only cluster RBAC, a refinement the hypothesis missed

`manifests/c2b-…` gives `c2/applier` every verb on clusterroles and clusterrolebindings, but not
the get/list on nodes that the rendered ClusterRole grants.

- A **verb-only** SAR now says yes on every entry.
- The escalation sub-checks in `predict.sh` (`escalate=no`, `bind=no`, `get nodes -> no`) still say **FAIL**.

The operator, restarted to re-trigger the instance, confirmed the stricter prediction:

```text
user "system:serviceaccount:c2:applier" (groups=[...]) is attempting to grant RBAC permissions not currently held:
{APIGroups:[""], Resources:["nodes"], Verbs:["get" "list"]}
```

A gate that SARs only the apply verbs gives a **false GO** for any module that renders
RBAC. RBAC escalation prevention has to be modelled:

- For a Role or ClusterRole: hold `escalate` on it, or hold every rule it grants.
- For a binding: hold `bind` on the referenced role, or every rule of the referenced role.

The SAR also has to carry the impersonation groups (`system:serviceaccounts`,
`system:serviceaccounts:<ns>`, `system:authenticated`), as `predict.sh` does with `--as-group`.

### Case 3: sufficient SA and `prune: true`, judged against 0006:D40 (held)

**Prediction (`captures/c3-predict.txt`).** **PREDICT OK**. The ClusterRoleBinding passes through
"holds the referenced role's rules", not `bind`.

**Flip.** The flip moved the generation from 1 to 2. Within about 2 s the reconcile reached
Ready=True/ReconciliationSucceeded and logged `Applied resources created=0 updated=6 unchanged=0`.

| D40 criterion | Observed |
| --- | --- |
| Ready=True for the flipped generation | yes, observedGeneration 2 |
| identical inventory entry set | yes (`ENTRY SET IDENTICAL`, 6 entries) |
| revision+1 | 1 -> 2 |
| nothing pruned | no Prune log or event, 6/6 objects present |
| no object recreated | UIDs stable for all 6 (`captures/c3-*-objects.txt`) |
| relabel only | `objdiff.py`: the **only** body change on each of the 6 objects is `metadata.labels.app.kubernetes.io/managed-by: "opm-cli" -> "opm-controller"`; the Deployment's pod template did not change (no rollout) |

`status.inventory.digest` changed between the two actors although the entry set is identical:
`sha256:4549…` (CLI) became `sha256:0f38…` (operator). The CLI's `pkg/inventory.InventoryEntry`
has no `omitempty` on `group` and `namespace` (`cli/pkg/inventory/types.go`), while the operator's
`api/v1alpha1.InventoryEntry` does. The JSON the two actors hash therefore differs for core-group or
cluster-scoped entries.

Two consequences:

- A handoff verdict has to compare entry **sets**, as the old `DescribeEntrySetDrift` did, never inventory digests.
- The operator's no-op check can never short-circuit the first reconcile after a flip. The render
  digest differs anyway, because the managed-by value is part of the render. That is what guarantees
  the relabel happens.

`instanceUUID` is identical across actors (deterministic), so the prune guard's uuid match holds.

**Prune of a formerly CLI-applied object.** A spec edit set `values.extra=false`. Reconcile
revision 3 gave `AppliedAndPruned` and `Pruned stale resource kind=ConfigMap name=multi-extra-extra`.
The ConfigMap is gone, and the inventory is 5 entries.

**Variant 3d (`captures/c6-prune-cli-labeled.txt`): the post-handoff prune window.** This flip also
dropped `extra`, deliberately violating D40. The operator pruned a ConfigMap still labelled
`managed-by=opm-cli` with the matching uuid. The guard accepts `opm-cli` objects of the same instance,
as the `prune-stale-resources` spec says.

### Case 3c: field ownership after transfer (managedFields)

**What `opm-cli` still owns (`captures/c3-fieldowners-after.txt`).** After the first operator
reconcile, `opm-cli` keeps its Apply entry on **every** object. Every leaf field (9 to 25 per
object) is **co-owned** by `opm-cli` and `opm-controller`. The managed-by label is the only
exception: its value changed under force, so it moved to `opm-controller` alone.

**Stranding demonstrated (`captures/c5-field-removal.txt`, module v0.0.3):**

1. The CLI applies the ConfigMap with `data.note` set.
2. After the flip (operator revision 2), `data.note` is co-owned.
3. A spec edit sets `note=""`, so the operator's render omits the key. Operator revision 3 reports
   Ready=True and `Applied resources … updated=0 unchanged=6`.
4. **`data.note` is still on the object.** Flux's dry-run keeps it because `opm-cli` still owns it, so
   Flux sees no diff and skips the patch. The `opm-controller` managedFields entry even keeps a stale
   claim on `f:note`.

**Remedy, demonstrated.** After the first operator reconcile, apply an identity-only document as
`opm-cli` (`apiVersion/kind/metadata.name/namespace`). This **releases** every `opm-cli` field
without deleting anything, because all of them are co-owned at that point. The managers list
becomes `["opm-controller"]`. The next operator apply then removes the field: `data` became
`{"message":"after release"}`.

The release must run only after the D40 verdict. Before the operator's first apply, every field is
owned by `opm-cli` alone, and a release would delete it.

### Case 4: race between verification and flip (`captures/c4-race.txt`)

The sequence:

1. The snapshot was taken at generation 1, `message="hello from multi"`.
2. A concurrent `opm instance apply … -f values/c4-race.cue` moved the generation to 2. The
   ConfigMap became `changed concurrently`.
3. The generation re-read (old `ensureUnchangedSinceVerification`) detects `1 -> 2` and would refuse.

Without the guard, the flip from the stale snapshot (generation 3) **silently reverts** the
concurrent apply. The spec went back to `hello from multi`, the operator applied it, and the
ConfigMap went back too. The D40 verdict passed (Ready, revision 3), so nothing reports the loss.
The guard is needed.

A generation re-read still leaves a read-to-write window. Putting the snapshot's
`metadata.resourceVersion` into the SSA flip body makes the write a compare-and-swap. A stale
resourceVersion is rejected with
`Operation cannot be fulfilled … the object has been modified` (`captures/c4-rv-precondition.txt`),
and the current one is accepted.

resourceVersion also moves on status writes, for example the operator's one-time
ManagedExternally write. A refusal should therefore re-read and retry once if only the
resourceVersion moved and the generation did not.

### Case 5: operator-side backstop (sketch only, not implemented)

This sketch reads `opm-operator/internal/reconcile/moduleinstance.go` at `f568db6`.

**Placement.** Immediately after the owner-skip gate (lines 118-126) and **before** finalizer
registration (line ~137):

```go
if mi.Spec.Owner == releasesv1alpha1.OwnerCLI {
    return ctrl.Result{}, handleCLIOwned(ctx, params, &mi)
}
// NEW: adoption refusals (0029). No finalizer, no render, no apply, no prune.
if refusal := adoptionRefusal(&mi, params.Self); refusal != nil {
    if controllerutil.ContainsFinalizer(&mi, FinalizerName) && !mi.DeletionTimestamp.IsZero() {
        // already adopted earlier and now deleting: release WITHOUT pruning (orphan)
        return ctrl.Result{}, removeFinalizer(ctx, params.Client, &mi)
    }
    return ctrl.Result{}, handleAdoptionRefused(ctx, params, &mi, refusal) // like handleCLIOwned
}
```

`adoptionRefusal` returns a reason and message for two cases:

- **`LocalSourceRefused`:**
  `mi.Annotations["module-instance.opmodel.dev/source"] == "local"` (cli `internal/inventory/cr.go`),
  with the message "this instance was rendered from local module bytes the operator cannot fetch;
  publish the module and re-apply with the CLI, or set spec.owner: cli". It is a cheap metadata
  check. The annotation can only block (0006:D38), so stripping it by hand falls through to the
  normal path, and the CLI's digest gate remains the real check.
- **`SelfManagementRefused`:** the instance deploys the operator itself. Detection should not rely
  on the module path alone, because forks and mirrors rename it. The reconciler knows its own
  identity from the downward API (`POD_NAMESPACE`, the Deployment name, and its ServiceAccount).
  The check refuses when any of these holds:
  - `spec.module.path` equals the operator module path (`opmodel.dev/modules/opm_operator@v1`);
  - `status.inventory` contains its own Deployment or ServiceAccount, or the ClusterRoleBinding that grants it;
  - a label stamped by `opm operator install` is present.

  The pre-finalizer check sees only the CLI-written inventory. An instance created directly with
  `owner: operator` has none, so the same predicate must run **again on the rendered set** in
  Phase 4, before `apply.Apply`, as a Stalled refusal.

**Status.** `handleAdoptionRefused` writes the following, without touching inventory,
`lastApplied*` or `instanceUUID`, the same way `handleCLIOwned` does:

- `Ready=False` with the reason;
- `Stalled=True` with the same reason (terminal: nothing on this object can change it except a spec edit);
- one Warning event.

**Why before the finalizer (yes, it must be).** Case 1 shows the cost of a finalizer added to an
instance the operator never manages: the CR wedges in Terminating once ownership goes back to the
CLI. Refusing before the finalizer keeps three things true:

- reverse SSA to `owner: cli` stays clean;
- deletion is never blocked;
- `handleDeletion` (which prunes all of `status.inventory` when `spec.prune`) can never run over a
  CLI-written inventory. For the operator's own instance, that inventory includes the operator's
  own Deployment and RBAC.

### Verdict

**Hypothesis held, with two refinements, one gap and one environmental deviation.**

**Held:**

- (a) Every outcome matched the SAR prediction:
  - c1 FAIL -> strand;
  - c2 FAIL -> Stalled;
  - c3 and c5 OK -> Ready (c4 and c6 used the same grants and also reached Ready).
- (b) The first reconcile met every 0006:D40 criterion (identical set, revision+1, nothing pruned,
  UIDs stable, managed-by relabel only).
- (c) After transfer `opm-cli` co-owns every field, and that **does** strand a later field removal.
  An `opm-cli` release apply after the verdict fixes it.

**Refinements:**

- The SAR must model RBAC escalation (case 2b), or it gives a false GO.
- The verdict must compare entry sets, not inventory digests (case 3).

**Gap:** the generation re-read alone leaves a window. A resourceVersion precondition closes it (case 4).

**Deviation:** the operator ran out of cluster as the controller SA, because containers had no
egress on this host. Identity and RBAC were unaffected.
