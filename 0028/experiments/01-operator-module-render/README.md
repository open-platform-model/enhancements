# 01-operator-module-render — The Operator Ships as an OPM Module

Status: Concluded

> **Note (2026-10-04):** a later owner decision chose the catalog path this experiment measured, with the seccomp profile and roles with no subjects added to the catalog first (0028:D2, 0028:D12), over the exact-objects variant; the outcome below is unchanged.

## Hypothesis

The opm-operator's full install (the 19 objects in the cli's embedded
`install.yaml`, operator v1.0.0-beta.5) can be authored as an OPM module
against the current `opmodel.dev/core@v2` and `opmodel.dev/catalogs/opm@v4`.
The current opm CLI renders that module, without a cluster, to the same
object set: same names, namespaces and kinds, with semantically equal specs.
The CRDs and the controller-gen RBAC are generated from YAML with `cue import`.

## Setup

Versions, all as of 2026-10-04:

| Input | Version |
| --- | --- |
| opm CLI | built from cli `main` at `ae60f007` (release 1.0.0-beta.7): `go build -C cli -o <scratch>/exp-0028-01-opm ./cmd/opm`. It reports `dev`, CUE SDK v0.17.1 |
| cue | v0.17.1 |
| Module deps (after `cue mod tidy`) | `opmodel.dev/catalogs/opm@v4` v4.5.2, `opmodel.dev/core@v2` v2.0.0-beta.2, `cue.dev/x/k8s.io@v0` v0.12.0, all resolved from GHCR and registry.cue.works |
| Operator sources | opm-operator at `f568db6` (tag v1.0.0-beta.5) |

Copied into this directory, never referenced:

| Copy | Source |
| --- | --- |
| `source/crd/*.yaml` (4 files, 57,732 bytes) | `opm-operator/config/crd/bases/*.yaml` |
| `source/rbac/role.yaml` (controller-gen output) and 5 unbound-role scaffolds | `opm-operator/config/rbac/{role,metrics_reader_role,moduleinstance_{admin,editor,viewer}_role,transformerregistration_admin_role}.yaml` |
| `source/install.yaml` (the comparison baseline) | `cli/internal/operator/dist/install.yaml` (`PinnedOperatorVersion = v1.0.0-beta.5`) |

Layout:

- `module/` holds the OPM module and is the only thing published. The path is `testing.opmodel.dev/modules/experiments/opm-operator-render/opm_operator@v0`, version 0.1.0.
  - `module.cue` holds the metadata, `#config` and `debugValues: {}`.
  - `components.cue` holds the components.
  - `zz_generated_crds.cue` and `zz_generated_rbac.cue` are written by `hack/generate.sh`. Do not edit them.
- `hack/generate.sh` runs `cue import -l '#crdSource:' -l metadata.name` over the concatenated CRDs, and `-l '#rbacSource:' -l metadata.name` over the six ClusterRole files. Each result is a definition keyed by object name. Override the inputs with `SRC=<operator>/config CRD_SUBDIR=crd/bases`.
- `hack/drift-check.sh` regenerates into a temp dir and diffs the result against `module/zz_generated_*.cue`, ignoring the 4-line header.
- `hack/compare.py` keys each object by kind/namespace/name, normalizes it to sorted JSON and prints every leaf difference. Spec and labels/annotations are reported separately.
- `hack/run.sh` runs the whole experiment. `hack/variant.sh` runs the exact-objects variant (see Outcome).
- `values/knobs.cue` sets every `#config` field.
- `variants/exact_objects.cue` is the variant. It is not part of the published module.

How each object is authored:

| Object(s) | Path | Why |
| --- | --- | --- |
| Namespace `<instance ns>` | `resources/v1alpha1 #Namespaces`, named from `#ctx.instance.namespace` | Fits. The Namespace is the instance namespace, so there is a single source for it. |
| 4 CRDs | `resources/v1beta1 #CRDs`, embedding each imported `spec` whole, plus the controller-gen annotation | Fits. Embedding the whole spec, not picking fields (metallb picks fields), makes an uncarriable field refuse at render (see Outcome). |
| Deployment, ServiceAccount, metrics Service | One component, `controller-manager`, built from `blueprints/v1beta1 #StatelessWorkload`, `#ServiceAccount`, `#Volumes`, traits `SecurityContext`, `WorkloadIdentity`, `GracefulShutdown`, `PodMetadata` and `Expose` | Fits, with the two gaps below. The name derives as `<instance>-controller-manager` with no override. The Service name is set explicitly through `expose.name`. |
| `manager-role` + binding | `resources/v1beta1 #Role` (cluster), rules taken from `#rbacSource["manager-role"]` (controller-gen) | Fits, but `#Role` names the binding after the role. |
| `metrics-auth-role` + binding, `leader-election` Role + RoleBinding | `#Role` (cluster / namespace), rules hand-written | As above. |
| 5 unbound ClusterRoles (`metrics-reader`, `moduleinstance-{admin,editor,viewer}-role`, `transformerregistration-admin-role`) | `resources/v1alpha1 #Objects`, named `<instance>-<source name>`, rules taken from `#rbacSource` | `#RoleSchema.subjects` requires at least one subject, so `#Role` cannot express an unbound role. |

