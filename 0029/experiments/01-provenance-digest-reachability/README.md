# 01-provenance-digest-reachability — Gated Ownership Transfer from CLI to Operator

Status: Concluded

## Hypothesis

The removed handoff's gates (the provenance annotation, a strict-registry re-render with an isolated CUE cache, and the digest self-comparison) catch (i) a local-path instance and (ii) a registry module that no longer reproduces the deployed render. They miss (iii) a coordinate the CLI can pull and the operator cannot (a registry mapping mismatch) and (iv) a local render that carries no `source: local` annotation. And today, when a `source: local` instance is flipped to `owner: operator` with `kubectl`, the operator either fails resolution or silently applies different registry bytes of the same coordinate.

## Setup

Run on 2026-10-04 with these versions:

- opm CLI: a copy of `cli` at `ae60f007` (release 1.0.0-beta.7), built with library v1.0.0-beta.3 and CUE v0.17.1.
- Operator image: `ghcr.io/open-platform-model/opm-operator:v1.0.0-beta.5`.
- Cluster: kind v0.32.0 with node `kindest/node:v1.34.3`. Platform `cluster` subscribes `opmodel.dev/catalogs/opm@v4` at 4.4.4, and modules depend on `opmodel.dev/core@v2` at v2.0.0-beta.1.
- Registry: the local `opm-registry` container. The host sees it as `127.0.0.1:5000` and the cluster sees it as `opm-registry:5000`.

What the experiment directory holds:

| Path | What it is |
| --- | --- |
| `module/` | A copy of `opm-operator/test/fixtures/modules/hello` (one ConfigMap). It is renamed to `testing.opmodel.dev/modules/experiments/handoff-src/hello@v0` at version 0.1.0. |
| `module-local/` | The same module with an extra `data.origin: "local-bytes"`. It keeps the coordinate 0.1.0 and is never published. |
| `module-unpub/` | The `module-local` bytes at version 0.9.0, which is never published. |
| `module-republish/` | The 0.1.0 coordinate with `origin: "republished-0.1.0"`. It is pushed over the original 0.1.0 tag with `cue mod publish`, because `opm module publish` refuses to overwrite a tag. |
| `module-v030/`, `module-mirror/` | 0.3.0, and 0.1.0 with `origin: "cli-only-mirror"`. Both are published only under the repository prefix `cli-only/`, which the operator's mapping never reads. |
| `instances/registry`, `reg-rb`, `reg-vc` | `opm instance init` packages that pin hello 0.1.0 from the registry. |
| `instances/local-replace` | The registry package plus `cue.mod/local-module.cue`, which redirects `hello@v0` to `../../module-local`. |
| `instances/cli-only-030`, `cli-only-010` | Packages initialized with `opm/config-cli-only.cue`. |
| `instances/inline-unannotated` | The module copied as a plain package inside the instance package's own CUE module. Its metadata still claims the published coordinate, and the package has no `local-module.cue`. |
| `opm/config.cue` | The CLI mapping `testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works` and context `kind-opm-handoff-src`. |
| `opm/config-cli-only.cue` | The same mapping, except that `testing.opmodel.dev` maps to `127.0.0.1:5000/cli-only+insecure`. |
| `verify-tool/` | The removed gate chain rebuilt as a read-only command. `build.sh` copies `cli` at `ae60f007` (via `git archive`) into a scratch directory and adds two files. One is `render.ExpVerificationDigest`, a port of `cli 7ae153f7^:internal/workflow/handoff/verify.go` to today's internals: it acquires `spec.module` strictly from the registry, replays `spec.values` and renders against the cluster Platform. The other is the hidden command `opm instance exp-verify NAME [--fresh-cache] [--runtime-name]`. That command prints gates 2, 3, 3b, 4 and 5, and the digest is `inventory.ComputeRenderDigest`, unchanged. `--runtime-name` requires the copy to turn the `RuntimeName` const into a var. The cli tree itself is never edited. |
| `flip.sh` | `ssa` replays the removed flip (`inventory.ApplySpec` with `Owner=operator` and `SourceLocal=false`): a forced server-side apply as field manager `opm-cli` that restates `spec.module`, `spec.values` and the CR labels and sends no annotations. `edit` is the `kubectl edit` bypass: a merge patch of `spec.owner` only, after which the annotation survives. |
| `observe.sh` | Prints the CR's owner, annotations, conditions, digests, inventory and events, plus the data of the applied ConfigMap. |

Environment workarounds, all specific to this host and none part of the claim:

