# Design Decisions: The Operator Ships as an OPM Module

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, a changed choice is an in-place edit to the existing `DN`, with an evidence-backed old position folded into *Alternatives considered*. Once `accepted`, bodies are protected and a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract`, `policy` or `scope`) and passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Mechanism decisions belong in the implementing OpenSpec change in the target repo.

Both experiments concluded on 2026-10-04 and are folded in. [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) backs D2 and refuted its first form: the catalog's workload and role resources change three binding names, the Deployment's selector and the pod's seccomp profile, so D2 now requires the earlier manifest's names, selector and security posture. [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) backs D3, D4, D8 and D9: the two-step install, reinstall and upgrade held; a refused install had already changed the CRDs, `--wait` returned before the operator reconciled, and deleting the operator's instance with `opm instance delete` skipped the finalizer guard, so D3 and D9 gained requirements.

---

## Decisions

### D1: The operator release publishes the operator as a module

**Kind:** contract

**Depends:** 0021:D10

**Decision:** The operator is published as the module `opmodel.dev/modules/opm_operator`, major v1, from the operator's own repository, by the same release that builds the operator image. The module's version is the operator release's version: one release, one number. The module refers to the image of the same release by its version tag. Version-named registry tags are never re-pointed (0021:D10), so the tag names the same image for as long as the release exists. The module artifact is signed and attested by the same release, with the same kinds of signature and provenance the image carries. A release is not made public until its module is published.

**Requirements:**

- R1: Every operator release publishes the module `opmodel.dev/modules/opm_operator` at the release's own version, and no operator release becomes public without it.
- R2: The major of the module path equals the major of the operator release.
- R3: The module's default image reference names the operator image of the same release by its version tag.
- R4: The module artifact of a release carries the same kinds of signature and provenance attestation as the operator image of that release.
- R5: Only the operator's own release publishes under the module's path.

**Alternatives considered:**

- **Publish the module from the first-party module fleet.** Not chosen: the fleet releases on its own train, so the module would trail the operator release it describes, and the CLI would have to pin a module version and an operator version that can disagree.
- **An independent version train for the module.** Not chosen: two numbers for one install produce a compatibility matrix nobody asked for. The test fixtures the operator publishes run on their own versions, which is right for fixtures and wrong for the product.
- **Pin the image by digest in the published module.** Not chosen as the default: the digest exists only after the image is built, which is after the release's content is committed, so it can only be stamped into the artifact at publish time, and then the published module differs from the tagged source tree. An immutable version tag gives the same guarantee within OPM's own registry policy. A digest stays available as a value (D5).
- **Publish under the test namespace `testing.opmodel.dev`.** Not chosen: that prefix holds test fixtures and is documented as not a staging environment.

**Rationale:** The owner chose a registry pull for install, which needs a published module at an address the CLI can pin. Publishing it from the release that builds the image is the only placement where the module and the image cannot describe different releases. The path follows the first-party module convention: one flat snake-case leaf under `opmodel.dev/modules/`, which the CLI's publish gate already admits.

**Measured 2026-10-04:** the operator's release workflow already installs the CLI and publishes its test fixture modules with it, between the image job and the job that makes the release public (`opm-operator/.github/workflows/release.yml`, jobs `image-release`, `publish-examples`, `publish-release`). The publish gate admits first-party paths of the form `opmodel.dev/modules/<leaf>` (`cli/internal/publish/gates.go`, read the same day). [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) could default the image by digest only because the beta.5 image already existed when the module was written, which is the ordering problem the tag-only default avoids. Its local registry accepted a re-push of the same module version, so R1's "one release, one number" relies on the registry refusing re-pushes, as GHCR's version tags do under 0021:D10 (entry 0029 OQ9 asks the same of every module).

**Source:** User decision 2026-10-04: "Where does opm operator install get the operator module?" = "Registry pull (Recommended)" (pull opmodel.dev/modules/opm_operator from GHCR; air-gapped users point --registry at a mirror; drop the embedded install.yaml; the CLI pins a module version). Tag-only image reference and the signing clause: supervisor defaults 2026-10-04, not yet confirmed by the owner.

### D2: The module is the authority for the operator's install shape

**Kind:** contract

**Depends:** 0021:D2, 0021:D4

**Amends:** 0021:D4

**Decision:** The operator module is the one source of the operator's install shape. Its CRDs and the controller's cluster RBAC are generated from what the controller's own code declares (its CRD schemas and its permission markers), and a release whose module disagrees with them is refused before anything is published. The release keeps publishing an install manifest, and that manifest is the module's render at its default values, so a kubectl-only install stays possible and cannot differ from the module. The objects keep the names an operator installed from an earlier manifest has, so tooling, documentation and the migration of D8 see the same operator. The controller Deployment keeps the earlier manifest's pod selector, which Kubernetes never lets an apply change, so no move between a manifest install and a module install, or between two module versions, has to delete the operator's Deployment. The operator's pods keep the security posture the manifest gave them: they satisfy the Kubernetes Pod Security `restricted` profile.

These three properties bind the module's authoring. Where a first-party catalog resource renders an object with another name, another selector or a weaker security context, the module writes that object in the earlier manifest's shape instead. On 2026-10-04 that is the controller's workload and all its RBAC (experiment 01, variant).

This amends 0021:D4. What survives: the install manifest is still not an artifact class of its own. What changes: the manifest is now a render of the operator module, and the operator module falls in the module class, with its `#config` schema as the compatibility surface 0021:D2 assigns to every module. An operator release that narrows the values `#config` accepts is therefore a breaking release of the operator.

