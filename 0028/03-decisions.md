# Design Decisions: The Operator Ships as an OPM Module

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, a changed choice is an in-place edit to the existing `DN`, with an evidence-backed old position folded into *Alternatives considered*. Once `accepted`, bodies are protected and a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract`, `policy` or `scope`) and passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Mechanism decisions belong in the implementing OpenSpec change in the target repo.

Both experiments concluded on 2026-10-04 and are folded in. [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) backs D2 and D12: the catalog's workload and role resources change three binding names and the Deployment's selector and drop the pod's seccomp profile, and writing those objects in the manifest's shape avoided all three. The owner then chose the catalog path anyway, as the better showcase, so D2 renders through the catalog, D12 adds the seccomp profile and subject-less roles to the catalog first, and D8's migration recreates the Deployment once and deletes the old bindings. [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) backs D3, D4, D8 and D9: the two-step install, reinstall and upgrade held; a refused install had already changed the CRDs, `--wait` returned before the operator reconciled, and deleting the operator's instance with `opm instance delete` skipped the finalizer guard, so D3 and D9 gained requirements.

---

## Decisions

### D1: The operator module is its own release unit in the operator repository

**Kind:** contract

**Depends:** 0011:D10, 0021:D2, 0021:D10

**Decision:** The operator is published as the module `opmodel.dev/modules/opm_operator` from the operator's own repository, as a release unit of its own. The module has its own version train, independent of the operator binary's: its own versions, its own release pull request and its own release tags. Its release tags name the module and its version in a form no operator release tag can take, and like every release tag in the organization they are created only by the release tooling and never moved (0021:D10). How the repository produces those tags is the implementing change's to decide; the tag shape is part of this contract.

The module's source names the operator image it deploys by version tag and content digest. An operator release builds and publishes its image before any module release references it, so the digest is known when the module's source is committed, and the published module is the tagged source with nothing stamped at publish time. An operator release is followed by a module release that moves the image reference to it; a module release may also change only the module itself (its `#config`, its rendered shape, its core and catalog pins) and deploy the same operator as the release before it. One module version therefore deploys exactly one operator version. The CLI pins a module version, and through it the operator version it installs (D3). The CLI's ceiling on operator versions (0021:D9) still reads the version the running operator reports about itself, not the module's version.

**Version rule.** The module is in the module class of 0021 (D2 of this entry), on its own train: its version moves by what its `#config` accepts (0021:D2), never by the operator's or the CLI's `MAJOR.MINOR`. Its path starts at major `v0`. While the operator it deploys is on its beta line, the module is pre-stable: its versions are `0.y.z`, and a release that 0021:D2 classes as breaking raises `y`, while every other release raises `z`. The module crosses to `@v1` with its first `1.0.0` release, no earlier than the operator's GA, and from then on 0021:D2 binds it unshifted. This `0.x` form is one of the pre-stable forms 0021:OQ4 weighs; if 0021 settles its pre-stable form for modules otherwise before this entry is accepted, the version rule follows 0021.

**Integrity.** A version tag is not an integrity anchor: OPM's release paths never re-point one (0021:D10), but GHCR has no tag-immutability control, and the requirement that a conforming registry refuse an overwrite does not take effect until such a registry is in place (0011:D10), so the registry, or a mirror, can serve other bytes under the same tag. The CLI therefore pins its default module version together with the content digest that version was published with, and install of the default refuses a module whose content differs. Because the module names the image by digest, the image is anchored through the module. A user who selects another module version gets the module the registry serves under that version, whose image reference is still a digest, and install says so; verifying a signature instead is OQ7. Each module release is signed and attested with the same kinds of signature and provenance the operator image carries.

**Revised:** 2026-10-04: the module left the operator's version for a train of its own after the owner's decision; the image is now named by digest in the module's source; R1 to R3 and R6 to R8 retired, R9 to R15 added.

**Requirements:**

- R1: (retired, 2026-10-04)
- R2: (retired, 2026-10-04)
- R3: (retired, 2026-10-04)
- R4: The module artifact of a release carries the same kinds of signature and provenance attestation as the operator image it deploys.
- R5: Only the operator repository's own module release publishes under the module's path.
- R6: (retired, 2026-10-04)
- R7: (retired, 2026-10-04)
- R8: (retired, 2026-10-04)
- R9: The operator module is released from the operator's repository on a version train of its own: its versions and release tags are independent of the operator binary's, and every module release tag names the module and its version in a form no operator release tag takes.
- R10: Every module release names the operator image it deploys by a published operator release's version tag and content digest, and the module content it publishes is its tagged source, with nothing added at publish time.
- R11: Every module version deploys exactly one operator version, and that version is readable from the module before it is installed.
- R12: While the module's path major is `v0`, a module release that 0021:D2 classes as breaking raises the minor, and every other module release raises the patch.
- R13: The module's path starts at major `v0` and moves to `v1` only with a `1.0.0` release made no earlier than the operator's first GA release.
- R14: Installing the CLI's default module version applies the module content that CLI release pinned, identified by content digest; a module whose content differs is refused before any object changes.
- R15: Installing a module version other than the CLI's default reports that the module is trusted as the registry serves it, and still pulls the operator image by the digest the module names.

**Alternatives considered:**

- **One version for the module and the operator, published by the operator release (previously adopted).** The module carried the operator release's version, so one release produced one number. Not chosen by the owner on 2026-10-04. The digest of the image did not exist when the release's content was committed, so the module's source could name the image by tag only and the install paths had to supply the digest; every core or catalog adoption by the module forced an operator release with no binary change; and the module class's bump rule had to share one number with the tooling train's `MAJOR.MINOR` (0021:D9) and the documentation site's version (0021:D10), so adding one optional tuning field would have dragged the CLI and the site to a new minor (the former OQ13). A separate train removes all three: the image exists before the module names it, a pin adoption is a module release, and `#config` moves only its own number.
- **Publish the module from the first-party module fleet.** Not chosen: the module's CRDs and RBAC are generated from the controller's code and drift-checked against it (D2), which needs the module beside the controller's source, and only the operator's repository can make an operator release's image reference the next module release's input.
- **Stamp the image digest into the artifact at publish time.** Not chosen: the published module would differ from its tagged source tree. With the module on its own train the digest is known before the module is committed, so there is nothing to stamp.
- **Start the module at `@v1` on the stable table.** Not chosen: while the operator is on its beta line its controller arguments, and so the module's `#config`, still change, and every narrowing would move the module's path to a new major, an import change for every consumer of what is still a pre-stable controller.
- **A `1.0.0-beta.N` line like the operator's.** Not chosen: the version would look coupled to the operator's `1.0.0-beta.N` when it is not, and 0021:D7 names the prerelease lines explicitly, with module fleets on the stable table, so adding one would amend it.
- **Trust the version tag alone.** Not chosen: GHCR does not refuse a tag overwrite (0011:D10) and experiment 01's local registry accepted a re-push of the same module version, so the default install would apply, with cluster-admin rights, whatever the registry or a mirror served under the tag, where today it applies a manifest compiled into the CLI binary.
- **Publish under the test namespace `testing.opmodel.dev`.** Not chosen: that prefix holds test fixtures and is documented as not a staging environment.