`#config` has these fields:
- `image` (repository, tag, digest, pullPolicy)
- `registry?` (sets `--registry`)
- `defaultServiceAccount?` (sets `--default-service-account`)
- `extraArgs`
- `replicas`
- `goMemLimit`
- `resources`

The defaults reproduce install.yaml, including the beta.5 image digest.

Workarounds in the authoring, each also recorded as a finding:
- `#ctx: _` is re-declared in `module.cue`, because a field of the embedded `m.#Module` is not in lexical scope from `components.cue`. The error otherwise is `reference "#ctx" not found`.
- `restartPolicy` and `updateStrategy` are set explicitly, because the blueprint requires them.
- `readOnly: false` is set on the `emptyDir` volume.
- `automountToken: true` is set on the ServiceAccount and the workload identity.
- The CPU limit is written as the number `2`, not the string `"2"`.

## Run

```bash
cd 0028/experiments/01-operator-module-render
S=$SCRATCH
go build -C $WORKSPACE/cli -o $S/exp-0028-01-opm ./cmd/opm

# Generate, drift-check, render (KUBECONFIG=/nonexistent), compare, knobs,
# and the published-module arm
OPM=$S/exp-0028-01-opm PUBLISHED=1 hack/run.sh
# Exact-objects variant
OPM=$S/exp-0028-01-opm hack/variant.sh

# Drift check against the live operator tree, then against a mutated copy
SRC=$WORKSPACE/opm-operator/config CRD_SUBDIR=crd/bases hack/drift-check.sh
SRC=<copy of source/ with "- list" added to the serviceaccounts rule and "plats" to platforms shortNames> hack/drift-check.sh   # exits 1

# Instance path, no cluster
opm instance init opm-operator testing.opmodel.dev/modules/experiments/opm-operator-render/opm_operator \
  --version 0.1.0 -n opm-operator-system --dir $S/exp-0028-01-inst
KUBECONFIG=/nonexistent opm instance build $S/exp-0028-01-inst/instance.cue > out/rendered-instance.yaml
```

The registry environment for every command is:

```bash
export OPM_REGISTRY='testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
export CUE_REGISTRY=$OPM_REGISTRY
```

### How to publish (the next experiment copies this module)

```bash
cd module
OPM_REGISTRY='testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works' \
  opm module publish . --dry-run     # gates; GO -> tag v0.1.0
OPM_REGISTRY=... opm module publish .
curl -s 127.0.0.1:5000/v2/testing.opmodel.dev/modules/experiments/opm-operator-render/opm_operator/tags/list
# {"name":"testing.opmodel.dev/modules/experiments/opm-operator-render/opm_operator","tags":["v0.1.0"]}
```

v0.1.0 was published on 2026-10-04 from commit `b0c782b`. The module tree has not changed since then. To change the module, bump `identity/identity.cue` `Version` first: the local registry does not refuse a re-push, but other experiments pin 0.1.0.

Inside a kind cluster, the operator reaches the module through `--registry=testing.opmodel.dev=opm-registry:5000+insecure,...`, which is `#config.registry`.

## Outcome

The render works. The strict claim that the output matches install.yaml does not hold.

The module renders all 19 objects with the same kinds and namespaces, and 16 of the 19 names. The four CRDs are byte-equal. The two blocking differences, the Deployment selector and seccomp, come from the catalog's idiomatic path, not from OPM itself. Rendering the same objects through `objects@v1alpha1` reaches exact spec parity (the variant below).

### What was observed