**Revised:** 2026-10-04: R7 and R8 added and the authoring rule stated after experiment 01 refuted the catalog-first shape.

**Requirements:**

- R1: For every operator release, the CRDs its module renders are identical to the CRD schemas the controller of that release serves. Validated by [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/): all four CRD specs rendered equal to the controller's generated YAML.
- R2: For every operator release, the cluster RBAC its module renders for the controller grants exactly the permissions the controller of that release declares it needs.
- R3: A release whose module fails R1 or R2 publishes nothing. Experiment 01's regenerate-and-diff check failed on one added RBAC verb and one added CRD short name, and passed against the operator's own generated tree.
- R4: Every operator release publishes an install manifest equal to its module's render at default values, and applying that manifest with kubectl yields a running operator.
- R5: The operator's Namespace, Deployment, ServiceAccount, RBAC objects and CRDs have the same names whether the operator was installed from the module or from an earlier release's manifest. Experiment 01: the catalog's role resource renamed three bindings; the variant kept all 19 names.
- R6: An operator release whose module's `#config` stops accepting a value the previous release accepted is a breaking release of the operator.
- R7: Installing the module over an operator installed from an earlier release's manifest, upgrading between module versions, and applying an earlier release's manifest over a module install never require deleting the operator's Deployment.
- R8: The operator's pods satisfy the Kubernetes Pod Security `restricted` profile, as the pods of the earlier manifest do.

**Alternatives considered:**

- **Render the controller's workload and RBAC through the catalog's workload and role resources (previously adopted as the default).** Not chosen after [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/). The catalog adds the instance and component labels to every workload selector, so the Deployment's selector changes and the first module install over a manifest-installed operator fails with "field is immutable" unless the Deployment is deleted first ([`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 6). The catalog's role resource names each binding after its role, which leaves the three bindings of the earlier manifest behind unrecorded. The catalog's security context has no seccomp field, so the pod loses `seccompProfile: RuntimeDefault` and fails the `restricted` profile. Writing those objects in the manifest's shape reached spec parity with only label differences. The cost is that the operator's own module exercises the catalog's CRD and Namespace resources but not its workload abstractions; when the module may move its workload onto them is OQ12.

