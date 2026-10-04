# 02-cli-bootstrap-install — The Operator Ships as an OPM Module

Status: Concluded

## Hypothesis

On a fresh cluster with no operator, "install = SSA the module's CRD subset,
then `opm instance apply` a CLI-owned ModuleInstance of the operator module
pulled from a registry" yields a working operator. A reinstall is idempotent.
An upgrade is a re-apply with a new module version. Uninstall
(`opm instance delete`) keeps the CRDs and the Namespace and keeps today's
finalizer guard. The operator never touches its own CLI-owned instance.

## Setup

Versions (2026-10-04):

| Input | Version |
| --- | --- |
| opm CLI | built from cli `main` at `ae60f007` (release 1.0.0-beta.7): `go build -C cli -o <scratch>/exp-0028-02-opm ./cmd/opm`. It reports `dev`, CUE SDK v0.17.1 |
| Operator image | `ghcr.io/open-platform-model/opm-operator:v1.0.0-beta.5@sha256:cd48321b…` (the module default, the same as the cli's embedded install.yaml) |
| Module deps | core v2.0.0-beta.2, catalogs/opm v4.5.2, cue.dev/x/k8s.io v0.12.0 |
| Cluster | kind v0.32.0, `kindest/node:v1.36.1`, cluster `opm-dogfood`, created and deleted by this experiment |

Copied in, never referenced:

| Copy | Source | Change |
| --- | --- | --- |
| `module/` | `../01-operator-module-render/module/` at `d3883e0` (the idiomatic catalog path, not the exact-objects variant) | Module path rewritten to `testing.opmodel.dev/modules/experiments/opm-operator-bootstrap/opm_operator@v0`. 0.1.0 was published unchanged. 0.2.0 (the current tree) bumps `identity.Version`, raises the default memory request from 256Mi to 320Mi, and adds the pod annotation `experiments.opmodel.dev/module-version: "0.2.0"`. |
| `fixture/platform.yaml` | `cli/hack/kind-platform.yaml` | Catalog pin 4.4.4 bumped to 4.5.2 to match the module pins. |
| `fixture/dev-applier-rbac.yaml` | `cli/hack/kind-operator-rbac.yaml` | Verbatim. |
| `fixture/hello.yaml` | `opm-operator/test/fixtures/modules/hello/moduleinstance.yaml` (`f568db6`) | Uses v0.0.11, the newest in the local registry. `owner: operator`, `prune: true`. No per-instance applier SA, because the dev grant covers configmaps. |

Other files:

- `instance/` is `opm instance init opm-operator testing.opmodel.dev/modules/experiments/opm-operator-bootstrap/opm_operator --version 0.1.0 -n opm-operator-system`. Its `values.cue` sets `registry` (the operator's `--registry`).
- `instance-0.2.0/` is the same package with the dep pinned to v0.2.0.
- `hack/install.sh` emulates the proposed module-based `opm operator install`:
  1. `opm instance build` the instance.
  2. Pick out the 4 CRDs with `yq`.
  3. `kubectl apply --server-side --field-manager=opm-cli`, then wait for `Established`.
  4. `opm instance apply <instance.cue> --wait`.
  5. Print the timings.
- `hack/old-install.sh` runs today's `opm operator install` (the embedded install.yaml plus the Platform seed). It applies the environment fix below.
- `hack/snapshot.sh` prints each inventory object's kind, name, uid, resourceVersion, generation and field managers, plus the CR.
- `hack/relabel-old.sh` is the migration-probe helper.
- `hack/kind.sh` and `hack/mirrors.sh` set up the environment.

**Environment deviation (not part of the design under test).** On this host, kind nodes and pods have no internet egress: `curl https://ghcr.io/v2/` returns 000 from every kind node, including opm-dev, while host-network containers reach it. Two consequences:
- The operator image never pulled (`dial tcp 4.225.11.196:443: i/o timeout`).
- The operator hung after `Resolved CUE registry` while fetching core and catalog, and its probes then failed.

`hack/mirrors.sh` runs two host-network `registry:2` pull-through caches: `:5055` for ghcr.io and `:5056` for registry.cue.works. `hack/kind.sh` points the node's containerd at `http://172.18.0.1:5055` (the kind gateway) for ghcr.io. The operator gets `--registry=testing.opmodel.dev=opm-registry:5000+insecure,opmodel.dev=172.18.0.1:5055/open-platform-model+insecure,172.18.0.1:5056+insecure` through `#config.registry`.

This doubles as a small proof of the owner's "air-gapped users point --registry at a mirror" path: a plain pull-through mirror served the operator's CUE module fetches unchanged.

`kind load docker-image` failed for multi-arch images (`ctr: content digest … not found`), so the image could not be pre-loaded. For the old install the stock Deployment has no `--registry`, so `old-install.sh` appends one with `kubectl patch --field-manager=exp-env-fix` as soon as the Deployment exists.

## Run

```bash
cd 0028/experiments/02-cli-bootstrap-install
S=/var/home/emil/.cache/claude-tmp/claude-1000/-var-home-emil-dev-open-platform-model/04e7f2a4-4c96-4d07-ab32-440633d5661f/scratchpad
go build -C /var/home/emil/dev/open-platform-model/cli -o $S/exp-0028-02-opm ./cmd/opm
source hack/env.sh          # OPM, CTX=kind-opm-dogfood, OPM_REGISTRY/CUE_REGISTRY, $K

# Publish 0.1.0 (git show cd4cca7:…/module) and 0.2.0 (current tree)
(cd module && $OPM module publish .)
curl -s 127.0.0.1:5000/v2/testing.opmodel.dev/modules/experiments/opm-operator-bootstrap/opm_operator/tags/list
# {"…":"…","tags":["v0.1.0","v0.2.0"]}

hack/mirrors.sh             # this host only
hack/kind.sh                # fresh opm-dogfood with the containerd mirror

# 1-2. Install
hack/install.sh             # instance/ (0.1.0)
$K -n opm-operator-system get mi opm-operator -o yaml --show-managed-fields   # out/step2-mi.yaml

# 3. Platform seed (a plain create with field manager opm-cli, as cli/internal/platform/cluster.go:96 does), dev grant, fixture
$K create --field-manager=opm-cli -f fixture/platform.yaml
$K apply --server-side --field-manager=exp-dev -f fixture/dev-applier-rbac.yaml
$K apply --server-side --field-manager=exp-fixture -f fixture/hello.yaml
$K wait --for=condition=Ready mi/hello -n default

# 4. Reinstall
hack/snapshot.sh > out/step4-before.tsv; hack/install.sh; hack/snapshot.sh > out/step4-after.tsv
diff <(cut -f1-6 out/step4-before.tsv) <(cut -f1-6 out/step4-after.tsv)

# 5. Upgrade
hack/install.sh "$PWD/instance-0.2.0"
$K patch mi hello -n default --type merge -p '{"spec":{"values":{"message":"after operator upgrade to 0.2.0"}}}'

# 7. Delete the operator's own instance while hello is armed, then recover
$OPM instance delete opm-operator -n opm-operator-system --context $CTX --dry-run
$OPM instance delete opm-operator -n opm-operator-system --context $CTX --force
$OPM instance delete hello -n default --context $CTX --force            # refused, exit 2
$K delete mi hello -n default --wait=false                               # wedges on opmodel.dev/cleanup
hack/install.sh "$PWD/instance-0.2.0"                                    # operator returns, finishes hello's cleanup

# 6. Migration from today's install (fresh cluster)
hack/kind.sh && hack/old-install.sh
hack/install.sh "$PWD/instance-0.2.0"     # refused: existence check
hack/relabel-old.sh                       # emulate "adopt": managed-by=opm-cli on all 19 old objects
hack/install.sh "$PWD/instance-0.2.0"     # 18 applied, Deployment selector immutable, no inventory
$K -n opm-operator-system delete deploy opm-operator-controller-manager --wait
hack/install.sh "$PWD/instance-0.2.0"     # completes; 3 old bindings left un-inventoried

# Timing samples, fresh cluster each
for i in 1 2; do hack/kind.sh; hack/old-install.sh; hack/kind.sh; hack/install.sh "$PWD/instance-0.2.0"; done

# 8. Self-handoff probe (fresh cluster with install + step 3 seeding)
$K -n opm-operator-system patch mi opm-operator --type merge --field-manager=exp-flip \
  -p '{"spec":{"owner":"operator","prune":true}}'                                  # 8a
$K create clusterrolebinding exp-0028-02-operator-cluster-admin --clusterrole=cluster-admin \
  --serviceaccount=opm-operator-system:opm-operator-controller-manager              # 8b
$OPM instance apply instance-0.2.0/instance.cue --context $CTX                      # 8b: thin edit, no reclaim
timeout 150 $OPM instance delete opm-operator -n opm-operator-system --context $CTX --force   # 8c: wedges
$OPM instance apply instance-0.2.0/instance.cue --context $CTX --timeout 1m         # 8c: cannot recover
$K -n opm-operator-system patch mi opm-operator --type json -p '[{"op":"remove","path":"/metadata/finalizers"}]'
$OPM instance apply instance-0.2.0/instance.cue --context $CTX --wait               # recovers

# Teardown
kind delete cluster --name opm-dogfood
docker rm -f exp-0028-02-ghcr-mirror exp-0028-02-cueworks-mirror
```

Logs and snapshots for each step are in `out/`. `out/render.yaml` and `out/crds.yaml` hold the last render.

## Outcome

### 1. Bootstrap install works

The sequence is: SSA the CRD subset, then apply the CLI-owned instance.
- With no Platform CR, the render used the instance's own deps: `WARN cluster Platform not used (no Platform CR in the cluster) — rendering against the instance's own deps`.
- `opm instance apply` applied the Namespace first and then the 18 other objects: `applied 19 resources successfully (15 created, 4 unchanged)`. The CRDs were unchanged because the CRD step had just applied them.
- The ModuleInstance CR lands in the Namespace the same apply creates. No separate namespace step is needed.

**Ordering trap.** `opm instance apply --create-namespace` creates the namespace without OPM labels. The module then renders that same Namespace, and the pre-apply existence check refuses: `resource Namespace/opm-operator-system … already exists and is not managed by OPM`. A module-based install must not pass `--create-namespace` when the module owns its namespace.

### 2. The operator leaves its own CLI-owned instance alone

`out/step2-mi.yaml`:
- `spec.owner: cli`.
- No finalizers and no annotations.
- The only write by the operator (manager `manager`) is the `Update` on the status subresource for `Ready=Unknown`, reason `ManagedExternally`, `observedGeneration: 2`. The log reads `ModuleInstance is managed externally by the CLI, skipping reconciliation`.
- Every other field is owned by `opm-cli`.

`status.inventory` lists all 19 objects, including the 4 CRDs and the Namespace.

### 3. End to end

After the Platform seed (catalog 4.5.2) and the dev grant:
- Platform `cluster` reached Ready (reason Generated, operator v1.0.0-beta.5).
- The operator-owned `hello` fixture reached Ready, and ConfigMap `hello-hello-hello` was created.

### 4. Reinstall is idempotent

- All 19 objects kept their uid and resourceVersion (`out/step4-*.tsv`). The CLI reported `19 unchanged`.
- Only the CR's resourceVersion moved: `status.lastAppliedAt` changed, generation stayed 2, and `lastAppliedRenderDigest` stayed `sha256:d96f19fb…`.
- The second render went through the now-seeded cluster Platform, not the instance deps, and produced the same digest. This holds only because the Platform subscribes to the same catalog (4.5.2) as the module pins.
- The operator's own install render is coupled to the cluster Platform. A Platform on another catalog version would re-render the operator install.

### 5. Upgrade 0.1.0 to 0.2.0 is a re-apply

- `15 configured, 4 unchanged`: every non-CRD object changed because its `module.opmodel.dev/version` label changed. The CRDs had already been relabelled by the CRD step.
- One new ReplicaSet rolled out, and the new pod template carries the 320Mi request and the annotation.
- `hack/install.sh` timing: apply plus `--wait` took 13.9 s.
- `managedFields`: `opm-cli` (Apply) on everything, `kube-apiserver` on the CRDs, `kube-controller-manager` on the Deployment status.

**Gap: `--wait` returns before the operator serves.** The new pod started at 10:06:37, but its log shows its controllers only started at 10:07:05: 28 s with no reconciler. The leader lease handover is the likely cause; this run did not confirm it.
- The first `hello` reconcile then reported `PlatformNotReady`, because the in-memory Platform store was empty.
- The Platform regenerated at 10:07:07, and `hello` was Ready at 10:07:11.
- `opm instance apply --wait` reported "Instance healthy" about 30 s before the operator was reconciling anything.

### 6. Migration from today's `opm operator install` refuses, and forcing it leaves orphans

On a fresh cluster with the old install (field manager `opm-cli`, kustomize labels), the apply goes through three stages.

**First apply.** `pre-apply existence check failed: resource Namespace/opm-operator-system … is not managed by OPM`. It neither adopts nor duplicates.
- The check stops at the first object without an OPM `managed-by` value (`cli/internal/inventory/stale.go:87-92`).
- It is skipped entirely once a previous inventory exists (`internal/workflow/apply/apply.go` `RunPreApplyExistenceCheck`).
- The emulated CRD step had already SSA'd and relabelled the four CRDs before the refusal. A real install must run the existence check before the CRD step, or accept that the CRD step mutates first.

**After `hack/relabel-old.sh` (an emulated adopt).** `applied 18 resources … 3 created, 11 configured` and `Deployment … spec.selector … field is immutable`. Then `apply had errors — skipping pruning and inventory write`, so no ModuleInstance CR is written.
- The old operator kept running throughout.
- The 3 "created" are the module's binding names (`opm-operator-manager-role`, `…-metrics-auth-role`, `…-leader-election-role`), which now exist next to the old `*-rolebinding` objects.

**After deleting the Deployment.** `applied 19 resources successfully (1 created, 18 unchanged)` and healthy. Total time 16.3 s, including the delete.
- Every other object was adopted in place with the same uid (`out/step6-after-migrate.jsonl`).
- Because both installs use field manager `opm-cli`, the kustomize labels the old SSA owned were dropped cleanly.
- **Left un-inventoried** (`out/step6-uninventoried.txt`): `ClusterRoleBinding/opm-operator-manager-rolebinding`, `ClusterRoleBinding/opm-operator-metrics-auth-rolebinding`, `RoleBinding/opm-operator-leader-election-rolebinding`. They are functional duplicates that nothing will ever prune.

### 7. Delete has no finalizer guard; CRDs and the Namespace survive

- `opm instance delete opm-operator` (dry run and real) deleted 14 objects and listed the Namespace and 4 CRDs as `left behind reason="CRDs and Namespaces are never deleted"`.
- It never mentioned that `hello` still carried `opmodel.dev/cleanup`. **Today's `opm operator uninstall` guard (`CheckFinalizerGuard`, `cli/internal/operator/uninstall.go:64-84`, refusing with `--remove-finalizers` as the override) has no equivalent on this path.**
- Afterwards `hello` kept a stale `Ready=True` and its finalizer.
- The per-instance guard on the other side does work. `opm instance delete hello` exits 2 with: `the opm operator is not ready (Deployment/opm-operator-controller-manager in opm-operator-system) — instance "hello" is operator-managed, and deleting its ModuleInstance now would wedge it …; install or repair it with 'opm operator install', then retry`.
  - That guard is `CheckReady` (`cli/internal/operator/ready.go:41-57`), and it locates the operator from the **embedded install.yaml**: the CRD names plus the fixed Deployment name and namespace.
  - Dropping install.yaml removes its locator.
  - A module instance named anything other than `opm-operator` in `opm-operator-system` (the module derives `<instance>-controller-manager`) would never be found.
- `kubectl delete mi hello --wait=false` wedged in Terminating as predicted.
- Re-running `hack/install.sh` brought the operator back (`14 created, 5 unchanged`). It ran `Deletion cleanup pruned resources … Finalizer removed` and `hello` was gone 18 s after the install returned.
- Re-running the bootstrap CLI is the working escape hatch while the instance is CLI-owned.

### 8. Self-handoff (flipping the operator's own instance to `owner: operator`)

**8a. Shipped RBAC plus the dev grant: fails closed, but arms the finalizer.**
- `Ready=False ApplyFailed: CustomResourceDefinition/moduleinstances.opmodel.dev dry-run failed (Forbidden): … cannot patch resource "customresourcedefinitions"`.
- The dry-run runs before any apply, so nothing changed: the Deployment stayed at generation 1 with the same uid.
- The operator did add `opmodel.dev/cleanup` to its own instance.

**8b. With cluster-admin on the operator SA** (the applier rights self-management needs: CRDs, ClusterRoles, bind and escalate):
- `ReconciliationSucceeded` about 40 s later.
- All 19 objects were re-applied in place: same uids, new resourceVersions. The Deployment stayed at generation 1, so there was no self-restart, because the render matched.
- `opm-controller` became a co-owner of every object, and `app.kubernetes.io/managed-by` flipped to `opm-controller`.
- **Re-running the CLI does not take the instance back.**
  - `opm instance apply` said `instance is operator-managed — editing its spec and waiting for the operator` and left `owner: operator`.
  - The emulated CRD step (kubectl SSA without force) now conflicts: `conflict with "opm-controller": .metadata.labels.app.kubernetes.io/managed-by`.

**8c. Delete the self-owned instance (prune: true): it wedges.**
- `opm instance delete` waited on the operator's cleanup until `timeout 150` killed it (rc 124).
- The operator pruned its own Deployment, ServiceAccount, metrics Service and `opm-operator-manager-role` ClusterRole, then died mid-cleanup.
- The CR is stuck: `deletionTimestamp` 10:17:49Z, finalizer `opmodel.dev/cleanup`, `owner: operator`.
- Left in place: the leader-election Role and RoleBinding, 5 ClusterRoles, and two ClusterRoleBindings that now point at a deleted ClusterRole or a deleted SA.
- `hello` was orphaned again with an armed finalizer.

**Recovery from 8c.**
- `opm instance apply` cannot recover: `timed out waiting for the operator to reconcile generation 3`, because it only edits the spec of an operator-owned CR.
- The only way back was manual: `kubectl patch … remove /metadata/finalizers`, then `opm instance apply`. That gave `4 created, 15 configured`, healthy, `owner: cli`, `ManagedExternally` again.
- The CLI's apply took `managed-by` back. `opm-controller` stays a field manager on the CRDs and ClusterRoles (`out/step8c-after-recover.jsonl`), as stale co-ownership.

In short:
- A self-owned operator instance cannot be reclaimed by re-running the bootstrap CLI.
- Deleting it destroys the operator before its own finalizer clears.
- Without broad rights it only arms a finalizer and fails.

This is direct evidence for the owner's "CLI-owned forever" decision and for a refusal gate, both CLI-side and operator-side.

### Install time (fresh cluster each, image via the mirror)

| Run | Today's `opm operator install` (with Platform seed) | Module install (`hack/install.sh`, no Platform seed) |
| --- | --- | --- |
| 1 | 12.8 s (outlier, first run after the mirror was warmed) | 31.8 s (render+CRDs 3.5 s, apply+wait 28.2 s) |
| 2 | 28.7 s | 28.6 s (render+CRDs 2.5 s, apply+wait 26.1 s) |
| 3 | 30.7 s | 30.2 s (render+CRDs 2.3 s, apply+wait 27.9 s) |

The module path costs about 2.5 s of render with a warm CUE cache and is otherwise the same. Readiness, mostly the image pull and the probe delays, dominates both.

**Hypothesis partly held.**
- **Held:**
  - Install from a registry-pulled module yields a working operator, and it reconciled a fixture end to end.
  - The reinstall changed no object.
  - The upgrade is a re-apply.
  - Delete keeps the CRDs and the Namespace.
  - The operator writes only the `ManagedExternally` condition on its own CLI-owned instance.
- **Refuted:**
  - Delete does **not** keep the finalizer guard.
  - Migrating from today's install refuses, and when forced it needs a Deployment recreate and orphans three bindings.
  - `--wait` does not prove the operator is serving.
  - `--create-namespace` conflicts with a module-owned Namespace.

### Design implications for 0028 / 0029

- `opm operator uninstall` (or a module-based `opm operator delete`) must keep `CheckFinalizerGuard` before deleting the operator's own instance. Plain `opm instance delete` of the operator instance needs the same guard, or must refuse that instance and name the operator command.
- `CheckReady` and every "is the operator there" probe (the delete guard, handoff gate 1) need a locator that does not read install.yaml. Options: find the CLI-owned ModuleInstance whose `spec.module.path` is the operator module, or label the Deployment.
- Install readiness should wait for Platform `Ready` at the current generation and for the operator's lease, not just Deployment health. Today's `task cluster:operator wait-ready` already does the Platform part.
- Migration from install.yaml has to be explicit:
  - adopt (relabel) the 19 objects or skip the existence check for exactly them,
  - delete the Deployment when the selector changes,
  - delete the three `*-rolebinding` objects.

  The alternative is the exact-objects module shape from experiment 01, which keeps the selector and the binding names and avoids all three.
- The CRD-subset step must run after the existence check and force conflicts the way the CLI's apply does.
- Never pass `--create-namespace` for a module that renders its own Namespace.
- The operator's install render goes through the cluster Platform once one exists. The entry should state whether the operator module renders against the Platform or always against its own pins (`--platform`-style), so a Platform catalog bump cannot silently re-render the operator.
- 0029, refusal gates:
  - The CLI handoff must refuse the operator's own instance.
  - The operator must refuse to adopt an instance whose module is the operator module (or whose inventory contains its own Deployment or ServiceAccount). Otherwise `kubectl patch spec.owner=operator` arms a finalizer (8a) or yields an unreclaimable, self-destroying instance (8b, 8c).
  - The CLI has no path to take an instance back from the operator. 0029 should say whether one exists (reverse handoff) or whether the only exit is a manual finalizer strip.
- The air-gapped mirror story works with a plain pull-through cache for the operator's `--registry`. The image needs its own containerd mirror.

The cluster `opm-dogfood` and both mirror containers were deleted at the end; `kind get clusters` shows only `opm-dev`, which was never touched. This experiment is linked from `02-design.md` and `03-decisions.md` and has a row in `experiments/README.md` (linked after it concluded, 2026-10-04).
