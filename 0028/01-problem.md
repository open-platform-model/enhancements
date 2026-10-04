# Problem Statement: The Operator Ships as an OPM Module

OPM asks every workload to be a module with a typed configuration, a registry address and an inventory of what it deployed. Its own controller is the one workload that is none of those things: the operator is installed from a static Kubernetes manifest that the CLI carries inside its binary.

## Current State

The operator's install is one manifest of 19 objects, built by the operator's release and copied into the CLI.

- **What the manifest holds.** Four CustomResourceDefinitions (ModuleInstance, ModulePackage, Platform, TransformerRegistration), the `opm-operator-system` Namespace, one ServiceAccount, seven ClusterRoles, two ClusterRoleBindings, one Role and RoleBinding for leader election, a metrics Service and the controller Deployment. It has no webhooks and no certificates. Measured from `cli/internal/operator/dist/install.yaml` on 2026-10-04.
- **How it is built.** The operator's release workflow renders the kustomize tree under `config/` with the image pinned by version tag and digest, and uploads the result as a release asset (`opm-operator/.github/workflows/release.yml`, job `image-release`, read 2026-10-04). Eleven of its 19 objects carry the label `app.kubernetes.io/managed-by: kustomize`, the four CRDs and four RBAC objects carry no managed-by label, and none carries an OPM instance identity (measured from the embedded manifest).
- **How the CLI installs it.** The CLI embeds that asset from one pinned release (read from `cli/internal/operator/manifest.go` on 2026-10-04, pinned to `v1.0.0-beta.5`) and applies every document with server-side apply as field manager `opm-cli`. The CRDs-only form applies the CustomResourceDefinition documents of the same file. Selecting another release downloads that release's asset from GitHub over HTTPS with no further integrity check (0006:D35 deferred one). Install then seeds the cluster Platform with a plain create (0006:D22).
- **How it is removed.** Uninstall deletes the documents of the CLI's own embedded manifest except the CRDs and the Namespace, and refuses while any instance still carries the operator's cleanup finalizer (0006:D34).
- **How it is tuned.** The controller's tuning lives in command-line arguments: the module registry mapping, the default applier service account, the CUE cache and render concurrency (read from `opm-operator/cmd/main.go` on 2026-10-04). None of them is reachable from the install command. The install guide tells the user to patch them onto the Deployment by hand, and warns, verbatim from `opm-operator/docs/site/start/install-the-operator.md` (read 2026-10-04): "Running `opm operator install` again drops the flags you added: it force-applies the shipped manifest, which restores the manager's original arguments."

## Gap / Pain

1. **Tuning does not survive an upgrade.** The only way to upgrade the operator is to re-run install, and re-running install resets every argument the user added. An operator that loses its registry mapping falls back to the public registry and fails every instance whose module lives elsewhere. One that loses its default service account applies as itself, and its own role grants no workload rights.
2. **The operator has no inventory.** Uninstall deletes what the CLI's own copy of the manifest lists, not what is on the cluster. An object an older release installed and a newer release dropped is never removed by an upgrade and never removed by an uninstall run from a newer CLI. Nothing records which release is running except the image tag on the Deployment.
3. **OPM does not use its own model for its own controller.** The registry, versioned module, typed configuration, render and inventory that OPM asks module authors to trust are never exercised by OPM's most critical workload. A module author reading the install guide sees the project install its controller the way OPM tells them not to install theirs.
4. **The install shape has two authorities that nothing compares.** The kustomize tree defines what the release publishes, and the CLI embeds whatever asset it last copied. No check proves the operator's committed manifest, the release asset and the CLI's embedded copy agree beyond the image tag (measured: the CLI's release gate compares only the embedded image tag with its pinned version, read 2026-10-04).
5. **Selecting another version needs GitHub.** The embedded manifest is the only offline path. Any other version is fetched from GitHub release assets, which an air-gapped cluster cannot reach and a registry mirror cannot serve.

## Concrete Example

A platform team runs OPM on a cluster whose modules live in an internal registry.

```text
1. opm operator install                       19 objects applied, Platform seeded
2. kubectl patch deployment ...               --registry=opmodel.dev=registry.internal/opm
                                              --default-service-account=opm-applier
3. instances reconcile                        Ready
4. new CLI release, team upgrades the CLI
5. opm operator install                       built-in manifest force-applied
                                              --registry and --default-service-account gone
6. operator restarts                          resolves modules from the public registry,
                                              applies as its own service account
7. every instance                             ResolutionFailed or forbidden
```

The team followed the guide. Step 5 is the documented upgrade path, and the guide's own warning describes what it does to step 2. Nothing in step 5 can know about step 2, because step 2 changed a live object that no OPM record describes.

## User Stories

- As a **platform team operator**, I want the operator's registry mapping and applier identity to survive an upgrade so that upgrading OPM does not break every instance. Today: re-running install resets them and the guide says so.
- As a **platform team operator on an air-gapped cluster**, I want to install any operator version from my registry mirror so that I am not tied to the version my CLI was built with. Today: another version is fetched from GitHub release assets.
- As an **OPM maintainer**, I want the operator's install to be an ordinary module so that one release produces one artifact, the CLI pins one number, and the module path is exercised by OPM itself on every install. Today: the release produces a manifest the CLI copies, and the copy is synchronised by hand.

## Why Existing Workarounds Fail

- **Patch the Deployment after every install.** This is the documented workaround. It must be repeated after every upgrade, it is easy to forget, and forgetting it fails every instance at once.
- **Keep a kustomize overlay over the release manifest and apply it with kubectl.** It keeps the tuning, but it leaves the CLI's install, readiness check and uninstall working from a manifest that is not the one on the cluster. A later `opm operator install` overwrites the overlay's changes.
- **Deploy the operator with another tool (Helm, Flux).** It answers tuning and upgrade, and it confirms the problem: OPM's own controller would be the one workload OPM recommends deploying with something other than OPM.
