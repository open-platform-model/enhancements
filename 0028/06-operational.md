# Operational Concerns: The Operator Ships as an OPM Module

The five fixed production-readiness prompts, answered for this design.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **The operator's instance is the record.** `opm instance list` and `kubectl get moduleinstances` show the operator's instance like any other: its module version, its values and its inventory. Which operator release runs on a cluster becomes a field of a record instead of an image tag on a Deployment, and the running image cannot differ from it through a recorded value (D5:R6).
- **Install reports what it did.** The report names the module version installed and the operator version it deploys, the registry it came from, the objects created, changed and adopted, and, during a migration, the recreated Deployment, the deleted bindings and every other object of the earlier manifest the module does not render (D8:R9).
- **New refusals, each naming its cause.** A recorded value the target module version rejects (D5:R3); a module the registry cannot serve, or whose content differs from the CLI's pin (D1:R14); an operator newer than the CLI, an unasked downgrade, or CRDs that stop serving a version the cluster serves (D10); a foreign object install cannot prove came from an earlier operator release (D8:R8); and a delete of the operator's instance while instances still carry its cleanup finalizer, now on the generic instance delete too (D9:R5). A refusal changes nothing in the cluster (D3:R12).
- **Install success means the operator is reconciling.** Install waits for the cluster Platform to report Ready from the release it installed (D3:R10), which experiment 02 showed is about 30 s later than the Deployment's rollout after an upgrade.
- **The operator emits nothing new.** Its own metrics and conditions are unchanged.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

The entry's `semver` is `major` (OQ9): on the beta lines these ship as declared breaking changes with a migration note (0021:D7).

- **cli.** Install needs a registry where it did not; selecting another version takes a module version instead of a release tag; uninstall deletes the cluster's recorded set instead of the CLI's list; the first install over a manifest-installed operator recreates its Deployment and deletes three bindings (D8).
- **opm-operator.** No change to the operator's API or behaviour. The repository gains a second release unit, the module, whose `#config` is a compatibility surface under the module class on its own `0.x` train (D1). The operator release stops publishing an install manifest; the module release publishes it (D2:R13).
- **catalog.** Additive: the workload security context gains a seccomp profile and the role resource accepts a role with no subjects (D12). Every module that renders today renders the same.
- **Users of the release manifest.** The manifest is now published by the module release and rendered from the module. Its role bindings have new names and its Deployment a new selector, so `kubectl apply` of the first module-rendered manifest over an earlier one fails on the Deployment's selector until the Deployment is deleted, and leaves the three old bindings behind; the migration note says how. Applying a later module-rendered manifest over an earlier one behaves as before (D2:R11).

## Deprecation

**What gets removed and when? What replaces it?**

| Removed | Replacement |
| --- | --- |
| The operator manifest embedded in the CLI and its pinned version | A pinned operator module version in the CLI (D3) |
| The CLI's task that refreshes the embedded manifest | The ordinary pin bump of a module version, carried by the release cascade (D7) |
| Fetching another release's manifest from GitHub | Resolving another module version through the CLI's registry mapping (D3) |
| Patching controller arguments onto the Deployment after install | Values of the operator's instance (D5) |
| Uninstall's list of documents from the embedded manifest | The operator instance's recorded inventory (D9) |
| The CLI's operator version constant, read by the documentation site's version resolver | The operator version the CLI's pinned module deploys, which the resolver reads instead (D7) |
| The workspace release checks keyed on the embedded manifest (G1's tag comparison, G4's trigger) | The same checks keyed on the pinned operator module version and its content digest (D7) |
| The install manifest the operator release publishes | The install manifest each module release publishes, rendered from the module (D2) |