**Rationale:** The owner chose a registry pull for install, which needs a published module at an address the CLI can pin, and then chose a version of its own for that module. Publishing it from the operator's repository keeps it beside the controller whose CRDs and permissions it renders. Naming the image by digest in the source closes the integrity gap a tag leaves without a publish-time step, and pinning the module's content digest in the CLI extends that anchor to the module. The `v0` start keeps the module's path stable while the controller it deploys is still pre-stable. The path follows the first-party module convention: one flat snake-case leaf under `opmodel.dev/modules/`, which the CLI's publish gate already admits.

**Measured 2026-10-04:** the operator's release workflow already installs the CLI and publishes its test fixture modules with it, after the image job (`opm-operator/.github/workflows/release.yml`, jobs `image-release`, `publish-examples`, `publish-release`). The publish gate admits first-party paths of the form `opmodel.dev/modules/<leaf>` (`cli/internal/publish/gates.go`, read the same day). [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) defaulted the image by tag and digest because the beta.5 image already existed when the module was written, which is the order a separate module train makes normal. Its local registry accepted a re-push of the same module version. Today both install paths pin the image by tag and digest: the embedded manifest names `opm-operator:v1.0.0-beta.5@sha256:cd48…` (`cli/internal/operator/dist/install.yaml`), and the release renders a "digest-pinned install manifest" (`opm-operator/.github/workflows/release.yml`, job `image-release`), so R10 and R14 keep an anchor the install already has. The workspace's tag rule allows only release-please to create tags (`AGENTS.md` "Release Tags Are Immutable", `RELEASING.md`), and the operator's tags today carry no component, so the module's tags need one to be told apart.

**Source:** User decision 2026-10-04: "Where does opm operator install get the operator module?" = "Registry pull (Recommended)" (pull opmodel.dev/modules/opm_operator from GHCR; air-gapped users point --registry at a mirror; drop the embedded install.yaml; the CLI pins a module version). User decision 2026-10-04 (round 2): "Module version = operator version ... Which rule wins?" = "Separate module version" ("Decouple: the module has its own version train; the CLI pins module and operator versions separately."). The `v0` start, the `0.x` bump rule (R12, R13) and the signing clause: supervisor defaults 2026-10-04, not yet confirmed by the owner. The digest anchor (R10, R14, R15): review finding 2026-10-04, re-cut after the owner's decision.

### D2: The module is the authority for the operator's install shape

**Kind:** contract

**Depends:** 0021:D2, 0021:D4

**Amends:** 0021:D4

**Decision:** The operator module is the one source of the operator's install shape. Its CRDs and the controller's cluster RBAC are generated from what the controller's own code declares (its CRD schemas and its permission markers), and a module release whose module disagrees with the operator release it deploys is refused before anything is published. Each module release publishes an install manifest, and that manifest is the module's render at its default values, so a kubectl-only install stays possible and cannot differ from the module. The operator release no longer publishes an install manifest of its own.

The module renders the operator through the first-party catalog's abstractions: the CRDs, the Namespace, the controller's workload, its service account, and its roles and bindings each come from the catalog resource made for them, not from objects written in a manifest's shape. The five ClusterRoles the manifest ships unbound, for administrators to bind to users, are roles with no subjects, which the catalog's role resource renders once D12 holds. Three properties follow from that choice and bind the module:

- **Names.** The Namespace, the Deployment, the ServiceAccount, the Service, the roles and the CRDs keep the names an operator installed from an earlier manifest has, so the CLI's fallback locator (D3:R15), documentation and the migration of D8 see the same operator. A role binding takes the name the catalog derives from its role, so the three bindings of the earlier manifest are renamed and D8 removes the old ones.
- **Selector.** The controller Deployment's pod selector is the catalog's, which differs from the earlier manifest's. Kubernetes never lets an apply change a selector, so the move from a manifest-installed operator to the module recreates the Deployment once (D8). From then on every module version renders the same selector, and no upgrade between module versions deletes the Deployment.
- **Security.** The operator's pods keep the security posture the manifest gave them: they satisfy the Kubernetes Pod Security `restricted` profile, which needs the catalog's seccomp profile (D12).

This amends 0021:D4. What survives: the install manifest is still not an artifact class of its own. What changes: the manifest is a render of the operator module and an artifact of the module's release, not of the operator release, and the operator module falls in the module class, on its own train (D1), with its `#config` schema as the compatibility surface 0021:D2 assigns to every module.

**Revised:** 2026-10-04: the catalog path replaces the manifest-shaped objects after the owner's decision; R4 to R7 retired, R9 to R13 added; the manifest moved to the module's release with D1's separate train.

**Requirements:**

- R1: For every module release, the CRDs it renders are identical to the CRD schemas served by the controller of the operator release it deploys. Validated by [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/): all four CRD specs rendered equal to the controller's generated YAML.
- R2: For every module release, the cluster RBAC it renders for the controller grants exactly the permissions the controller of the operator release it deploys declares it needs.
- R3: A module release that fails R1 or R2 publishes nothing. Experiment 01's regenerate-and-diff check failed on one added RBAC verb and one added CRD short name, and passed against the operator's own generated tree.
- R4: (retired, 2026-10-04)
- R5: (retired, 2026-10-04)
- R6: (retired, 2026-10-04)
- R7: (retired, 2026-10-04)
- R8: The operator's pods satisfy the Kubernetes Pod Security `restricted` profile, as the pods of the earlier manifest do.
- R9: Every module release publishes an install manifest equal to its render at default values, and applying that manifest with kubectl on a cluster with no operator yields a running operator.
- R10: The operator's Namespace, Deployment, ServiceAccount, Service, roles and CRDs have the same names whether the operator was installed from the module or from an earlier release's manifest; only role bindings may take a name the catalog derives.
- R11: Upgrading or downgrading between module versions never requires deleting the operator's Deployment: every module version renders the same Deployment selector.
- R12: The published operator module renders the controller's workload, service account, roles and bindings through first-party catalog resources, and renders no object written as raw Kubernetes data except where a catalog resource for that kind does not exist.
- R13: No operator release publishes an install manifest of its own; the module release's manifest is the one manifest a user applies with kubectl.

**Alternatives considered:**

- **Write the controller's workload and RBAC as objects in the earlier manifest's shape (previously adopted after experiment 01).** The catalog's `objects` resource reached spec parity with the manifest: the same 19 names, the same Deployment selector and the seccomp profile, with only label differences ([`experiments/01-operator-module-render/`](experiments/01-operator-module-render/), variant), so the migration of D8 would have recreated nothing. Not chosen by the owner on 2026-10-04: OPM's own controller would not exercise the catalog's workload and role abstractions, which is the showcase this entry exists for. The owner accepted the costs the catalog path carries, which the beta line allows as a declared break (0021:D7): the catalog gains a seccomp profile first (D12), and the first module install over a manifest-installed operator recreates the Deployment once and deletes the three old bindings (D8).
- **Keep the five unbound ClusterRoles as raw objects with a stated reason.** Not chosen: the catalog's role resource needs only to accept a role with no subjects and skip the binding for it (D12:R2), a small change that leaves the module with no raw object at all.
- **Keep the kustomize tree as the authority and generate the module from its render.** Not chosen: the module would be a passthrough of bytes with no typed configuration of its own, and the tuning surface of D5 would have to be patched into kustomize output. The kustomize tree stays where it is useful, as the source of what the controller's generators emit.
- **Drop the install manifest and make the module the only install path.** Not chosen: a kubectl-only install is a documented path, and some users apply the manifest from their own GitOps tooling. Rendering the manifest from the module keeps that path at the cost of one release step, and it cannot drift.
- **Copy the CRD and RBAC YAML into the module by hand.** Not chosen: the first-party modules that carry CRDs re-vendor them by a documented manual recipe with no check, so a module and its controller can disagree without anyone seeing it. The operator's CRDs are the contract the CLI writes against, so drift there is a correctness bug, not a stale copy.

