# Risks, Drawbacks, Alternatives: The Operator Ships as an OPM Module

Risks describe what could go wrong. Drawbacks describe what definitely costs something. Alternatives describe the high-level paths not taken; per-decision detail lives in `03-decisions.md`.

## Risks and Mitigations

Ranked by blast radius.

- **A CRD change deletes or strands every instance.** An upgrade or a downgrade applies CRDs whose stored versions or schemas differ from what the cluster holds. A CRD delete would remove every ModuleInstance in the cluster. **Mitigation:** neither frontend deletes a CRD in an instance's inventory (0012:D1:R3), and D9 keeps that for upgrade and uninstall. A served-version check before applying CRDs is OQ6.
- **The first module install refuses or recreates a running operator.** Every operator on a cluster today was installed from a manifest whose objects carry no OPM identity, so the apply guard of 0012:D8 treats them as foreign. A migration that recreates the CRDs would delete every instance. **Mitigation:** D8 requires adoption with no recreation, and experiment 02 records object UIDs before and after. Who sets the adopt annotation is OQ3.
- **An upgrade cannot render because the cluster Platform is unhealthy.** If install renders the operator module against the cluster Platform, a broken or mis-subscribed Platform blocks the one command meant to repair the cluster. **Mitigation:** OQ5 decides which platform install renders against; D4 makes install the recovery path, which argues for the module's own pins.
- **A newer module needs a newer kernel than the CLI has.** A user selects a module version whose core or catalog pins the CLI's kernel cannot render, or whose operator the CLI then refuses to drive (0021:D9). **Mitigation:** each CLI release defaults to a module version it was tested with; OQ4 decides whether install refuses a newer one.
- **Deleting the instance record with kubectl orphans the operator silently.** A CLI-owned instance carries no finalizer, so `kubectl delete` removes the record and leaves every object running with no record of them. **Mitigation:** the objects keep the instance's identity labels, so re-running install records them again without a refusal (D3:R3).
- **A partial release publishes the image but not the module, or the module twice.** **Mitigation:** D1:R1 makes the release public only after the module is published; registry versions are never re-pointed (0021:D10), so a re-run must treat an already-published identical version as done (OQ11).
- **Names the module derives differ from the manifest's.** The CLI, its end-to-end tests, the demo repository and the documentation name the operator's Namespace, Deployment and CRDs. **Mitigation:** D2:R5 keeps every name; experiment 01 checks them.

## Drawbacks

- **Install needs a module registry.** The embedded manifest installed with no network. Every install, the CRDs-only form included, now resolves the module and its core and catalog dependencies from a registry or a mirror. A learner on a laptop with no network can no longer install OPM's CRDs.
- **Install is heavier.** The CLI resolves dependencies and renders a module with large CRDs instead of applying static bytes, which costs time and memory on the user's machine.
- **More releases.** Every core or catalog release the module adopts produces an operator release and then a CLI pin bump (D7).
- **Nobody corrects drift on the operator.** The operator's own instance is CLI-owned (D4), so an edit to the operator's Deployment stays until the next install. This was true of the manifest as well; the entry does not improve it.

## Alternatives

- **The operator manages its own instance after a bootstrap, as Flux and Argo CD do.** **Why not:** a broken self-managed operator has no outer layer to repair it, and its own deletion wedges on a finalizer only it can clear (D4).
- **Embed the module tree in the CLI for offline installs.** **Why not:** a vendored module renders through a local replacement, which marks it as local bytes, and it brings back the copy-and-sync plumbing the entry removes (D3).
- **Keep the install manifest as the CLI's artifact and publish the module only for GitOps users.** **Why not:** two install shapes that can drift, and the CLI would still not install OPM's controller with OPM (D3).
- **A separate CRD bundle artifact beside the module.** **Why not:** a second artifact per release that must agree with the first, for no gain on uninstall, since CRDs are never deleted anyway (D3).
