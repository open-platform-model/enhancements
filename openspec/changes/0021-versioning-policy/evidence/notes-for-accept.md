# Notes for the owner at accept

These points come from the conversion and from the delivered seeds. The old entry did not hold them as open questions, so they are not in the proposal. The owner decides each at accept.

## The entry itself

- **`breaking` is `false`, and a shipped change was marked BREAKING.** The old `config.yaml` had no `semver` key, so the conversion set `breaking: false`. The cli change `install-operator-from-module`, which task 4.2 ticks, calls itself BREAKING in its own proposal. The owner settles `breaking` at accept.
- **`opm` is in `affects` and has no task line.** The old config lists `opm`. The conversion kept it. The vet rule V23 reports an error at accept for a repo in `affects` with no task line. The owner adds a task line for `opm` or drops it from `affects`.

## Detail that the seeds hold and 0021 does not

Three delivered seeds held more detail than the rule 0021 states. The detail was taken out of the seeds so that 0021 and the seeds do not state one rule twice. The full text of each list is in the `source.md` of the archived seed, under "For the owner at 0021's accept": `seed-instance-ownership`, `seed-platform-resolution` and `seed-operator-lifecycle`. At accept the owner decides for each item whether it joins 0021 as a requirement or a scenario, or is dropped.

### From the seed `instance-ownership`, for "The controller never touches its own instance" (old 0021:D11:R9)

- **How the controller recognises its own instance.** Three signals from the stored object, with no render: the name `opm-controller` in the namespace `opm-system`; the module path `opmodel.dev/modules/opm_controller` with any major suffix removed; an inventory entry that is a CustomResourceDefinition of the controller's own group. A name or path that only looks like these does not match.
- **The refusal verdict.** An own instance whose owner is `controller` or absent is refused before the finalizer and before the suspend check, so a suspended own instance reads `SelfManagementRefused`, not `Suspended`. Ready is False and Stalled is True with that reason. The message names the matched signal and says to set the owner to `cli`. The observed generation is set and one Warning event is emitted. Inventory, digests, UUID and history stay as they were. There is no requeue. The conditions Reconciling, ModuleResolved, Drifted and Healthy are removed. A repeated refusal is a no-op. Setting the owner to `cli` clears it.
- **The leftover finalizer.** A leftover cleanup finalizer on an own instance is removed without deleting any object of the inventory, whatever the prune setting, on a live and on a deleting instance. A deleting own instance gets no status write. An own instance with owner `cli` follows the rules for CLI-owned instances.
- **A flip to `controller`.** A flip of the own instance to the owner `controller` leads to the refusal and never to an adoption.

### From the seed `platform-resolution`, for "Install does not depend on the cluster Platform" (old 0021:D11:R10)

- **A bad Platform does not refuse the render.** A Platform that is missing, not Ready or unreadable does not refuse the render of controller install.
- **Scenario "A stalled Platform does not block repair".** The cluster's Platform is Stalled and install runs. The render succeeds from the module's own pins and install goes on to its checks.
- **The reason.** Repairing the controller never depends on the Platform it serves (old 0021:D11:R10).
- **Where the code does it.** Controller install sets the render that reads only the dependency pins, so neither a platform directory nor the cluster is consulted (cli `internal/cmd/controller/install.go`, `internal/workflow/render/module.go`).

### From the seed `operator-lifecycle`, for the controller install and uninstall rules (old 0021:D11:R1 to R12)

Install:

- **Module path and pins (old 0021:D11:R1, R10).** The controller module is `opmodel.dev/modules/opm_controller`, fetched from the CLI's configured registry. The render uses the module's own dependency pins only. One module version and one set of values give the same objects whatever the Platform says (scenario: two clusters with different Platforms, or none).
- **Default version (old 0021:D11:R6).** Without a version selector, install installs the module version that the CLI release pins. Each CLI release names that version and the controller version it deploys, both known without a registry (scenario: the output names both).
- **Mirror (old 0021:D11:R2).** With the registry mapping routed to a mirror that holds the module and its dependencies, and the public registry unreachable, install succeeds.
- **Version ceiling.** A MAJOR.MINOR above the CLI's is refused with exit 2. The message names the module version and the controller version and says to upgrade the CLI. A CLI whose own version is not a release skips the rule with a warning. A running controller above the CLI's MAJOR.MINOR, or a target below what runs, does not refuse install (scenarios: controller newer than the CLI; a newer running controller does not block repair). No old id states this rule.
- **Existing Platform (old 0021:D11:R8).** Install never records the Platform in the instance. An existing Platform is reported and left untouched (scenario: the stored Platform is unchanged and the command says it was already present).

CRDs-only install (old 0021:D11:R7):

- **Same render, same refusals.** It renders the same module version as a full install and applies the same refusals before it applies any CRD. It applies exactly the rendered CRDs with server-side apply as `opm-cli`, and waits for each to be `Established`. It writes no instance record, no workload and no Platform, and does no catalog lookup. A later full install of the same module version records those CRDs without recreating them (scenarios: solo-cluster CRD install; full install after CRDs-only).

Uninstall (old 0021:D11:R11):

- **Refusal while an instance is armed.** Before it deletes anything, uninstall lists the instances cluster-wide. If any carries the controller's cleanup finalizer, it refuses, exits 2 and names each as `namespace/name`. With the option that removes finalizers it strips exactly that finalizer from each, attempts every one, says their workloads are orphaned, and deletes only if every one was stripped. A failed list, an RBAC denial included, fails closed with the permission-denied exit code and nothing deleted (scenarios: refusal names the armed instances; override strips only the controller's finalizer; partial failure blocks the delete step; list failure fails closed).
- **No record.** Uninstall reads the controller's instance record. With none it deletes nothing and exits 2, and the message names `opm controller install` (scenario: controller applied with kubectl).
- **What it deletes.** It deletes the objects the record lists, except CRDs, the Namespace and any PersistentVolumeClaim, and any object the deletion rules for an instance leave in place. It deletes the record when no object failed. It deletes no unlisted object, does not wait for deletion to finish, and treats an absent object as deleted. The closing line counts the deleted and the left-behind objects (scenarios: uninstall after a module install; re-running uninstall; a recorded object adopted by another instance is left behind). The exception for PersistentVolumeClaims comes from the code; the CLI spec names the CRDs and the Namespace only.