**Rationale:** One authority removes the gap in 01-problem.md where the committed manifest, the release asset and the CLI's copy are compared by nothing. Generating from the controller's own declarations keeps the controller's code as the place a permission or a field is decided. Rendering through the catalog makes OPM's own controller the module that proves the catalog's workload abstractions can carry a production controller under the `restricted` profile. Keeping every name the CLI and the documentation read is what lets them stay correct; the bindings are the one exception because nothing reads them.

**Measured 2026-10-04:** the kernel loads only the `.cue` files of a module tree (`library/opm/internal/sourcetree/sourcetree.go`), so a module cannot carry the controller's CRD YAML as files and must hold it as CUE. The first-party modules `cert_manager` and `metallb` hold their CRDs as CUE generated by `cue import`, with a README recipe and no drift check (`modules/cert_manager/README.md`, `modules/metallb/README.md`). The manifest's five unbound ClusterRoles are `metrics-reader`, the ModuleInstance admin, editor and viewer roles, and the TransformerRegistration admin role, each under the `opm-operator-` prefix (`cli/internal/operator/dist/install.yaml`); none carries an aggregation rule.

**Measured 2026-10-04 by [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/)** (operator v1.0.0-beta.5, core v2.0.0-beta.2, catalog opm 4.5.2, CLI 1.0.0-beta.7):

- The module renders all 19 objects with no cluster and no cluster Platform. Every name derives from the instance's name and namespace: instance `opm-operator` in `opm-operator-system` reproduces the manifest's names, because the manifest's name prefix equals `<instance>-`. The CRDs do not vary with the instance, so the module is a cluster singleton (D3:R11).
- The CRDs are generated from the controller's YAML into CUE and embedded whole. Every schema feature the operator's CRDs use survived (CEL validations, preserve-unknown-fields, list-map keys, the status subresource, printer columns). The catalog's CRD resource cannot carry `conversion` or `preserveUnknownFields`; embedding the whole spec makes such a field refuse the render instead of vanishing, so a future multi-version CRD needs a catalog change first (05-risks.md).
- Catalog path: 16 of 19 names equal; the three bindings take their roles' names; the Deployment's selector gains the catalog's instance, component and workload-type labels; the pod loses `seccompProfile: RuntimeDefault` because the catalog's security context has no seccomp field. The ServiceAccount, Service, Namespace, Role and all seven ClusterRoles render equal. Objects written in the manifest's shape: the same 19 names, no spec differences, only labels.
- Cost: 5.7 s and 507 MB peak memory cold, 2 to 4 s warm. The module is 1,977 lines of CUE, 1,713 of them generated.

**Source:** Supervisor seed 2026-10-04, following from the owner's registry-pull decision of the same day. The 0021:D4 amendment follows 0021:D2 ("A module's compatibility surface is its `#config` schema"). The catalog path, R10 to R12 and the dependence on D12: user decision 2026-10-04 (round 2): "The operator module can match install.yaml exactly only by writing the Deployment and RBAC as raw objects ... Which shape?" = "Catalog abstractions (Recommended)" ("Better showcase. Add seccompProfile to catalog_opm first; install's one-time migration recreates the operator Deployment (controller blips, workloads untouched) and deletes the 3 old *-rolebinding objects. Beta allows the break."). The unbound roles through the catalog: supervisor default 2026-10-04 after reading the catalog's role resource. R9 and R13 follow D1's separate train.

### D3: `opm operator install` deploys the module as a CLI-owned ModuleInstance

**Kind:** contract

**Depends:** 0006:D3

**Amends:** 0006:D5, 0006:D32, 0006:D35, 0021:D9

**Decision:** `opm operator install` deploys the operator by installing its module. It obtains the module from the module registry the CLI is configured with, renders it, applies the module's CRDs and waits until they are served, and then applies a CLI-owned ModuleInstance of the module the way any CLI instance is applied. The two steps exist because the instance record is itself a ModuleInstance, which cannot be written before its CRD exists. The CRDs applied in the first step are the module's own render of them, carrying the instance's identity, so the second step records them in the instance's inventory instead of refusing them as foreign objects.

The CLI carries no copy of the operator's manifests. Each CLI release names one default module version, pinned with its content digest (D1:R14), and the user may select another version for a run. The module version fixes the operator version (D1:R11). A cluster with no access to the public registry installs from a mirror by pointing the CLI's registry mapping at it. The CRDs-only form keeps its meaning: it applies exactly the CRDs of the same render and nothing else, writing no instance record, no workload and no Platform.

The operator's instance is a singleton: it has the same name and namespace on every cluster and every install. The spellings of that name and namespace are fixed by the implementing change and are part of this contract from then on. The module renders the operator's Namespace itself, so install creates it only as an object of the instance and records it.

An install that refuses changes nothing. Every check that can refuse the install runs before the CRD step, because the CRD step writes the instance's identity onto the CRDs: resolving and rendering the module, the content check of D1:R14, the check of recorded values (D5:R3), the apply guard of entry 0012 over every object the render names, with the migration's own adoption (D8), and the version checks of D10. The render always uses the module's own dependency pins (D11). The two cluster checks of an ordinary instance apply that ask whether the CRDs are present and recent enough run after the CRD step, which is what satisfies them on a fresh cluster. The third, the ceiling of 0021:D9, does not refuse install: install replaces the operator the Platform reports rather than driving it, and a ceiling that refused it would leave a CLI below the recorded operator no way to repair the cluster (D4). Install checks the operator version of the module it installs instead (D10:R1).

Install reports success only once the operator release it installed is reconciling, not when its Deployment is merely rolled out: the cluster Platform reports Ready from that release. When the objects are applied but the Platform does not report Ready from the installed release within the wait, install keeps everything it applied, rolls nothing back, and fails with an error naming the Platform and its condition; re-running install once the Platform is fixed completes it.

Every CLI command that needs to know whether the operator is present and serving finds it through the operator's instance record when one exists. Where none exists, as for an operator applied with kubectl or GitOps from a release manifest, earlier or rendered from the module, or one whose record was deleted, the command finds the operator by the fixed names every install path keeps (D2:R10 and this decision's R11): its Deployment in its Namespace and the four CRDs. The CLI no longer carries the manifest it used to read those names from, so the names are part of this contract.

This amends three decisions of entry 0006:

- **0006:D5.** What survives: installs use server-side apply as `opm-cli`, the CLI never deletes CRDs, and instance apply never installs CRDs implicitly but fails with a hint. What changes: the CLI no longer embeds the operator's manifests, and the offline learner path that embedding served is replaced by a registry mirror.
- **0006:D32.** What survives: the `opm operator` command group and its CRDs-only form. What changes: install applies the operator module as an instance instead of applying the documents of an embedded manifest.
- **0006:D35.** What survives: the CRDs are a subset of the one artifact the full install applies, so they cannot drift from it, and install waits until the CRDs are served and the operator has rolled out. What changes: the artifact is the module's render, not an embedded manifest; the pinned manifest and its refresh task go away; selecting another version resolves a module version from the registry instead of downloading a GitHub release asset.

It also amends 0021:D9. What survives: every CLI command that drives the operator refuses one whose `MAJOR.MINOR` is above the CLI's own, read from what the running operator reports. What changes: install of the operator's own instance is not refused by that ceiling on the running operator; it applies the same `MAJOR.MINOR` rule to the operator version of the module it installs (D10:R1).