All of them go in the CLI release that switches install to the module; a CLI that installs from both sources would keep two install shapes alive, which D3 rejects.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- **The operator itself.** Re-run install with the previous module version and ask for a downgrade (D9, D10:R2). Install needs nothing from the running operator (D4:R2) or the cluster Platform (D11), and the ceiling on the running operator does not refuse it (D3:R16), so a broken or newer operator does not block its own rollback. Install refuses a previous version whose CRDs no longer serve a version the cluster serves (D10:R3); that rollback is then not possible by install, and the fix is a newer module release. Between module versions the Deployment selector does not change (D2:R11), so no rollback recreates the controller.
- **The CLI.** A user can return to a CLI release that still embeds the manifest, but its install fails on the operator's Deployment: the manifest's selector differs from the module's, and Kubernetes refuses the change. Returning to that CLI's install therefore means deleting the operator's Deployment first, and it leaves the module's catalog-named bindings beside the manifest's. The CRDs, custom resources and Namespace are untouched either way. The operator's instance record then describes objects that no longer carry its identity, and the next module install takes them back through the migration of D8, which recreates the Deployment once more. This direction was not run.
- **The release.** Published module versions are never re-pointed (0021:D10). A bad module release is fixed by the next module release, and the CLI's pin moves back by a pin change. A bad operator release is fixed by the next operator release and a module release that names it; until then the CLI's pinned module keeps naming the previous image by digest.
- **State that survives.** CRDs and the custom resources under them are never deleted by either path, so no rollback loses an instance.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- **The catalog changes ship before the module.** The module renders the controller through the catalog's workload, service account, role and CRD resources (D2), and it cannot meet the `restricted` profile or render the unbound roles until a catalog release carries D12's seccomp profile and subject-less roles. That catalog release comes first, then the module release that pins it. A future operator CRD with a conversion webhook needs a catalog release whose CRD resource carries `conversion` first.
- **The operator image exists before the module names it.** An operator release publishes its image; the module release that names it by digest follows (D1:R10).
- **A module release is published before the CLI pins it.** The CLI's default module version and its content digest must name a published module release (D1:R14).
- **The module's release tags are in place before its first release.** The workspace tag rules (only the release tooling creates tags; tags are never moved) cover the module's tags as they cover the operator's, and the tag shape tells the two units apart (D1:R9), so the repository's release configuration and the workspace's tag tooling learn the second unit before the module's first release.
- **The release's CLI can publish the module without needing it.** The module release runs a pinned CLI to publish; that CLI must not depend on the operator module it publishes.
- **The apply guard's adopt annotation exists before the migration.** D8 adopts through 0012:D8's override, so the frontends implement the annotation before the CLI release that installs the module over manifest-installed operators.
- **The CLI's install switch and the documentation move together.** The install pages in `opm` and `opm-operator` describe the module install, and the one-time migration, only once a CLI release installs that way; documentation that changes before the release shows a command that does not yet behave as described.
- **The operator's refusal of its own instance ships early.** D4:R1 holds whatever the owner field says, and experiment 02 showed a hand edit of the owner field already makes the operator adopt or wedge itself today, so the operator-side check does not wait for the module install. Any later design that moves instance ownership between the CLI and the operator must refuse this instance from its first release.
- **The CLI's operator locator moves with the install switch.** The readiness check behind the CLI's delete guard reads the embedded manifest today, so the release that drops the manifest also switches the check to the operator's instance, with the fixed names as the fallback where no record exists (D3:R13, R15).
- **The documentation site's resolver reads the new pin before the CLI drops the old one.** `opmodel.dev`'s version resolver reads `PinnedOperatorVersion` at each CLI tag (`site/scripts/resolve-versions.sh`, documented in its `README.md` and `AGENTS.md`). It must read the operator version the CLI's pinned module deploys, and keep reading the constant at older CLI tags, before the first CLI release without the constant is tagged, or the site build for that version fails.
- **The workspace release rules change with the CLI release that drops the manifest.** `RELEASING.md`'s tier table gains the module release between the operator and the CLI, and its CLI tier row, its shipped-pin row, G1's comparison and G4's trigger (with its replacement job `add-embedded-operator-e2e-job`) name the embedded `install.yaml` and `PinnedOperatorVersion`; they move to the operator module version and its content digest in the same window (D7), or G1 fails the first CLI release PR that has no constant to compare.