- **Keep the kustomize tree as the authority and generate the module from its render.** Not chosen: the module would be a passthrough of bytes with no typed configuration of its own, and the tuning surface of D5 would have to be patched into kustomize output. The kustomize tree stays where it is useful, as the source of what the controller's generators emit.
- **Drop the install manifest and make the module the only install path.** Not chosen: a kubectl-only install is a documented path, and some users apply the manifest from their own GitOps tooling. Rendering the manifest from the module keeps that path at the cost of one release step, and it cannot drift.
- **Copy the CRD and RBAC YAML into the module by hand.** Not chosen: the first-party modules that carry CRDs re-vendor them by a documented manual recipe with no check, so a module and its controller can disagree without anyone seeing it. The operator's CRDs are the contract the CLI writes against, so drift there is a correctness bug, not a stale copy.

**Rationale:** One authority removes the gap in 01-problem.md where the committed manifest, the release asset and the CLI's copy are compared by nothing. Generating from the controller's own declarations keeps the controller's code as the place a permission or a field is decided. Keeping the names stable is what lets every existing reader of the operator (the CLI's readiness check, documentation, the migration) stay correct.

**Measured 2026-10-04:** the kernel loads only the `.cue` files of a module tree (`library/opm/internal/sourcetree/sourcetree.go`), so a module cannot carry the controller's CRD YAML as files and must hold it as CUE. The first-party modules `cert_manager` and `metallb` hold their CRDs as CUE generated by `cue import`, with a README recipe and no drift check (`modules/cert_manager/README.md`, `modules/metallb/README.md`). The catalog's `objects` resource renders an object under the name written, which is how an object that no idiomatic resource expresses (an unbound ClusterRole) keeps its name (`catalog_opm/src/resources/v1alpha1/objects.cue`).

**Measured 2026-10-04 by [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/)** (operator v1.0.0-beta.5, core v2.0.0-beta.2, catalog opm 4.5.2, CLI 1.0.0-beta.7):

- The module renders all 19 objects with no cluster and no cluster Platform. Every name derives from the instance's name and namespace: instance `opm-operator` in `opm-operator-system` reproduces the manifest's names, because the manifest's name prefix equals `<instance>-`. The CRDs do not vary with the instance, so the module is a cluster singleton (D3:R11).
- The CRDs are generated from the controller's YAML into CUE and embedded whole. Every schema feature the operator's CRDs use survived (CEL validations, preserve-unknown-fields, list-map keys, the status subresource, printer columns). The catalog's CRD resource cannot carry `conversion` or `preserveUnknownFields`; embedding the whole spec makes such a field refuse the render instead of vanishing, so a future multi-version CRD needs a catalog change first (05-risks.md).
- Catalog path: three binding names, the Deployment selector and the seccomp profile differ (the alternative above). Objects written in the manifest's shape: the same 19 names, no spec differences, only labels (the kustomize labels give way to OPM's managed-by, module and instance labels).
- Cost: 5.7 s and 507 MB peak memory cold, 2 to 4 s warm. The module is 1,977 lines of CUE, 1,713 of them generated.

**Source:** Supervisor seed 2026-10-04, following from the owner's registry-pull decision of the same day. The 0021:D4 amendment follows 0021:D2 ("A module's compatibility surface is its `#config` schema"). R7, R8 and the authoring rule: experiment outcome `0028/experiments/01-operator-module-render/` (2026-10-04), with the selector failure measured by `0028/experiments/02-cli-bootstrap-install/`.

### D3: `opm operator install` deploys the module as a CLI-owned ModuleInstance

**Kind:** contract

**Depends:** 0006:D3

**Amends:** 0006:D5, 0006:D32, 0006:D35

**Decision:** `opm operator install` deploys the operator by installing its module. It obtains the module from the module registry the CLI is configured with, renders it, applies the module's CRDs and waits until they are served, and then applies a CLI-owned ModuleInstance of the module the way any CLI instance is applied. The two steps exist because the instance record is itself a ModuleInstance, which cannot be written before its CRD exists. The CRDs applied in the first step are the module's own render of them, carrying the instance's identity, so the second step records them in the instance's inventory instead of refusing them as foreign objects.

The CLI carries no copy of the operator's manifests. Each CLI release names one default module version, and the user may select another version for a run. A cluster with no access to the public registry installs from a mirror by pointing the CLI's registry mapping at it. The CRDs-only form keeps its meaning: it applies exactly the CRDs of the same render and nothing else, writing no instance record, no workload and no Platform.