- Containers on this host had no egress. The kind node, and even `docker run --network kind curlimages/curl`, timed out connecting to `ghcr.io:443`, while the host reached it. I worked around it in three steps:
  1. I pulled the operator image on the host, loaded it into the node with `docker save … | ctr -n k8s.io images import -`, and set the Deployment image to the tag only with `imagePullPolicy: IfNotPresent`. `kind load` failed on the multi-platform index.
  2. I seeded the operator's CUE cache with core and the catalog: a hostPath `/var/opm-cue-seed` is mounted at the operator's `--cue-cache-dir` (`/tmp/cue-cache`). The seed holds a host CUE cache filled by one `opm instance build`, with `testing.opmodel.dev` removed, so the operator fetches every experiment module from `opm-registry:5000` itself.
  3. Mirroring `opmodel.dev/*` into the local registry was not an option: the workspace Registry Policy requires the user's explicit ask.
- The persistent operator cache is also what case (ii) uses to show the operator's own stale-cache behaviour.

## Run

All commands run from this directory. `S` is a scratch directory and `C="--context kind-opm-handoff-src"`.

```bash
# 0. cluster, operator, tool
kind create cluster --name opm-handoff-src --config <cli>/hack/kind-config.yaml \
  --image kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48
go build -C <cli> -o $S/opm ./cmd/opm
$S/opm operator install --config opm/config.cue --context kind-opm-handoff-src --timeout 180s
#    (egress workaround: docker pull + docker save | docker exec -i <node> ctr -n k8s.io images import -;
#     docker cp <seed CUE cache without testing.opmodel.dev> <node>:/var/opm-cue-seed; chmod -R a+rwX)
kubectl $C -n opm-operator-system patch deploy opm-operator-controller-manager --type=json -p '[
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--registry=testing.opmodel.dev=opm-registry:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"},
 {"op":"add","path":"/spec/template/spec/volumes/-","value":{"name":"cue-seed","hostPath":{"path":"/var/opm-cue-seed","type":"Directory"}}},
 {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts/-","value":{"name":"cue-seed","mountPath":"/tmp/cue-cache"}},
 {"op":"replace","path":"/spec/template/spec/containers/0/image","value":"ghcr.io/open-platform-model/opm-operator:v1.0.0-beta.5"},
 {"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
kubectl $C apply -f <cli>/hack/kind-platform.yaml -f <cli>/hack/kind-operator-rbac.yaml
verify-tool/build.sh $S/vt            # -> $S/vt/opmx (cli ae60f007 + exp-verify)
X="$S/vt/opmx --config opm/config.cue"; export CUE_CACHE_DIR=$S/cache
$X module publish module              # hello 0.1.0 (original bytes)

# control: registry instance, gates, legitimate flip
$X instance apply instances/registry/instance.cue          # hello-reg
$X instance exp-verify hello-reg -n default --fresh-cache  # all PASS
./flip.sh ssa hello-reg; sleep 12; ./observe.sh hello-reg

# (i) local path
$X instance apply instances/local-replace/instance.cue     # hello-lr (replaceWith)
$X module apply module-local --name hello-ma               # same coordinate 0.1.0
$X module apply module-unpub --name hello-mu               # unpublished 0.9.0
for n in hello-lr hello-ma hello-mu; do $X instance exp-verify $n -n default --fresh-cache; done
./flip.sh ssa hello-lr; ./flip.sh edit hello-ma; ./flip.sh edit hello-mu; sleep 15
for n in hello-lr hello-ma hello-mu; do ./observe.sh $n; done
kubectl $C -n default get cm hello-ma-hello-hello -o json --show-managed-fields | jq '.metadata.managedFields'

# (ii) same coordinate, different bytes / changed values
$X instance apply instances/reg-rb/instance.cue; $X instance apply instances/reg-vc/instance.cue
(cd module-republish && CUE_REGISTRY='testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works' \
   cue mod publish v0.1.0)                                    # overwrites the tag
kubectl $C -n default patch moduleinstance hello-vc --type=merge -p '{"spec":{"values":{"message":"edited by kubectl"}}}'
for n in hello-rb hello-vc; do $X instance exp-verify $n -n default --fresh-cache; $X instance exp-verify $n -n default; done
./flip.sh ssa hello-rb; sleep 12; ./observe.sh hello-rb                 # operator cache still has old bytes
docker exec opm-handoff-src-control-plane sh -c 'chmod -R u+w /var/opm-cue-seed/mod; rm -rf /var/opm-cue-seed/mod/*/testing.opmodel.dev'
kubectl $C -n opm-operator-system rollout restart deploy/opm-operator-controller-manager; sleep 60
for n in hello-reg hello-rb hello-lr hello-ma; do kubectl $C -n default get cm $n-hello-hello -o jsonpath='{.data}'; done

# (iii) registry mapping mismatch
Y="$S/vt/opmx --config opm/config-cli-only.cue"; export CUE_CACHE_DIR=$S/cache-clionly
$Y module publish module-v030; $Y module publish module-mirror
$Y instance apply instances/cli-only-030/instance.cue; $Y instance apply instances/cli-only-010/instance.cue
for n in hello-x3 hello-xm; do $Y instance exp-verify $n -n default --fresh-cache; done
./flip.sh ssa hello-x3; ./flip.sh ssa hello-xm; sleep 15; ./observe.sh hello-x3; ./observe.sh hello-xm
# predicting the operator's digest (operator mapping vs CLI mapping)
for n in hello-reg hello-rb hello-xm; do $X instance exp-verify $n -n default --fresh-cache --runtime-name opm-controller; done
$Y instance exp-verify hello-xm -n default --fresh-cache --runtime-name opm-controller

# (iv) unannotated local render
export CUE_CACHE_DIR=$S/cache
$X instance apply instances/inline-unannotated/instance.cue          # hello-iv
$X instance exp-verify hello-iv -n default --fresh-cache
./flip.sh edit hello-iv; sleep 12; ./observe.sh hello-iv

# cold verification time (opm/cache removed + fresh CUE cache, x3), then warm
rm -rf opm/cache; /usr/bin/time -f wall=%es $X instance exp-verify hello-reg -n default --fresh-cache

# teardown
kind delete cluster --name opm-handoff-src
```