**Revised:** 2026-10-04: R10 tightened and R12 to R14 added after experiment 02. 2026-10-04 after review: the check order spelled out, R4 and R13 narrowed, R15 to R17 added, 0021:D9 amended.

**Requirements:**

- R1: On a cluster with none of OPM's CRDs, one install run leaves the operator running and recorded as exactly one CLI-owned ModuleInstance of the operator module. Validated by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 1, with a catalog-path module, the shape D2 requires, before the catalog had a seccomp profile.
- R2: Install writes the instance record only after the module's CRDs are served.
- R3: Every object the module renders, the CRDs and the Namespace included, is recorded in the instance's inventory, and no step of the install refuses an object the install itself applied. Experiment 02: all 19 objects recorded; creating the Namespace outside the module made the instance apply refuse it as a foreign object.
- R4: The CLI obtains the operator module from its configured module registry.
- R5: Each CLI release names one default module version, and a user can install any other published version.
- R6: With the CLI's registry mapping pointed at a mirror holding the module and its dependencies, install succeeds on a cluster with no access to the public registry.
- R7: The CRDs-only form applies exactly the CRDs a full install of the same module version applies, and writes no instance record, no workload and no Platform.
- R8: A full install after a CRDs-only install of the same module version records the existing CRDs without recreating them. Experiment 02 reported the four CRDs unchanged when the instance apply followed the CRD step of the same install; a CRDs-only install followed by a separate full install was not run.
- R9: Re-running install with an unchanged module version and unchanged values changes no live object. Validated by experiment 02, step 4, with the catalog-path module: all 19 objects kept their uid and resourceVersion.
- R10: Install reports success only after the CRDs are served, the operator's Deployment has completed its rollout, and the cluster Platform reports Ready from the operator release just installed.
- R11: A cluster holds at most one operator instance, and it has the same name and namespace on every cluster.
- R12: An install that refuses changes no object in the cluster.
- R13: After a module install, every CLI command that checks for a running operator before it acts finds the operator through its instance record.
- R14: Install creates no object outside the module's render except the cluster Platform and the opt-in user role of D6.
- R15: Where the cluster holds no operator instance record, every CLI command that checks for a running operator finds an operator installed from a release manifest, an earlier one or one rendered from the module, by the fixed names of its Deployment, Namespace and CRDs.
- R16: Install is not refused because the operator the cluster Platform reports has a `MAJOR.MINOR` above the CLI's.
- R17: An install whose objects are applied but whose cluster Platform does not report Ready from the installed release within the wait keeps every applied object, rolls nothing back, and fails with an error naming the Platform and its condition.

**Alternatives considered:**

- **Keep the embedded manifest and publish the module only for GitOps users.** Not chosen: two install shapes for one operator, and the CLI, OPM's main frontend, would still not install its own controller with OPM.
- **Embed the module tree, vendored with its dependencies, in the CLI.** Not chosen by the owner, who chose a registry pull. A vendored module renders through a local replacement, which marks the instance as rendered from local bytes, and it brings back the pin-and-sync plumbing the embedded manifest needs.
- **Ship the CRDs as a separate bundle outside the module.** Not chosen: a second artifact per release that must agree with the first. Neither frontend deletes a CRD in an instance's inventory (0012:D1:R3), so keeping the CRDs in the module costs nothing on uninstall.
- **Apply the whole module in one step and let the record follow.** Not possible: the CLI refuses any instance apply while the ModuleInstance CRD is missing, because the record it writes is a ModuleInstance.

**Rationale:** Install becomes the most-used instance of the module path rather than a special case beside it. The CRDs-first step is the minimum the bootstrap needs, and making it the module's own render keeps the record honest about every object the install owns. The owner accepted that install now needs a registry, with a mirror as the answer for clusters that cannot reach the public one.

**Measured 2026-10-04:** the CLI refuses an instance apply with "ModuleInstance CRD not found" when the CRD is absent (`cli/internal/inventory/gates.go`). On a cluster with no Platform, the CLI renders against a platform generated from the module's own dependency pins (`cli/openspec/specs/platform-resolution`, read the same day), so the bootstrap needs no Platform. An instance's identity is a name-based UUID of its own coordinates (`core/src/module_instance.cue`), so the first step can stamp the identity the second step will record.

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/)** (kind, Kubernetes 1.36, module emulating install with `kubectl` for the CRD step and `opm instance apply` for the rest):

- Fresh install: the render used the instance's own dependency pins ("cluster Platform not used … rendering against the instance's own deps"), the apply wrote the Namespace first and then the other 18 objects, and the ModuleInstance landed in the Namespace the same apply created. The operator then wrote only a `ManagedExternally` status condition on its own instance and reconciled a fixture end to end once the Platform was seeded.
- Upgrade between two module versions was a re-apply: one new ReplicaSet, 13.9 s for apply and wait. The new pod's controllers started 28 s after the pod did, the first fixture reconcile after the upgrade reported `PlatformNotReady`, and `opm instance apply --wait` had reported the instance healthy about 30 s before the operator reconciled anything. R10 is tightened for this.
- Migration probe: the instance apply refused at its first foreign object, but the CRD step had already relabelled the four CRDs. R12 and the order of checks above follow from this.
- The CLI's readiness check, which the per-instance delete guard calls, locates the operator through the CRD names and the Deployment name of the embedded manifest (`cli/internal/operator/ready.go`, read 2026-10-04). Dropping the manifest removes that locator, so R13 and R15 are requirements of this decision rather than an implementation detail. Without R15, that guard (`deleteOperatorOwned`, `cli/internal/cmd/instance/delete.go`) would refuse every operator-owned delete on a cluster whose operator was applied with kubectl.
- An ordinary instance apply runs three cluster gates in order: the ModuleInstance CRD is present, its fields meet a floor, and the operator's `MAJOR.MINOR` is not above the CLI's (`RunClusterGates`, `cli/internal/workflow/apply/apply.go`). The ceiling reads `status.operatorVersion` from the Platform the earlier operator wrote and skips itself for a development CLI (`cli/internal/inventory/gates.go`). Experiment 02 ran a development CLI, so it never exercised the ceiling; R16 follows from reading the code.
- Install time on a fresh cluster was the same as today's within noise (28.6 to 31.8 s against 28.7 to 30.7 s); render plus CRDs cost 2.3 to 3.5 s of it.
- The operator's module fetches worked unchanged through a plain pull-through mirror of GHCR, which is the mirror path of R6 on the operator's side. The CLI's side of R6 was not measured: the host running the CLI had public access.

**Source:** User decision 2026-10-04: "Where does opm operator install get the operator module?" = "Registry pull (Recommended)" (pull opmodel.dev/modules/opm_operator from GHCR; air-gapped users point --registry at a mirror; drop the embedded install.yaml; the CLI pins a module version). The two-step bootstrap: supervisor brief 2026-10-04, from the CRD gate measured above. R10, R12, R13, R14: experiment outcome `0028/experiments/02-cli-bootstrap-install/` (2026-10-04). The check order, R15 to R17 and the 0021:D9 amendment: review finding 2026-10-04, supervisor defaults not yet confirmed by the owner. The version checks and the render platform the check order names: D10 and D11 (supervisor resolutions of OQ4, OQ5 and OQ6, 2026-10-04).

### D4: The operator's own instance stays CLI-owned

**Kind:** contract

**Depends:** 0006:D3