The operator's instance is a singleton: it has the same name and namespace on every cluster and every install. The spellings of that name and namespace are fixed by the implementing change and are part of this contract from then on. The module renders the operator's Namespace itself, so install creates it only as an object of the instance and records it.

An install that refuses changes nothing. Every check that can refuse the instance apply, the apply guard of entry 0012 among them, runs before the CRD step, because the CRD step writes the instance's identity onto the CRDs. Install reports success only once the operator release it installed is reconciling, not when its Deployment is merely rolled out: the cluster Platform reports Ready from that release. Every CLI command that needs to know whether the operator is present and serving finds it through the operator's instance record, since the CLI no longer carries the manifest it used to look it up in.

This amends three decisions of entry 0006:

- **0006:D5.** What survives: installs use server-side apply as `opm-cli`, the CLI never deletes CRDs, and instance apply never installs CRDs implicitly but fails with a hint. What changes: the CLI no longer embeds the operator's manifests, and the offline learner path that embedding served is replaced by a registry mirror.
- **0006:D32.** What survives: the `opm operator` command group and its CRDs-only form. What changes: install applies the operator module as an instance instead of applying the documents of an embedded manifest.
- **0006:D35.** What survives: the CRDs are a subset of the one artifact the full install applies, so they cannot drift from it, and install waits until the CRDs are served and the operator has rolled out. What changes: the artifact is the module's render, not an embedded manifest; the pinned manifest and its refresh task go away; selecting another version resolves a module version from the registry instead of downloading a GitHub release asset.

**Revised:** 2026-10-04: R10 tightened and R12 to R14 added after experiment 02.

**Requirements:**

- R1: On a cluster with none of OPM's CRDs, one install run leaves the operator running and recorded as exactly one CLI-owned ModuleInstance of the operator module. Validated by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 1.
- R2: Install writes the instance record only after the module's CRDs are served.
- R3: Every object the module renders, the CRDs and the Namespace included, is recorded in the instance's inventory, and no step of the install refuses an object the install itself applied. Experiment 02: all 19 objects recorded; creating the Namespace outside the module made the instance apply refuse it as a foreign object.
- R4: The CLI obtains the operator module from its configured module registry and carries no copy of the operator's manifests.
- R5: Each CLI release names one default module version, and a user can install any other published version.
- R6: With the CLI's registry mapping pointed at a mirror holding the module and its dependencies, install succeeds on a cluster with no access to the public registry.
- R7: The CRDs-only form applies exactly the CRDs a full install of the same module version applies, and writes no instance record, no workload and no Platform.
- R8: A full install after a CRDs-only install of the same module version records the existing CRDs without recreating them. Experiment 02: the instance apply reported the four CRDs unchanged.
- R9: Re-running install with an unchanged module version and unchanged values changes no live object. Validated by experiment 02, step 4: all 19 objects kept their uid and resourceVersion.
- R10: Install reports success only after the CRDs are served, the operator's Deployment has completed its rollout, and the cluster Platform reports Ready from the operator release just installed.
- R11: A cluster holds at most one operator instance, and it has the same name and namespace on every cluster.
- R12: An install that refuses changes no object in the cluster.
- R13: After a module install, every CLI command that checks for a running operator before it acts finds the operator the install recorded, without a copy of the operator's manifest.
- R14: Install creates no object outside the module's render except the cluster Platform and the opt-in user role of D6.

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
- The CLI's readiness check, which the per-instance delete guard calls, locates the operator through the CRD names and the Deployment name of the embedded manifest (`cli/internal/operator/ready.go`, read 2026-10-04). Dropping the manifest removes that locator, so R13 is a requirement of this decision rather than an implementation detail.
- Install time on a fresh cluster was the same as today's within noise (28.6 to 31.8 s against 28.7 to 30.7 s); render plus CRDs cost 2.3 to 3.5 s of it.
- The operator's module fetches worked unchanged through a plain pull-through mirror of GHCR, which is the mirror path of R6 on the operator's side. The CLI's side of R6 was not measured: the host running the CLI had public access.