## Outcome

### Gate verdicts per case

The `exp-verify` output is excerpted below. "Digest" in this table is the `--fresh-cache` verification render compared with the CR's `status.lastAppliedRenderDigest`.

| Case | Instance | Annotation (gate 3) | Gate 4 resolve | Gate 5 digest | Old chain |
| --- | --- | --- | --- | --- | --- |
| control | hello-reg (registry 0.1.0) | absent, PASS | PASS (2.89 s) | `e7775a25…` = `e7775a25…`, PASS | flip |
| (i) | hello-lr (`local-module.cue` replaceWith) | `local`, REFUSE | PASS | `e5357…` ≠ `06013…`, REFUSE | refuse |
| (i) | hello-ma (`opm module apply <dir>`, same coordinate) | `local`, REFUSE | PASS | `0bd6b…` ≠ `bce5d…`, REFUSE | refuse |
| (i) | hello-mu (`module apply`, unpublished 0.9.0) | `local`, REFUSE | FAIL: `module …@v0.9.0: module not found` | (not reached) | refuse |
| (ii) | hello-rb (0.1.0 republished with other bytes) | absent, PASS | PASS | fresh: `2b84f…` ≠ `52be9…`, REFUSE. **Warm cache: `52be9…` = `52be9…`, PASS (wrong)** | refuse, but only with the isolated cache |
| (ii) | hello-vc (`spec.values` edited by kubectl) | absent, PASS | PASS | fresh and warm both ≠, REFUSE | refuse |
| (iii) | hello-x3 (0.3.0 only on the CLI's mapping) | absent, PASS | PASS (CLI mapping) | `e3a21…` = `e3a21…`, PASS | **flip** |
| (iii) | hello-xm (0.1.0 differs between the two mappings) | absent, PASS | PASS (CLI mapping) | `ce696…` = `ce696…`, PASS | **flip** |
| (iv) | hello-iv (inline module copy, no `local-module.cue`) | **absent, PASS** | PASS | `126af…` ≠ `f9d3e…`, REFUSE | refuse (digest is the only backstop) |

### What the operator did after a flip

- **Control.** The operator returned `Ready=True ReconciliationSucceeded` and the event `Applied 1 resources (0 created, 1 updated, 0 unchanged)`. The inventory set was unchanged and the revision moved from 1 to 2, and `managed-by` became `opm-controller`.
- **(i) hello-lr (`ssa` flip, which drops the annotation) and hello-ma (`edit` flip, which keeps `module-instance.opmodel.dev/source: local`).** Both reached `Ready=True ReconciliationSucceeded` with `ModuleResolved`. The operator read no annotation and emitted no warning. It rendered the registry's 0.1.0 bytes, but the live ConfigMap stayed `{"message":…,"origin":"local-bytes"}`. The managed fields show why: `opm-cli` still owns `f:data.f:origin` and `opm-controller` owns only `f:data.f:message`. The operator's server-side apply does not remove a field another manager owns, so the object becomes a hybrid of the registry intent and leftover local fields. The removed D40 verdict checked "entry set unchanged, revision incremented", and it would have reported **success** here.
- **(i) hello-mu.** The status was `Ready=False ResolutionFailed: … hello@v0.9.0: module not found`, with repeated Warning events. The CLI-written ConfigMap was left as it was (still `managed-by: opm-cli`), and the instance is stranded under `owner: operator`.
- **(ii) hello-rb, flipped while the operator's cache was warm.** The operator applied the *old* cached 0.1.0 bytes. After the operator's module cache was evicted and the pod restarted, **every** operator-owned 0.1.0 instance re-rendered the republished bytes: hello-reg, hello-rb, hello-lr and hello-ma all show `origin: "republished-0.1.0"`. They stayed `Ready=True` and moved to revision 3, with no generation change and no event other than `Applied`. Between the restart and the Platform regenerating there was a window with `Warning PlatformNotReady: platform not ready: no generated platform module`.
- **(iii) hello-x3.** The status was `Ready=False ResolutionFailed … hello@v0.3.0: module not found`, and the instance is stranded.
- **(iii) hello-xm.** `Ready=True` and `Applied`, but the live data went from `origin: "cli-only-mirror"` to `origin: "republished-0.1.0"`. That is a silent swap of bytes that every CLI gate had approved.
- **(iv) hello-iv (`edit` flip).** `Ready=True`, and the data went from `origin: "inline-unannotated"` to the registry bytes.

The operator's effective registry mapping is observable in only two places: the Deployment's `--registry` argument (or the `OPM_REGISTRY` env or the compiled-in default) and a startup log line, `Resolved CUE registry {"registry": "...", "source": "flag"}`. No CR reports it. Platform `status` carries `registry[]` catalog entries but not the mapping. The mapping also names in-cluster hosts (`opm-registry:5000`) that the CLI usually cannot resolve, so reading the mapping does not let the CLI test reachability.

### The CLI can predict the operator's digest

The operator's `lastAppliedRenderDigest` differs from the CLI's only because of the runtime name, which shows up as the `app.kubernetes.io/managed-by` label. With `--runtime-name opm-controller`, the verification render reproduces the operator's digest byte for byte:

| Instance | Operator's digest | CLI prediction, operator mapping | CLI prediction, CLI mapping |
| --- | --- | --- | --- |
| hello-reg | `e966f517…` | `e966f517…` (equal) | |
| hello-rb | `323685e3…` | `323685e3…` (equal) | |
| hello-xm | `f976443f…` | `f976443f…` (equal) | `96648941…` (different) |

So the cross-actor digest is comparable whenever the CLI renders with the operator's runtime name.

### Cold verification time

The cold time was measured with a fresh `CUE_CACHE_DIR` and the platform cache removed. The verification render took 2.93 s, 2.97 s and 2.96 s (wall time 2.95 to 2.99 s). Keeping the platform cache saved nothing measurable (2.90 to 2.98 s). With both caches warm it took 0.34 to 0.36 s, but the warm run returned the **stale** digest `e7775a25…` where the fresh run returned `3dc6fda1…`. A fresh cache downloads about 2.9 MB (core and catalog) from GHCR for this one-ConfigMap module.

### Surprises

1. The source digest identifies the coordinate, not the content. `lastAppliedSourceDigest` is `sha256(path + "@" + version)` (`cli/internal/workflow/apply/apply.go:501`), and it is `55a64f9c…` for registry, local and republished bytes alike. The operator records the same value. Nothing on the CR names the bytes that were rendered.
2. The old cleanup leaks. `isolateCUECache`'s `os.RemoveAll` cannot delete a CUE cache, because the extract tree is read-only. A plain `rm -rf` failed with `Permission denied` until `chmod -R u+w`. The old handoff would have leaked about 3 MB into `$TMPDIR` on every run and logged it only at debug level.
3. The CUE cache is registry-blind on both sides. It is keyed by `module@version`, so a CLI that switches mappings, or an operator whose pod outlives a republish, serves whichever bytes it cached first.
4. `opm module publish` refuses to overwrite a tag ("A published tag names fixed bytes permanently"), but `cue mod publish` against the same registry overwrote it without complaint. The mutable-tag scenario is real for any registry that does not enforce immutability.

### Verdict

**Hypothesis held.** In detail:

- The old chain refused (i) twice over, through both the annotation and the digest.
- It refused (ii) only with the isolated cache; a warm cache passes a republished coordinate.
- It passed both (iii) variants. One strands the instance with `ResolutionFailed`, and the other is a silent swap of bytes that the old D40 verdict scores as success.
- (iv) carries no annotation, so the digest gate was its only backstop.
- After a `kubectl` flip, the operator never reads `source: local`. It either fails resolution (an unpublished version) or reports Ready while applying registry bytes, merged with leftover `opm-cli`-owned fields.

The experiment also found three problems the hypothesis did not name:

- **A time-of-check gap.** Even after a correct verification, the operator re-renders whatever the tag serves at its next cache miss.
- **Field-ownership residue.** After a flip, `opm-cli` keeps owning workload fields, and the operator never prunes them.
- **A way to compare across actors.** A CLI render with runtime name `opm-controller` predicts the operator's digest exactly.