**Decision:** The ModuleInstance that deploys the operator is owned by the CLI for its whole life. The operator never reconciles the instance that deploys it: as a CLI-owned instance it is skipped under 0006:D3, and if its owner field is changed by hand, or it is created with another owner, the operator still applies, prunes and finalizes nothing for it. Upgrading the operator is re-running install (D3, D9). No CLI command moves this instance to the operator. Moving an instance's ownership between the CLI and the operator is out of scope for this entry and designed elsewhere; whatever design adds it must refuse this instance, at the CLI and in the operator, because R1 holds whatever the owner field says. Re-running install is the one recovery path for a broken operator, and it needs nothing from the operator.

**Revised:** 2026-10-04: made a contract with R1 and R2 after review, so the owner's "the operator never reconciles itself" binds the operator directly instead of resting on a draft entry. 2026-10-04: the refusal stated as this entry's own rule (R3) after the owner took ownership transfer out of these plans.

**Requirements:**

- R1: The operator applies, prunes and finalizes nothing for the instance that deploys it, whatever that instance's owner field says.
- R2: Re-running install repairs or replaces the operator with no step taken by the running operator, whether that operator is running, failing or absent.
- R3: No CLI command changes the owner of the operator's own instance to the operator.

**Alternatives considered:**

- **The operator takes over its own instance after the bootstrap**, as Flux does after `flux bootstrap` and as Argo CD does when it manages its own Application. Not chosen by the owner. An operator that owns its own instance prunes its own Deployment and RBAC when the instance is deleted with `spec.prune: true`, then waits forever on a cleanup finalizer only it can clear. It needs an applier identity allowed to grant any permission it applies, which is cluster-admin in practice. A broken image cannot render the fix to itself.
- **Allow the transfer, guarded by the same gates as any instance.** Not chosen: the gates prove the operator can pull and apply the instance, not that it can recover from applying itself wrongly. A self-managing operator has no outer layer left to repair it.

**Rationale:** The operator is the one workload whose failure stops every other instance, so its recovery path must not depend on it. Prior art agrees: the Flux Operator does not upgrade itself and is deployed by something else, and Flux's own guidance for a broken self-managed install is to run the bootstrap command again. Keeping the instance CLI-owned makes install that outer layer permanently.

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 8,** flipping the operator's own instance to `owner: operator` by hand, which no frontend refuses today:

- With the shipped RBAC plus the development cluster's workload grant, the operator's dry-run was forbidden to patch its own CRDs and nothing was applied, but the operator had already added its cleanup finalizer to its own instance.
- With cluster-admin granted, the operator adopted all 19 objects in place and became their co-manager. Re-running the CLI then only edited the spec and waited for the operator: the escape hatch "re-run install" no longer existed.
- Deleting that self-owned instance, which step 8 had set to `spec.prune: true`, made the operator prune its own Deployment, ServiceAccount, Service and manager role and die mid-cleanup. The record stayed in deletion on a finalizer only the dead operator could clear, two bindings were left pointing at deleted objects, and an operator-managed fixture was orphaned with its finalizer set. The only way back was removing the finalizer by hand and re-running the CLI apply.
- While the instance stayed CLI-owned, deleting it and re-running install brought the operator back, and the operator then finished a fixture's pending cleanup (step 7).