**Source:** User decision 2026-10-04: "Where does opm operator install get the operator module?" = "Registry pull (Recommended)" (pull opmodel.dev/modules/opm_operator from GHCR; air-gapped users point --registry at a mirror; drop the embedded install.yaml; the CLI pins a module version). The two-step bootstrap: supervisor brief 2026-10-04, from the CRD gate measured above. R10, R12, R13, R14: experiment outcome `0028/experiments/02-cli-bootstrap-install/` (2026-10-04).

### D4: The operator's own instance stays CLI-owned

**Kind:** policy

**Depends:** 0006:D3

**Decision:** The ModuleInstance that deploys the operator is owned by the CLI for its whole life. The operator never reconciles the instance that deploys it: as a CLI-owned instance it is skipped under 0006:D3. Upgrading the operator is re-running install (D3, D9). The ownership transfer that entry 0029 designs refuses this instance, at both of its ends: the CLI's transfer command and the operator's own refusal to adopt. Entry 0029 carries those refusals and their requirements. Re-running install is the one recovery path for a broken operator, and it needs nothing from the operator.

**Requirements:** none (posture; it is enforced by the owner marker of 0006:D3 and by the transfer refusals entry 0029 states)

**Alternatives considered:**

- **The operator takes over its own instance after the bootstrap**, as Flux does after `flux bootstrap` and as Argo CD does when it manages its own Application. Not chosen by the owner. An operator that owns its own instance prunes its own Deployment and RBAC when the instance is deleted, then waits forever on a cleanup finalizer only it can clear. It needs an applier identity allowed to grant any permission it applies, which is cluster-admin in practice. A broken image cannot render the fix to itself.
- **Allow the transfer, guarded by the same gates as any instance.** Not chosen: the gates prove the operator can pull and apply the instance, not that it can recover from applying itself wrongly. A self-managing operator has no outer layer left to repair it.

**Rationale:** The operator is the one workload whose failure stops every other instance, so its recovery path must not depend on it. Prior art agrees: the Flux Operator does not upgrade itself and is deployed by something else, and Flux's own guidance for a broken self-managed install is to run the bootstrap command again. Keeping the instance CLI-owned makes install that outer layer permanently.

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 8,** flipping the operator's own instance to `owner: operator` by hand, which no frontend refuses today:

- With the shipped RBAC, the operator's dry-run was forbidden to patch its own CRDs and nothing was applied, but the operator had already added its cleanup finalizer to its own instance.
- With cluster-admin granted, the operator adopted all 19 objects in place and became their co-manager. Re-running the CLI then only edited the spec and waited for the operator: the escape hatch "re-run install" no longer existed.
- Deleting that self-owned instance made the operator prune its own Deployment, ServiceAccount, Service and manager role and die mid-cleanup. The record stayed in deletion on a finalizer only the dead operator could clear, two bindings were left pointing at deleted objects, and an operator-managed fixture was orphaned with its finalizer set. The only way back was removing the finalizer by hand and re-running the CLI apply.
- While the instance stayed CLI-owned, deleting it and re-running install brought the operator back, and the operator then finished a fixture's pending cleanup (step 7).