**1. The render needs no cluster and no cluster Platform.**
- `opm module build` ran with `KUBECONFIG=/nonexistent` and reported `platform: module deps (opmodel.dev/catalogs/opm@v4 v4.5.2; generated module ~/.opm/cache/platforms/aa6f72…)`.
- `opm instance build` on an `instance init` package warned `cluster Platform not used (no Platform CR in the cluster) — rendering against the instance's own deps` and produced output identical to the module build.
- Rendering the published 0.1.0 from the local registry gave the same output as the local tree.

**2. Object set.** 19/19 objects.
- 16 match by kind, namespace and name.
- The other three are bindings: `#Role` names the binding after the role. It renders `ClusterRoleBinding/opm-operator-manager-role`, `ClusterRoleBinding/opm-operator-metrics-auth-role` and `RoleBinding/opm-operator-leader-election-role`, where install.yaml has `…-manager-rolebinding`, `…-metrics-auth-rolebinding` and `…-leader-election-rolebinding`.
- Nothing reads the binding names, so this is harmless on a fresh cluster. On an upgrade from today's kustomize install, the old bindings would be left behind as orphans, because neither frontend owns them.

**3. Spec differences against install.yaml** (`out/compare.txt`, 18 spec-level lines, all on three objects):

| Object | Difference | Does it matter? |
| --- | --- | --- |
| Deployment | `spec.selector.matchLabels` is `{app.kubernetes.io/name: controller-manager, component.opmodel.dev/name, core.opmodel.dev/workload-type: stateless, module-instance.opmodel.dev/name, control-plane}`, not `{app.kubernetes.io/name: opm-operator, control-plane: controller-manager}`. The pod template labels change the same way. | **Yes.** The selector is immutable. An SSA of this render onto a Deployment that `opm operator install` created today fails with "field is immutable", so the first module-based install over an existing operator must delete and recreate the Deployment. The catalog path cannot avoid this: `componentLabels` always adds the instance and component keys, and `app.kubernetes.io/name` is forced to the component name. The pods keep `control-plane: controller-manager`, which is what the operator's e2e `-l` selectors use. |
| Deployment | `template.spec.securityContext.seccompProfile: RuntimeDefault` is missing | **Yes.** The catalog's `#SecurityContextSchema` has no `seccompProfile` at pod or container level (`grep -r seccomp catalog_opm/src` finds nothing). The pod fails Pod Security `restricted`, which install.yaml satisfies. This is a security regression on the idiomatic path. |
| Deployment | `strategy: {type: RollingUpdate}`, `restartPolicy: Always`, container `ports: []` absent | No. These are API defaults, or an empty list. |
| Service | Selector changes as for the Deployment, and `type: ClusterIP` is now explicit | It still selects the same pods. The type is the default. |
| ServiceAccount | `automountServiceAccountToken: true` | No, true is the API default. It has to be set, because `#ToK8sServiceAccount` reads the optional `automountToken` unguarded and the render fails with "empty disjunction" without it. That is a catalog bug. |

**Labels and annotations.** Every object loses the kustomize `app.kubernetes.io/managed-by: kustomize` and `app.kubernetes.io/name: opm-operator` labels. Every object gains the OPM labels:
- `managed-by: opm-cli`
- `app.kubernetes.io/{name,instance}: <component>`
- `component.opmodel.dev/name`
- `module.opmodel.dev/{name,uuid,version}`
- `module-instance.opmodel.dev/{name,uuid}`

The Namespace loses `control-plane: controller-manager`. Only an external ServiceMonitor overlay selecting `app.kubernetes.io/name=opm-operator` on the Service would notice. That overlay is `config/prometheus`, which install.yaml does not ship.

**4. The CRDs round-trip faithfully.**
- For all four CRDs, the rendered `spec` equals the source YAML spec and install.yaml's spec, by Python dict equality. The `controller-gen.kubebuilder.io/version` annotation equals the source too.
- Exercised: `x-kubernetes-preserve-unknown-fields` (moduleinstances), `x-kubernetes-validations` CEL rules (platforms, transformerregistrations), `x-kubernetes-list-type` and `x-kubernetes-list-map-keys`, the `status: {}` subresource, `additionalPrinterColumns`, `shortNames` and `listKind`. These CRDs contain no top-level `spec.preserveUnknownFields` and no `spec.conversion`.
- Negative check: adding `conversion: strategy: "None"` to a copy refused the render with `field not allowed … crds."platforms.opmodel.dev".conversion`. `#CRDSchema` cannot carry `conversion` or `preserveUnknownFields`, and embedding the whole spec makes that fail closed. metallb-style field-picking would drop it silently.
- So the operator's first multi-version CRD with a conversion webhook needs a catalog change first.