**Source:** User decision 2026-10-04: "Who owns the operator's own ModuleInstance after opm operator install?" = "CLI-owned forever" (the operator never reconciles itself; handoff refuses the operator's own instance). The contract kind and R1, R2: review finding 2026-10-04, stating the owner's decision as requirements. R3 and the out-of-scope transfer: user decision 2026-10-04 (round 2): "Rmove the handoff feature from these plans. I will handle that in another session".

### D5: The module's `#config` is the operator's tuning surface

**Kind:** contract

**Depends:** 0006:D19, 0021:D2

**Decision:** Everything a platform team tunes on the operator is a value of its instance, declared in the module's `#config`: the repository of the operator image, so a mirror can serve it, the registry mapping the operator resolves modules through, the default service account the operator applies as, the container resources, the replica count, and additional controller arguments for anything the schema does not type. The instance's values are the one authoritative render input (0006:D19), so they are recorded on the instance. Re-running install, for the same or another module version, renders with the recorded values and changes only what the user changes in that run. A reinstall never resets a value to its default. An install whose recorded values the target module version does not accept is refused before any object changes. The registry mapping, being a value, is readable from the instance by anyone allowed to read it, which is what lets a client see where the operator is configured to pull modules from.

The image's tag and digest are not values. The operator's instance always runs the image its module version names, by tag and digest (D1:R10). A recorded tag or digest would survive an upgrade under R2, keep the earlier binary running under a record that names the new version, and leave D3:R10's wait for the new release unanswered.

**Requirements:**

- R1: A user can set the operator image's repository, the registry mapping the operator resolves modules through, its default applier service account, its container resources, its replica count and additional controller arguments as values of the operator's instance.
- R2: Re-running install, for the same or another module version, keeps every recorded value the user did not change in that run.
- R3: An install whose recorded values the target module version does not accept changes no object and names each rejected value.
- R4: The registry mapping configured for the operator is readable from its instance by anyone allowed to read that instance.
- R5: Pointing the image repository value at a mirror that holds the release's image is sufficient for the operator to run from the mirrored image.
- R6: The operator's Deployment runs the image of the instance's module version; no recorded value keeps an earlier release's image across an upgrade.

**Alternatives considered:**

- **Keep the arguments as post-install patches.** The state this entry replaces. Not chosen: the install guide itself documents that every reinstall drops them, which is Gap 1 in 01-problem.md.
- **Type only the image and the registry mapping.** Not chosen: a partial map keeps the trap for every argument left out, and the default service account is the one whose loss strands every instance.
- **Type the image tag and an optional digest as values (previously adopted).** Not chosen after review: a recorded value survives reinstall (R2), so a pinned tag or digest outlives a module upgrade, the record names a release the cluster does not run, and the claim that the running release is a field of the record becomes false.
- **Only free-form extra arguments.** Not chosen: nothing would be validated, and a mapping a client needs to read (R4) would be buried in an argument string.

**Rationale:** A tuning surface that lives on the instance survives upgrades by construction, because the upgrade renders from the instance. Under 0021:D2 the same schema becomes the operator's compatibility surface, so removing a tuning value is a breaking release that a consumer can see coming. R4 makes the configured mapping visible to a client that needs to know where the operator pulls modules from. It is the configured mapping, not proof of what the operator resolves with: the operator reports no mapping of its own, and a hand edit of the live Deployment is corrected by nobody until the next install (05-risks.md).

**Measured 2026-10-04:** [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) rendered every value of R1 into the Deployment through the catalog's workload (the image without a digest, two replicas, the registry mapping and default service account as controller arguments, two extra arguments after them, and the given resources). [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) set the registry mapping as a value and the operator resolved modules through two plain pull-through mirrors with it. Neither experiment exercised R2 or R3: both re-ran install from an instance file that already held the values, so whether a reinstall keeps values the user does not restate is untested. Neither exercised R5: the image came through a node-level registry mirror, not through the image value.

**Source:** Supervisor seed 2026-10-04, from the install guide's documented reinstall trap (`opm-operator/docs/site/start/install-the-operator.md`) and the controller's arguments (`opm-operator/cmd/main.go`), both read 2026-10-04. The field list is a supervisor default, not yet confirmed by the owner. The repository-only image value and R6: review finding 2026-10-04, supervisor default.

**Revised:** 2026-10-04: the image tag and digest stopped being values, R4 narrowed to the configured mapping and R6 added after review.

### D6: Platform seeding and the CLI user role stay outside the module

**Kind:** scope

**Depends:** 0006:D12, 0006:D22, 0006:D23

**Decision:** Two things install does today stay install steps and do not become part of the operator module. The cluster Platform is still seeded by install with a create that leaves an existing Platform untouched (0006:D12, 0006:D22). The opt-in role that lets a non-admin CLI user write instance status (0006:D23) is still created by install on request, on the CRDs-only path as well as the full one.

**Requirements:** none (boundary; seeding and the opt-in role keep their requirements under 0006:D12, 0006:D22 and 0006:D23)

**Alternatives considered:**

- **Render the Platform as an object of the operator module.** Not chosen: the operator owns the Platform singleton (0006:D12), and an object in a CLI-owned instance's inventory is the CLI's to apply, change and delete. The Platform would have two owners, and deleting the operator's instance would delete the Platform every other instance renders against.
- **Make the user role a value of the module.** Not chosen: the CRDs-only path creates the role and writes no instance (D3:R7), so the role cannot live in an instance's inventory.

**Rationale:** Both objects have owners other than the operator's instance. Keeping them out keeps the instance's inventory a list of exactly what the operator release installs.

**Measured 2026-10-04:** in [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) the Platform was seeded with a create after the instance apply, and the operator generated it and reported it Ready. The seeded Platform then changed what the next install rendered against, which D11 removes.

**Source:** Supervisor seed 2026-10-04, from 0006:D12 ("the operator always owns the singleton") and the CRDs-only form of 0006:D32.

### D7: The operator module release follows core, the catalog and the operator

**Kind:** policy

**Decision:** The module's pins on the core schema and on the first-party catalog are user-facing pins: every user who installs the module receives them, so they belong to the pin class the workspace release rules release against. The operator module, not the operator binary, is therefore a downstream of core and of the catalog, and it is also a downstream of the operator binary, whose image it references (D1). The operator binary stays a downstream of the kernel library only. A core or catalog release the module adopts produces a module release; an operator release is followed by a module release that moves the image reference; and the CLI's pin moves to the new module version, as it moves to a new operator release today. The workspace's release tiers and pin classes state where the module release sits, between the operator and the CLI, and the release gate that refuses a development pin in a module users receive covers the operator module.

The workspace rules that key on the embedded manifest change with it. The CLI's tier row and its shipped pin become the operator module version and the content digest that anchors it (D1:R14), instead of the embedded manifest and its version constant. The CLI's release-pin check (G1) stops comparing the embedded manifest's image tag with that constant and refuses instead a pinned module version that is not a published module release or whose content digest differs from what that release published. The operator-embed evidence label (G4) and the CI job meant to retire it keep their purpose with a new subject: a change to the CLI's pinned operator module version, installed through the module path on a cluster. The documentation site's version is still the shared CLI and operator `MAJOR.MINOR` (0021:D10), so the site reads the operator version the CLI's pinned module deploys (D1:R11) instead of the removed constant.

**Requirements:** none (release posture; the tiers and gates it changes are workspace release rules, not consumer-observable contracts)

**Alternatives considered:**

- **Treat the module's core and catalog pins as test-only and hold them.** Not chosen: users receive these pins with the module, so a held pin ships a catalog no release was tested against.
- **The operator release publishes the module and adopts its pins (previously adopted).** Every core or catalog adoption by the module produced an operator release, with no change to the binary. Not chosen once the owner gave the module a train of its own (D1): the adoption now produces a module release, and the operator binary releases only when its code or its library pin changes.

**Rationale:** A pin users receive is a release input, and the release process exists to make sure every such input has been released against. Putting the module between the operator and the CLI keeps each release unit's inputs to what it actually ships. The cost is one more release unit in the cascade; the alternative is an operator module whose dependencies nobody chose, or an operator release for every catalog bump.

**Measured 2026-10-04:** the workspace release documentation lists the operator in the tier that ships against the kernel library only, and its only shipped pin is the library in its Go module (`RELEASING.md` at the workspace root, read the same day). The same file keys the CLI's tier row and shipped pin on the embedded `install.yaml` and `PinnedOperatorVersion`, G1 compares that constant with the embedded image tag, and G4 and its replacement job `add-embedded-operator-e2e-job` trigger on the constant. The documentation site's version resolver reads `PinnedOperatorVersion` at each CLI tag (`opmodel.dev/site/scripts/resolve-versions.sh`, `opmodel.dev/README.md`, `opmodel.dev/AGENTS.md`).

**Source:** Supervisor seed 2026-10-04. The G1, G4 and documentation-site paragraph: review finding 2026-10-04. The module as a release unit of its own between the operator and the CLI: user decision 2026-10-04 (round 2), "Module version = operator version ... Which rule wins?" = "Separate module version".

**Revised:** 2026-10-04: the module, not the operator binary, became the downstream of core and the catalog after the owner gave it its own train.

### D8: The first module install migrates an operator installed from a manifest

**Kind:** contract

**Depends:** 0012:D8

**Decision:** The first module install on a cluster whose operator was installed from an earlier release's manifest, by an earlier CLI or with kubectl, migrates that operator into the new instance. The migration is install's own rule, not a general override, and it does three things and nothing else:

- **Adopts what it can prove.** Install takes into the instance exactly the objects it can prove belong to an earlier operator release: an object whose kind and name are those of an object in an earlier release's manifest, that carries the labels that manifest set on it where it set any, and that carries no OPM instance identity. It admits them through the apply guard's one override, the per-object adopt annotation naming the adopting instance (0012:D8), which install sets on those objects and no others. The guard still refuses every other foreign object as it does for any instance, and install offers the user no override of its own, so this reads within 0012:D8:R3 and does not amend 0012:D8.
- **Recreates the Deployment once.** The module's Deployment selector differs from the manifest's (D2), and Kubernetes never lets an apply change a selector, so install deletes the earlier Deployment and the instance creates it again. The controller is down from the delete until the new pod serves. The workloads of the instances it manages are not touched, and the CRDs, the custom resources under them and the Namespace are never deleted.
- **Deletes the superseded bindings.** The module's bindings take catalog-derived names (D2:R10), so install deletes the earlier manifest's three role bindings that they replace, and no binding of the earlier manifest is left granting rights nothing records.

Every other object of the earlier manifest the module does not render is named in install's report and left in place. Every check that can refuse runs first (D3), so a migration that refuses leaves the earlier operator as it was. An operator installed with kubectl from a manifest rendered from the module (D2:R9) already carries the instance's identity and the module's selector, and needs neither step.

**Revised:** 2026-10-04: the migration recreates the Deployment and deletes the old bindings after the owner chose the catalog path; install sets the adopt annotation itself (OQ3); R1 and R3 retired, R6 to R10 added.

**Requirements:**

- R1: (retired, 2026-10-04)
- R2: Custom resources stored under the operator's CRDs are unchanged by the migration.
- R3: (retired, 2026-10-04)
- R4: An operator installed with kubectl from a manifest rendered from the module is taken into the instance by install with no step on any object by the user.
- R5: A migration install that refuses leaves the earlier operator running and every object of the earlier manifest unchanged.
- R6: Installing the module over an operator installed from an earlier release's manifest deletes no object of that operator except its Deployment and the role bindings R7 names, and records every object the module renders in the new instance's inventory.
- R7: The migration deletes the earlier manifest's role bindings that the module's bindings replace, and leaves no role binding of the earlier manifest in the cluster.
- R8: The migration adopts only objects whose kind, name and labels match an object of an earlier operator release's manifest and that carry no OPM instance identity; every other existing object the render names is refused under 0012:D8 as for any instance, and install offers no override of its own.
- R9: An object of the earlier manifest that the module does not render, other than the role bindings R7 deletes, is named in install's report and left in place.
- R10: The migration changes no object recorded in the inventory of any other ModuleInstance.

**Alternatives considered:**

- **Keep the manifest's names and Deployment selector so the migration recreates nothing (previously adopted).** With the manifest-shaped objects of experiment 01's variant, every object was taken over in place. Not chosen once the owner chose the catalog path (D2), which accepts a one-time Deployment recreate and the deletion of three bindings, allowed on the beta line as a declared break.
- **The user annotates each object, with install printing the commands.** Not chosen: every cluster running OPM takes this migration once, and nineteen hand-made annotations are a step most users would get wrong or skip.
- **A one-off migration subcommand that adopts only when the user runs it.** Not chosen: a second command for a step every first module install needs, and install would still have to refuse and point at it.
- **Uninstall the old operator and install the module fresh.** Not chosen: it deletes and recreates the controller, and the uninstall refuses while any instance carries the cleanup finalizer (0006:D34), so a cluster in use cannot take that path without orphaning its instances.
- **A command-wide force flag that takes every conflicting object.** Not chosen: 0012:D8 rejected it, because it takes objects the user did not mean to take.

**Rationale:** Every cluster running OPM today runs an operator installed from a manifest, so the first module install is always a migration. A migration that recreates CRDs would delete every instance on the cluster, so not touching the CRDs, the Namespace and the managed workloads is the requirement that matters most; the controller's own Deployment is replaceable, and a short gap in reconciliation is what the owner accepted for the catalog path. Limiting the adoption to what install can prove came from an earlier release keeps 0012:D8's guard whole: nothing a user created is adopted by accident.

**Measured 2026-10-04:** 11 of the embedded manifest's 19 objects carry `app.kubernetes.io/managed-by: kustomize`; the other 8 (the four CRDs, the ClusterRoles `manager-role`, `metrics-auth-role` and `metrics-reader`, and the ClusterRoleBinding `metrics-auth-rolebinding`, each under the `opm-operator-` prefix) carry no managed-by label. None carries an OPM instance identity (`cli/internal/operator/dist/install.yaml`), so under 0012:D8 each is a foreign object to the new instance. The adopt annotation is not implemented in either frontend (read from the CLI and library on 2026-10-04).

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 6,** installing a catalog-path module, the shape D2 now requires, over today's `opm operator install`:

- The CLI's apply refused at the first object without an OPM managed-by label (`cli/internal/inventory/stale.go`, read 2026-10-04). It neither adopted nor duplicated anything. The CRD step that ran before it had already relabelled the four CRDs (D3:R12).
- With every old object relabelled as OPM-managed, which stands in for the adoption of R8, 18 objects were taken over in place with their uids, and the earlier manifest's labels were dropped cleanly because both installs apply as field manager `opm-cli`. A manifest applied with client-side `kubectl apply` is owned by another field manager, so that result does not carry over to it; it is not measured (04-graduation.md). The Deployment failed as immutable (its selector changed), so no instance record was written.
- After deleting the Deployment by hand the install completed in 16.3 s, delete included, but the three bindings of the earlier manifest stayed in the cluster unrecorded beside the module's renamed ones. R6 and R7 make install do both steps itself.

**Source:** Supervisor seed 2026-10-04. R5: experiment outcome `0028/experiments/02-cli-bootstrap-install/` (2026-10-04). The Deployment recreate and the binding delete (R6, R7): user decision 2026-10-04 (round 2), "Which shape?" = "Catalog abstractions (Recommended)" ("install's one-time migration recreates the operator Deployment (controller blips, workloads untouched) and deletes the 3 old *-rolebinding objects"). The adoption rule (R8): OQ3 resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.

### D9: Upgrade and uninstall act on the operator's instance

**Kind:** contract

**Depends:** 0006:D34

**Amends:** 0006:D34

**Decision:** Upgrading the operator is installing another module version over the existing instance: objects whose render changed are applied, objects the new version no longer renders are removed, and the CRDs and the Namespace are never removed. Uninstalling the operator deletes its instance through the CLI. This amends 0006:D34. What survives: uninstall refuses while any ModuleInstance in the cluster carries the operator's cleanup finalizer, its explicit override removes that finalizer only and orphans those instances' workloads, and the CRDs and the Namespace are never deleted. What changes: the set uninstall deletes is the operator instance's recorded inventory, not the documents of a manifest built into the CLI, so an object an older release installed is removed too. On a cluster with no operator instance record, such as one whose operator was applied with kubectl, uninstall deletes nothing: it refuses and names install, which records the running operator (D8), as the step before uninstall.

Because the operator's instance is an ordinary CLI-owned instance, the CLI's generic instance delete can reach it too. That path keeps the same guard: deleting the operator's instance by any CLI command either meets uninstall's finalizer refusal or is refused with a pointer to uninstall.

**Revised:** 2026-10-04: R5 added after experiment 02 deleted the operator's instance past an armed finalizer. R6 added after review found uninstall undefined for an operator with no record.

**Requirements:**

- R1: Upgrading to another module version removes every object the previous version rendered and the new one does not, except CRDs and the Namespace.
- R2: Uninstall refuses while any ModuleInstance in the cluster carries the operator's cleanup finalizer, unless the user explicitly chooses to remove that finalizer and orphan those instances' workloads.
- R3: Uninstall removes every object recorded in the operator instance's inventory except CRDs and the Namespace, and then removes the instance record.
- R4: Uninstall removes no object the operator instance's inventory does not record.
- R5: No CLI command deletes the operator's instance while any ModuleInstance in the cluster carries the operator's cleanup finalizer, unless the user makes the same explicit choice R2 offers.
- R6: Uninstall on a cluster with no operator instance record removes no object and names install as the step that records the operator.

**Alternatives considered:**

- **Keep uninstall working from a list built into the CLI.** Not chosen: Gap 2 in 01-problem.md. The list describes the CLI's release, not the cluster's.
- **Delete the CRDs on uninstall once no instance remains.** Not chosen: a CRD delete removes every custom resource of its kind. 0006:D5 and 0012:D1:R3 both forbid an automatic CRD delete, and this entry does not reopen them.

**Rationale:** Once the operator has an inventory, the inventory is the only honest answer to "what did install put here". The finalizer guard of 0006:D34 protects the instances the operator manages, which do not change when the operator's own record does.

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/):**