**Source:** User decision 2026-10-04: "Who owns the operator's own ModuleInstance after opm operator install?" = "CLI-owned forever" (the operator never reconciles itself; handoff refuses the operator's own instance).

### D5: The module's `#config` is the operator's tuning surface

**Kind:** contract

**Depends:** 0006:D19, 0021:D2

**Decision:** Everything a platform team tunes on the operator is a value of its instance, declared in the module's `#config`: the operator image (repository, tag and an optional digest), the registry mapping the operator resolves modules through, the default service account the operator applies as, the container resources, the replica count, and additional controller arguments for anything the schema does not type. The instance's values are the one authoritative render input (0006:D19), so they are recorded on the instance. Re-running install, for the same or another module version, renders with the recorded values and changes only what the user changes in that run. A reinstall never resets a value to its default. An install whose recorded values the target module version does not accept is refused before any object changes. The registry mapping, being a value, is readable from the instance by anyone allowed to read it, which is what lets a client see where the operator pulls modules from.

**Requirements:**

- R1: A user can set the operator image, the registry mapping the operator resolves modules through, its default applier service account, its container resources, its replica count and additional controller arguments as values of the operator's instance.
- R2: Re-running install, for the same or another module version, keeps every recorded value the user did not change in that run.
- R3: An install whose recorded values the target module version does not accept changes no object and names each rejected value.
- R4: The registry mapping the operator uses is readable from its instance by anyone allowed to read that instance.
- R5: Pointing the image value at a mirror is sufficient for the operator to run from a mirrored image.

**Alternatives considered:**

- **Keep the arguments as post-install patches.** The state this entry replaces. Not chosen: the install guide itself documents that every reinstall drops them, which is Gap 1 in 01-problem.md.
- **Type only the image and the registry mapping.** Not chosen: a partial map keeps the trap for every argument left out, and the default service account is the one whose loss strands every instance.
- **Only free-form extra arguments.** Not chosen: nothing would be validated, and a mapping a client needs to read (R4) would be buried in an argument string.

**Rationale:** A tuning surface that lives on the instance survives upgrades by construction, because the upgrade renders from the instance. Under 0021:D2 the same schema becomes the operator's compatibility surface, so removing a tuning value is a breaking release that a consumer can see coming. R4 makes the configured mapping visible to a client deciding whether the operator can pull a module, the question entry 0029 asks; what the operator actually resolves with is the operator's own report, which entry 0029 designs.

**Measured 2026-10-04:** [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) rendered every value of R1 into the Deployment (the image without a digest, two replicas, the registry mapping and default service account as controller arguments, two extra arguments after them, and the given resources). [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) set the registry mapping as a value and the operator resolved modules through two plain pull-through mirrors with it. Neither experiment exercised R2 or R3: both re-ran install from an instance file that already held the values, so whether a reinstall keeps values the user does not restate is untested. Neither exercised R5: the image came through a node-level registry mirror, not through the image value.

**Source:** Supervisor seed 2026-10-04, from the install guide's documented reinstall trap (`opm-operator/docs/site/start/install-the-operator.md`) and the controller's arguments (`opm-operator/cmd/main.go`), both read 2026-10-04. The field list is a supervisor default, not yet confirmed by the owner.

### D6: Platform seeding and the CLI user role stay outside the module

**Kind:** scope

**Depends:** 0006:D12, 0006:D22, 0006:D23

**Decision:** Two things install does today stay install steps and do not become part of the operator module. The cluster Platform is still seeded by install with a create that leaves an existing Platform untouched (0006:D12, 0006:D22). The opt-in role that lets a non-admin CLI user write instance status (0006:D23) is still created by install on request, on the CRDs-only path as well as the full one.

**Requirements:** none (boundary; seeding and the opt-in role keep their requirements under 0006:D12, 0006:D22 and 0006:D23)

**Alternatives considered:**

- **Render the Platform as an object of the operator module.** Not chosen: the operator owns the Platform singleton (0006:D12), and an object in a CLI-owned instance's inventory is the CLI's to apply, change and delete. The Platform would have two owners, and deleting the operator's instance would delete the Platform every other instance renders against.
- **Make the user role a value of the module.** Not chosen: the CRDs-only path creates the role and writes no instance (D3:R7), so the role cannot live in an instance's inventory.

**Rationale:** Both objects have owners other than the operator's instance. Keeping them out keeps the instance's inventory a list of exactly what the operator release installs.

**Measured 2026-10-04:** in [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) the Platform was seeded with a create after the instance apply, and the operator generated it and reported it Ready. The seeded Platform then changed what the next install rendered against (OQ5).

**Source:** Supervisor seed 2026-10-04, from 0006:D12 ("the operator always owns the singleton") and the CRDs-only form of 0006:D32.

### D7: The operator release follows core and the catalog

**Kind:** policy

**Decision:** The module's pins on the core schema and on the first-party catalog are user-facing pins: every user who installs the module receives them, so they belong to the pin class the workspace release rules release against. The operator repository is therefore a downstream of core and of the catalog for the module, in addition to being a downstream of the kernel library for its binary. A core or catalog release the module adopts produces an operator release, and the CLI's pin on the operator moves with that release as it does today. The workspace's release tiers and pin classes state this, and the release gate that refuses a development pin in a module users receive covers the operator module.

**Requirements:** none (release posture; the tiers and gates it changes are workspace release rules, not consumer-observable contracts)

**Alternatives considered:**

- **Treat the module's core and catalog pins as test-only and hold them.** Not chosen: users receive these pins with the module, so a held pin ships a catalog no release was tested against.
- **Release the module on its own train to avoid the cascade.** Not chosen by D1: two numbers for one install.

**Rationale:** A pin users receive is a release input, and the release process exists to make sure every such input has been released against. The cost is more operator and CLI releases; the alternative is an operator module whose dependencies nobody chose.

**Measured 2026-10-04:** the workspace release documentation lists the operator in the tier that ships against the kernel library only, and its only shipped pin is the library in its Go module (`RELEASING.md` at the workspace root, read the same day).

**Source:** Supervisor seed 2026-10-04, not yet confirmed by the owner.

### D8: The first module install adopts an operator installed from a manifest

**Kind:** contract

**Depends:** 0012:D8

**Decision:** The first module install on a cluster whose operator was installed from an earlier release's manifest, by an earlier CLI or with kubectl, takes the existing objects into the new instance's inventory. It deletes and recreates none of them, so custom resources stored under the operator's CRDs are untouched and the operator keeps running except for the rollout its own changed Deployment causes. The adoption passes the apply guard of entry 0012 through its one override, the per-object adopt annotation naming the adopting instance (0012:D8). Whether install may set that annotation itself on the objects of the release it replaces, or the user must, is OQ3, because 0012:D8:R3 allows no other override. An operator installed with kubectl from a manifest rendered from the module (D2:R4) already carries the instance's identity and needs no adoption step. No recreation is possible only because the module keeps the earlier manifest's names and Deployment selector (D2:R5, R7); a migration that refuses leaves the earlier operator as it was (D3:R12).

**Revised:** 2026-10-04: kept after experiment 02, which showed the migration needs D2's names and selector and an explicit adoption; R5 added.

**Requirements:**

- R1: Installing the module over an operator installed from an earlier release's manifest deletes and recreates none of that operator's objects, and records every object the module renders in the new instance's inventory.
- R2: Custom resources stored under the operator's CRDs are unchanged by the migration.
- R3: An object of the earlier manifest that the module does not render is named in install's report and left in place.
- R4: An operator installed with kubectl from a manifest rendered from the module is taken into the instance by install with no step on any object by the user.
- R5: A migration install that refuses leaves the earlier operator running and every object of the earlier manifest unchanged.

**Alternatives considered:**

- **Uninstall the old operator and install the module fresh.** Not chosen as the migration: it deletes and recreates the controller, and the uninstall refuses while any instance carries the cleanup finalizer (0006:D34), so a cluster in use cannot take that path without orphaning its instances.
- **A command-wide force flag that takes every conflicting object.** Not chosen: 0012:D8 rejected it, because it takes objects the user did not mean to take.

**Rationale:** Every cluster running OPM today runs an operator installed from a manifest, so the first module install is always a migration. A migration that recreates CRDs would delete every instance on the cluster, so not recreating is the requirement that matters most.

**Measured 2026-10-04:** every object of the embedded manifest carries `app.kubernetes.io/managed-by: kustomize` and no OPM instance identity (`cli/internal/operator/dist/install.yaml`), so under 0012:D8 each is a foreign object to the new instance.

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/), step 6,** installing a catalog-path module over today's `opm operator install`:

