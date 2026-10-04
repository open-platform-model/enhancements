# Operational Concerns: The Operator Ships as an OPM Module

The five fixed production-readiness prompts, answered for this design.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **The operator's instance is the record.** `opm instance list` and `kubectl get moduleinstances` show the operator's instance like any other: its module version, its values and its inventory. Which operator release runs on a cluster becomes a field of a record instead of an image tag on a Deployment.
- **Install reports what it did.** The report names the module version installed, the registry it came from, the objects created, changed and adopted, and, during a migration, every object of the earlier manifest the module does not render (D8:R3).
- **New refusals, each naming its cause.** A recorded value the target module version rejects (D5:R3); a module the registry cannot serve; and the rules OQ4 and OQ5 settle.
- **The operator emits nothing new.** Its own metrics and conditions are unchanged.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

- **cli.** Install needs a registry where it did not; selecting another version takes a module version instead of a release tag; uninstall deletes the cluster's recorded set instead of the CLI's list. On the CLI's beta line (0021:D7) these ship as a declared breaking change with a migration note. The entry's own `semver` is OQ9.
- **opm-operator.** No change to the operator's API or behaviour. The release gains an artifact, and the operator's `#config` becomes a compatibility surface under the module class (D2:R6).
- **core, catalog.** No change. The operator module consumes existing catalog resources.
- **Users of the release manifest.** The manifest keeps its objects and names (D2:R5), so `kubectl apply` of a newer release over an older one behaves as before. Its labels change, because it is now a module render.

## Deprecation

**What gets removed and when? What replaces it?**

| Removed | Replacement |
| --- | --- |
| The operator manifest embedded in the CLI and its pinned version | A pinned operator module version in the CLI (D3) |
| The CLI's task that refreshes the embedded manifest | The ordinary pin bump of a module version, carried by the release cascade (D7) |
| Fetching another release's manifest from GitHub | Resolving another module version through the CLI's registry mapping (D3) |
| Patching controller arguments onto the Deployment after install | Values of the operator's instance (D5) |
| Uninstall's list of documents from the embedded manifest | The operator instance's recorded inventory (D9) |

All of them go in the CLI release that switches install to the module; a CLI that installs from both sources would keep two install shapes alive, which D3 rejects.

## Rollback

**If this lands and proves bad, what's the rollback story?**

- **The operator itself.** Re-run install with the previous module version (D9). Install needs nothing from the running operator (D4), so a broken operator does not block its own rollback.
- **The CLI.** A user can return to a CLI release that still embeds the manifest. Its install applies the manifest over the same objects with the same field manager, which drops the instance identity labels the module had set. The operator's instance record then describes objects that no longer carry its identity, and the next module install takes them back through the migration of D8.
- **The release.** Published module versions are never re-pointed (0021:D10). A bad module release is fixed by the next release, and the CLI's pin moves back by a pin change.
- **State that survives.** CRDs and the custom resources under them are never deleted by either path, so no rollback loses an instance.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- **The catalog resources the module needs exist before the module.** The module renders through the first-party catalog's existing workload, role, CRD and `objects` resources; it pins a catalog release that carries all of them.
- **The operator release publishes the module before the CLI pins it.** The CLI's default module version must name a published module, and the module must be published before the operator release becomes public (D1:R1).
- **The release's CLI can publish the module without needing it.** The operator release runs a pinned CLI to publish; that CLI must not depend on the operator module it publishes.
- **The apply guard's adopt annotation exists before the migration.** D8 adopts through 0012:D8's override, so the frontends implement the annotation before the CLI release that installs the module over manifest-installed operators.
- **The CLI's install switch and the documentation move together.** The install pages in `opm` and `opm-operator` describe the module install only once a CLI release installs that way; documentation that changes before the release shows a command that does not yet behave as described.
- **Entry 0029 refuses the operator's instance before any transfer command ships.** A transfer command that could move the operator's own instance would break D4 the day it ships.