- Upgrade from module 0.1.0 to 0.2.0 re-applied every non-CRD object (their version label changed) and left the CRDs unchanged. Both versions render the same object set, so R1's removal of a dropped object was not exercised.
- `opm instance delete` of the operator's instance deleted 14 objects and left the Namespace and the four CRDs ("CRDs and Namespaces are never deleted"), as R3 asks. It did not check finalizers: an operator-managed fixture still carried the cleanup finalizer and the delete went ahead silently. Today's uninstall guard (`cli/internal/operator/uninstall.go`, `CheckFinalizerGuard`, read 2026-10-04) has no counterpart on that path, hence R5.
- The orphaned fixture's later delete wedged in deletion until install was re-run; the restored operator then finished its cleanup.

**Source:** Supervisor seed 2026-10-04 (seed D4's uninstall clause, split out because it carries requirements and D4 is a policy). R5: experiment outcome `0028/experiments/02-cli-bootstrap-install/` (2026-10-04). R6: review finding 2026-10-04, supervisor default not yet confirmed by the owner.

### D10: Install refuses a target version the CLI cannot drive or the cluster cannot safely take

**Kind:** contract

**Depends:** 0021:D9

**Decision:** Before it changes anything, install checks the module version it is about to install against three rules. The operator version a module deploys is readable from the module (D1:R11), so these checks run on the target, not on what the cluster runs.

- **No operator newer than the CLI.** Install refuses a module whose operator `MAJOR.MINOR` is above the CLI's own, and names upgrading the CLI as the fix. This is 0021:D9's ceiling applied to the target version: a CLI that installed such an operator could drive none of its apply commands afterwards.
- **No silent downgrade.** Install refuses a module version lower than the one recorded on the operator's instance, unless the user explicitly asks for a downgrade.
- **No CRD that stops serving a version the cluster serves.** Install refuses, whether or not a downgrade was asked for, a module version whose CRDs no longer serve a version the cluster's CRD of the same name serves. The same check guards an upgrade that removes a served version.

Each refusal names the module version and the rule it failed, and changes nothing (D3:R12). The ceiling on the running operator does not refuse install (D3:R16); these rules replace it for install.

**Requirements:**

- R1: Install refuses a module version whose operator `MAJOR.MINOR` is above the CLI's own, before any object changes, and names upgrading the CLI as the fix.
- R2: Install refuses a module version lower than the one recorded on the operator's instance unless the user explicitly asks for a downgrade.
- R3: Install refuses a module version whose CRDs do not serve every version that the cluster's CRDs of the same names serve, even when the user asked for a downgrade.
- R4: Each refusal under R1 to R3 names the module version and the failed rule, and changes no object.

**Alternatives considered:**

- **Warn and install a newer operator anyway.** Not chosen: the user is left with an operator none of the CLI's apply commands will drive, and the only way out is the CLI upgrade the refusal would have named.
- **Allow it, as selecting a newer manifest does today.** Not chosen for the same reason; today's manifest selection has no check because the CLI could not read an operator version from a manifest before applying it, which the module now provides.
- **Allow any downgrade and rely on the CRD check alone.** Not chosen: a downgrade can also drop `#config` values and controller behaviour a running workload relies on, and an older CLI re-running install over a newer operator (D3:R16) should not downgrade by accident.
- **Let an explicit downgrade override the CRD check.** Not chosen: a CRD that stops serving a version leaves the custom resources stored under it unreadable to clients of that version, and a CRD change is the highest-ranked risk in 05-risks.md. Prior art: the CRD upgrade-safety preflight of OLM v1.

**Rationale:** Install is the one recovery path (D4), so it must not be able to install something the CLI then cannot drive or that strands the cluster's stored resources. Reading the operator version from the module makes the first check possible before anything is applied, which the embedded manifest never allowed.

**Source:** OQ4 and OQ6 resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.

### D11: Install renders the operator module against its own dependency pins

**Kind:** contract

**Depends:** 0006:D11

**Amends:** 0006:D11

**Decision:** Install, the CRDs-only form included, always renders the operator module against a platform generated from the module's own dependency pins, never against the cluster Platform. This amends 0006:D11. What survives: every other instance the CLI renders still takes its platform by 0006:D11's precedence, and offline builds still never read the cluster. What changes: for the operator's own instance install skips that precedence, so a Platform that is missing, unhealthy or subscribed to other catalog releases neither changes nor refuses the operator's render, and repairing the operator never depends on the Platform it serves.

**Requirements:**

- R1: Install renders the same objects for the same module version and values whether or not the cluster holds a Platform, and whatever that Platform subscribes to.
- R2: A cluster Platform that is missing, not Ready or unreadable does not refuse the operator's render.

**Alternatives considered:**

- **Render against the cluster Platform once one exists, as for every other instance.** Not chosen: the Platform may be why the operator is being repaired, and a Platform on another catalog release re-renders the operator's own install on the next reinstall with no change by the user. One rule for every instance is worth less than a recovery path that works when the Platform does not.

**Rationale:** D4 makes install the recovery path, and a recovery path cannot depend on the state it repairs. The module's own pins are the release-tested inputs (D7), so rendering against them also makes every install of one module version produce the same operator.

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 4:** the first install rendered against the module's own pins ("cluster Platform not used … rendering against the instance's own deps"), and the reinstall after the Platform was seeded rendered through the cluster Platform. The render digest stayed the same only because the Platform subscribed to the same catalog release (4.5.2) the module pins. The CLI's precedence is specified in its `platform-resolution` spec: flag, then cluster Platform, then local default.

**Source:** OQ5 resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.

### D12: The catalog carries what the operator module needs

**Kind:** contract

**Decision:** Two catalog changes are prerequisites of the operator module, because D2 renders the controller through the catalog and the catalog cannot yet carry it:

- **A seccomp profile.** The catalog's workload security context gains a seccomp profile at pod and at container level, rendered into the pod spec. Without it a catalog-rendered pod cannot satisfy the Kubernetes Pod Security `restricted` profile, which the operator's pods must (D2:R8), and neither can any other module's.
- **A role with no subjects.** The catalog's role resource accepts a role with no subjects and renders the role alone, with no binding. The operator ships five ClusterRoles for administrators to bind to users, and a role resource that requires a subject cannot express them.

Experiment 01 also hit four rough edges in the catalog, each a render failure reported only as "N errors in empty disjunction". They are catalog follow-ups, not prerequisites of this entry: a CPU quantity written as a whole-number string passes the schema but fails the workload transform; the service account's optional automount flag is read unguarded, so leaving it unset fails the render; the workload blueprint requires a restart policy and an update strategy that have API defaults; and an empty-dir volume needs its read-only flag set explicitly.

**Requirements:**

- R1: A module author can set a seccomp profile on a catalog workload at pod level and at container level, and the rendered pod carries it.
- R2: A catalog role with no subjects renders as the role alone, at namespace or cluster scope, with no binding.
- R3: A catalog role with subjects renders exactly as before R2 holds.

**Alternatives considered:**

- **Keep the seccomp profile and the unbound roles out of the catalog and write those objects raw in the operator module.** Not chosen: the owner chose the catalog path for the showcase (D2), and a security context that cannot reach `restricted` is a gap every module meets, not one the operator should route around.
- **Fix the four rough edges as prerequisites too.** Not chosen: the operator module can be written around each of them, as experiment 01 was, and holding the entry on them would tie it to catalog work it does not need.

**Rationale:** The module is only as idiomatic as the catalog lets it be. Landing the two changes in the catalog first makes the operator's module the proof that the catalog carries a production controller, and leaves the change available to every module author.

**Measured 2026-10-04:** the catalog's role resource requires at least one subject and its transformer always renders a binding beside the role (`catalog_opm/src/resources/v1beta1/role.cue`, `catalog_opm/src/transformers/role_transformer.cue`, read the same day). The catalog has no seccomp field at either level ([`experiments/01-operator-module-render/`](experiments/01-operator-module-render/), which also records the four rough edges).

**Source:** User decision 2026-10-04 (round 2), "Which shape?" = "Catalog abstractions (Recommended)" ("Add seccompProfile to catalog_opm first"). The role with no subjects and the list of follow-ups: supervisor defaults 2026-10-04, after reading the catalog's role resource.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