**5. Derived names.** With instance `opm-operator` in namespace `opm-operator-system`:
- Every name and namespace in install.yaml is reproduced from `#ctx.instance` with no `resourceName` override, apart from the three binding names. This works because kustomize's `namePrefix: opm-operator-` equals `<instance>-`.
- `--name opm -n opm-system` renders `opm-controller-manager` in `opm-system`, with every subject in `opm-system`.
- The CRDs do not vary with the instance, so the module is a cluster singleton.

**6. Generation and drift.**
- `cue import` with `-l '#crdSource:' -l metadata.name` produces a definition keyed by name, ready to embed. No `@embed` is needed.
- `drift-check.sh` passes against `source/` and against the live `opm-operator/config` (same beta.5).
- It fails, with a readable diff, against a copy where one RBAC verb (`list` on serviceaccounts) and one CRD shortName (`plats`) were added. That is the shape of a CI gate after `make manifests`.

**7. `#config` knobs.** `values/knobs.cue` renders:
- image `…:v1.0.0-beta.6` with no digest
- `replicas: 2`
- args with `--registry=…`, `--default-service-account=opm-applier` and the two extra args, in that order
- `GOMEMLIMIT=1638MiB`
- the given resources

See `out/rendered-knobs.yaml`.

**8. Cost** (`/usr/bin/time -v`, `opm module build`):

| Run | Wall time | Peak RSS |
| --- | --- | --- |
| Cold (fresh `CUE_CACHE_DIR`, so core, catalog and k8s are fetched from GHCR and registry.cue.works) | 5.66 s | 507 MB |
| Warm | 2.0 to 3.9 s | 494 to 510 MB |

That is well inside the operator's own 4Gi limit. Published module size: 1,977 lines of CUE, 1,713 of them generated.

**9. Exact-objects variant** (`hack/variant.sh`, `out/compare-variant.txt`).
- The variant replaces the `controller-manager`, `manager-rbac`, `metrics-auth-rbac` and `leader-election` components with one `objects@v1alpha1` component written in install.yaml's shape.
- Result: the same 19 names, **no spec-level differences**, and only label differences.
- Cost: the Deployment's pods carry no OPM instance or component labels, and the module no longer exercises the workload abstractions.

**10. Catalog and kernel rough edges found while authoring.** Each one cost a render failure with an opaque "N errors in empty disjunction" message:
- The CPU string `"2"` passes `#ResourceRequirementsSchema`'s regex, but `#NormalizeCPU` only converts `"<n>m"` strings, so `"2"` fails the Deployment transform.
- `automountToken` must be set (see the table above).
- The blueprint requires `restartPolicy` and `updateStrategy.type`.
- The `emptyDir` volume needs `readOnly` set explicitly.
- `#ctx` must be re-declared to be referenced from module files.

**Hypothesis refuted** as stated (the same names and semantically equal specs). The CRDs, all seven ClusterRoles, the ServiceAccount, Namespace, Role and Service render equal, and the render needs no cluster. The idiomatic catalog path still changes three binding names, the Deployment selector (immutable, so an upgrade over today's install must recreate the Deployment) and drops `seccompProfile` (a Pod Security `restricted` regression). `objects@v1alpha1` closes all three today.

### Design implications for 0028

- The real module should be a hybrid:
  - `#CRDs` with the whole spec embedded, generated by `cue import` and drift-checked.
  - `#Namespaces`.
  - `objects@v1alpha1` for the Deployment, Service, ServiceAccount and all RBAC.

  The alternative is to land `seccompProfile` in the catalog's security context first and accept a one-time Deployment recreate plus orphaned bindings when migrating from install.yaml. The entry has to decide which.
- `opm operator install` over an existing kustomize-installed operator must handle the selector change if the catalog path is used. Possible approaches: delete the Deployment before apply, or keep the old selector through `objects`.
- Multi-version CRDs (conversion) need a catalog `#CRDSchema` extension before the operator ships them. The fail-closed embed surfaces this at render time.
- The CLI-side render works on a bare cluster: the generated platform comes from the module's own pins. This confirms the bootstrap order in BRIEF fact 2, at least for rendering.
- Release: the image digest default in `#config` is only possible here because beta.5 is already built. A released module defaults the tag only, or stamps the digest at publish time.

Cluster: none was created. Not linked into `02-design.md` or `03-decisions.md` yet, because this agent owns only its experiment directory. The supervisor should add the link and the index row in `experiments/README.md`.