- The CLI's apply refused at the first object without an OPM managed-by label (`cli/internal/inventory/stale.go`, read 2026-10-04). It neither adopted nor duplicated anything. The CRD step that ran before it had already relabelled the four CRDs (D3:R12).
- With every old object relabelled as OPM-managed, which stands in for the adoption OQ3 decides, 18 objects were taken over in place with their uids, and the earlier manifest's labels were dropped cleanly because both installs apply as field manager `opm-cli`. The Deployment failed as immutable (its selector changed), so no instance record was written.
- After deleting the Deployment by hand the install completed, but three bindings of the earlier manifest stayed in the cluster unrecorded beside the module's renamed ones. The module shape D2 now requires keeps those names and the selector ([`experiments/01-operator-module-render/`](experiments/01-operator-module-render/), variant), which removes both failures; the end-to-end migration with that shape is not yet measured.

**Source:** Supervisor seed 2026-10-04. R5 and the dependence on D2:R5 and R7: experiment outcome `0028/experiments/02-cli-bootstrap-install/` (2026-10-04).

### D9: Upgrade and uninstall act on the operator's instance

**Kind:** contract

**Depends:** 0006:D34

**Amends:** 0006:D34

**Decision:** Upgrading the operator is installing another module version over the existing instance: objects whose render changed are applied, objects the new version no longer renders are removed, and the CRDs and the Namespace are never removed. Uninstalling the operator deletes its instance through the CLI. This amends 0006:D34. What survives: uninstall refuses while any ModuleInstance in the cluster carries the operator's cleanup finalizer, its explicit override removes that finalizer only and orphans those instances' workloads, and the CRDs and the Namespace are never deleted. What changes: the set uninstall deletes is the operator instance's recorded inventory, not the documents of a manifest built into the CLI, so an object an older release installed is removed too.

Because the operator's instance is an ordinary CLI-owned instance, the CLI's generic instance delete can reach it too. That path keeps the same guard: deleting the operator's instance by any CLI command either meets uninstall's finalizer refusal or is refused with a pointer to uninstall.

**Revised:** 2026-10-04: R5 added after experiment 02 deleted the operator's instance past an armed finalizer.

**Requirements:**

- R1: Upgrading to another module version removes every object the previous version rendered and the new one does not, except CRDs and the Namespace.
- R2: Uninstall refuses while any ModuleInstance in the cluster carries the operator's cleanup finalizer, unless the user explicitly chooses to remove that finalizer and orphan those instances' workloads.
- R3: Uninstall removes every object recorded in the operator instance's inventory except CRDs and the Namespace, and then removes the instance record.
- R4: Uninstall removes no object the operator instance's inventory does not record.
- R5: No CLI command deletes the operator's instance while any ModuleInstance in the cluster carries the operator's cleanup finalizer, unless the user makes the same explicit choice R2 offers.

**Alternatives considered:**

- **Keep uninstall working from a list built into the CLI.** Not chosen: Gap 2 in 01-problem.md. The list describes the CLI's release, not the cluster's.
- **Delete the CRDs on uninstall once no instance remains.** Not chosen: a CRD delete removes every custom resource of its kind. 0006:D5 and 0012:D1:R3 both forbid an automatic CRD delete, and this entry does not reopen them.

**Rationale:** Once the operator has an inventory, the inventory is the only honest answer to "what did install put here". The finalizer guard of 0006:D34 protects the instances the operator manages, which do not change when the operator's own record does.

**Measured 2026-10-04 by [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/):**

- Upgrade from module 0.1.0 to 0.2.0 re-applied every non-CRD object (their version label changed) and left the CRDs unchanged. Both versions render the same object set, so R1's removal of a dropped object was not exercised.
- `opm instance delete` of the operator's instance deleted 14 objects and left the Namespace and the four CRDs ("CRDs and Namespaces are never deleted"), as R3 asks. It did not check finalizers: an operator-managed fixture still carried the cleanup finalizer and the delete went ahead silently. Today's uninstall guard (`cli/internal/operator/uninstall.go`, `CheckFinalizerGuard`, read 2026-10-04) has no counterpart on that path, hence R5.
- The orphaned fixture's later delete wedged in deletion until install was re-run; the restored operator then finished its cleanup.

**Source:** Supervisor seed 2026-10-04 (seed D4's uninstall clause, split out because it carries requirements and D4 is a policy). R5: experiment outcome `0028/experiments/02-cli-bootstrap-install/` (2026-10-04).

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
