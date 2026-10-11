# Source note: seed-instance-ownership

This is a seed. It records behaviour the CLI and the operator ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `instance-ownership`. Full seed (35 requirements: 13 on the owner marker and the two sides, 22 on the CLI's apply guard and prune; review T4.R24 added two, "An unconfirmed operator edit fails the apply" and "An unreadable stale claim is kept"). Written 2026-10-11 from the CLI at commit `09b0b812` and the operator at commit `cb97ffb0`. The owner-marker behaviour is seeded as it ships today, including the changes enhancement 0021 made to it (DECISIONS.md of the swarm, 2026-10-11 11:20), because the converted 0021 states none of it as a requirement except the one sentence named under "Left out".

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, file path or flag. The owner field is named in words, its values and the two condition reasons as published API. "CLI spec" is `cli` `openspec/specs/inventory-ownership/spec.md` at `09b0b812`. "Operator spec" is `opm-operator` `openspec/specs/module-instance-ownership/spec.md` at `cb97ffb0`. A row marked "code only" has no sentence in either spec.

| Requirement here | Source requirement | Code read |
| --- | --- | --- |
| A ModuleInstance records its owner | Operator spec, "ModuleInstance carries an ownership marker" | `api/v1alpha1/moduleinstance_types.go:61` (enum `cli;operator`); `config/crd/bases/opmodel.dev_moduleinstances.yaml:117-140` |
| The CLI sets the owner once, at creation | CLI spec, "spec.owner defines instance ownership" (first sentences), "Thin-editor apply on operator-owned instances" (second paragraph) and "Ownership mode resolution is a single branch point" (last two sentences) | `internal/workflow/apply/apply.go:633` (`Owner: OwnerCLI` on every full write); `internal/workflow/apply/thineditor.go:43-55` (restates the held owner); `internal/inventory/store.go:98-103, 136-139` (an empty owner is omitted from the document). The scenario "an absent owner stays absent" is code only |
| The CLI reads ownership from the owner field | CLI spec, "spec.owner defines instance ownership" and "Ownership mode resolution is a single branch point" (first sentence; the "single function" is a mechanism and is left out) | `internal/inventory/ownership.go:22-34`; `internal/workflow/apply/apply.go:145-148, 165`; `internal/cmd/instance/delete.go:218, 285` |
| Apply edits an operator-owned instance's spec only | CLI spec, "Thin-editor apply on operator-owned instances" (first paragraph and four scenarios), "Ownership is exclusive across tools" (CLI half) | `internal/workflow/apply/thineditor.go:25-79`; the spec edit carries the module reference, the values and the held owner (`internal/inventory/store.go:126-131`, `ApplySpec`; `thineditor.go:48-58`). The scenario "A values edit writes only the values" is code only (the same lines). The failure rule moved to its own requirement (next row) |
| An unconfirmed operator edit fails the apply | Code only. The CLI spec says only "report its resulting status" | `thineditor.go:64-74` (a wait that ends with the operator's Ready not true, whether the bound ran out or the operator reported Ready False, exits 1 with the "spec change is written — the operator will retry" text); `internal/inventory/reconcile.go:55-57` (`Reconciled`), `:84-124` (`WaitForReconcile` ends at the first Ready for the generation or at the bound; `:117-118` returns the read error when no read returned the instance and one failed, which `thineditor.go:66-68` reports as is, without the retry statement) |
| Apply refuses modules the operator cannot fetch | CLI spec, "Thin-editor apply on operator-owned instances" (local module sentence and scenario) | `thineditor.go:117-139`. The refusal of an incomplete module reference is code only (`thineditor.go:133-138`) |
| A dry run previews the spec edit only | None. Code only | `internal/workflow/apply/apply.go:138-150`; `thineditor.go:80-103` |
| Operator-owned delete hands cleanup to the finalizer | CLI spec, "Operator-owned delete hands cleanup to the operator's finalizer" (first paragraph, scenarios "Delete of an operator-owned instance" and "Delete refused while the operator is down") | `internal/cmd/instance/delete.go:352-375` (readiness is checked before the question and has no bypass) |
| Delete reports the outcome that occurred | Same requirement, second paragraph and scenario "Delete without spec.prune reports the orphaning" | `delete.go:380-425`. The scenario for a true prune setting is code only (`delete.go:408-411`) |
| The operator leaves a CLI-owned instance alone | Operator spec, "The operator skips CLI-owned instances before registering a finalizer" (first paragraph, three scenarios); CLI spec, "Ownership is exclusive across tools" (operator half) | `internal/reconcile/moduleinstance.go:236, 1212-1233, 1250-1258` |
| The operator releases a CLI-owned instance's leftover finalizer | Same requirement, second paragraph and two scenarios | `moduleinstance.go:1250-1265` |
| The operator acknowledges a CLI-owned instance once | Operator spec, "The operator acknowledges a CLI-owned instance with a single condition" | `moduleinstance.go:1257-1267` (a deleting instance returns before any status write), `:1266-1285`; `internal/status/conditions.go:331-336`. The scenario "The acknowledgement is set" names a live instance, as `:1257-1267` does |
| A hand-over to the operator is adopted | Operator spec, "Ownership handoff falls through to a normal reconcile" (first sentence and first scenario; the last sentence, about the operator's own instance, is out: see "For the owner at 0021's accept") | `moduleinstance.go:236-251` (the gates return before finalizer registration; no other branch) |
| A refusal names every refused resource | CLI `apply-pruning` spec, "Ownership guard judges every apply and dry run" (first paragraph, scenarios "Foreign resource refused", "Every refused resource is reported") | `internal/workflow/apply/apply.go:192-216, 740-783` |
| An unreadable resource stops the apply | Same requirement, third paragraph and scenario "Unreadable resource refused on a later apply" | `apply.go:740-760, 946-957`; `internal/inventory/guard.go:96-115` (not found or an unserved kind means absent) |
| A dry run runs the same guard | Same requirement, fifth paragraph | `apply.go:785-827` |
| A first-apply refusal explains earlier identities | Same requirement, second paragraph | `apply.go:762-782`. The requirement states the cause list the line prints (`:768`: "its module path, name or namespace changed", a deleted record, or an old release that recorded it in a Secret) and no identity rule; the identity rule is in "The prune judges with the recorded identity". The CLI wording (a major bump does not move the identity) is a follow-up in TECH-DEBT |
| Let-go resources get a warning | "Resource adopted by another instance is let go" (the warning and the dry-run line only) | `apply.go:222-236` |
| A full let-go ends with a closing line | Same requirement, second paragraph | `apply.go:237, 284, 358, 829-838` |
| A failed apply prunes nothing and records nothing | "No prune and no inventory write on apply failure" | `apply.go:313-317` |
| An unreadable record stops the apply | "Unreadable instance record stops the apply" (without the operator-install sentence, which is `operator-lifecycle`'s) | `apply.go:606-640, 946-957` |
| No record is read from a missing namespace | Same requirement, scenario "A missing namespace is not read for a record" | `apply.go:534-560` |
| An empty render needs force to prune | "Empty render safety gate" | `apply.go:719-731` (`GuardEmptyRender`); `apply.go:292-346` (a forced empty render runs the usual split and prune: protected kinds and claims are kept, the verdict still judges each object). The CLI spec's "all 5 previous resources SHALL be pruned" (`apply-pruning/spec.md:166-168`) is looser than the code |
| Pruning can be switched off | "--no-prune flag skips pruning" | `internal/cmd/instance/apply.go:86-89`; `apply.go:307-310, 324-345` (a dry run with pruning off skips the preview and the claim read, scenario "A dry run with pruning off") |
| A stale claim is kept by default | "Prune keeps stale PersistentVolumeClaims unless delete-data is set" (all but the operator-managed warning) | `internal/inventory/stale.go:39-80`; `apply.go:491-510` |
| An unreadable stale claim is kept | Same requirement, "A stale claim whose read fails in any other way SHALL be kept" (`apply-pruning/spec.md:331`), which the first draft of this seed dropped | `internal/inventory/stale.go:50-65` (`ClaimsInCluster` drops a claim only on NotFound; "Any other read error keeps the claim"); `apply.go:294-300, 341-344` (claims are read and kept only without data deletion; with it they go into the prune, where a failed read is a failed delete, `internal/kubernetes/deletion.go:83`; kept claims are logged and recorded, the exit is not touched) |
| Data deletion does not change an operator-owned instance | Same requirement, last sentence and scenario | `internal/workflow/apply/delete.go:17-22`; `thineditor.go:33-36` |
| The prune lists what it leaves behind | "Stale resources pruned after successful apply" (protected kinds listed as left behind) and "Prune asks the ownership verdict for each stale resource" (the listing, the failure and inventory outcome; the verdict itself is 0012's) | `internal/kubernetes/delete.go:140-150`; `internal/inventory/stale.go:23-37` |
| The prune judges with the recorded identity | "Prune asks the ownership verdict ..." (second paragraph) and "Apply flow orchestration" (scenario "The record takes the new identity after the prune") | `apply.go:388, 404-443`; the identity is the rendered `module-instance.opmodel.dev/uuid` label (`apply.go:654`, `inventory.ExtractInstanceUUID`), which the core schema derives from the module's major-free registry path, the name and the namespace (`core` `src/module_instance.cue:50,57` at `f3b7ecd`; seed `instance-identity`), so a major bump alone does not change it. The CLI spec's "module's path" (`apply-pruning/spec.md:390`) means that major-free path |
| A failed delete keeps its entry | "Failed prune keeps the entry and fails the command" | `apply.go:325-380` |
| The prune deletes only the object it read | "Prune asks the ownership verdict ..." (third paragraph) | `internal/kubernetes/delete.go:326-330` |
| A prune counts what the API server accepts | "Stale resources pruned after successful apply" (404 as success) and "Prune follows the shared deletion plan" (accepted delete counts; failed discovery stops requests) | `apply.go:404-443`; `internal/inventory/stale.go:125-135` |
| A dry run previews the prune | "Dry-run prune preview lists left-behind resources" (first paragraph) | `apply.go:445-490` |
| A dry run explains kept stale resources | Same requirement, second paragraph | `apply.go:445-490` |
| First installs over managed resources warn | "First install over OPM-managed resources warns" (the Secret and release wording is migration detail and is out) | `apply.go:873-900` |

## Disagreements between spec and code

The code wins. These are the differences that matter.

- The operator spec says an absent or empty owner is operator-managed and has a scenario "Empty owner is reconciled as operator-managed". The CRD enum is `cli;operator` and its description says the API server rejects an explicit empty string (`config/crd/bases/opmodel.dev_moduleinstances.yaml:119-122`). So the empty owner is rejected, not reconciled. The requirement "A ModuleInstance records its owner" says so, and its scenario "Any other value is rejected" names the empty string.
- The CLI spec says the CLI "waits, bounded, for the operator's reconcile and reports its resulting status". The code fails the command when the operator does not report Ready for the written generation in time (`thineditor.go:68-76`). The requirement "An unconfirmed operator edit fails the apply" states this outcome, which the code also gives when the operator reports Ready False for the generation (`internal/inventory/reconcile.go:55-57`, `Reconciled` is true only for Ready True).
- The CLI spec says a thin-editor apply carries "the instance's current owner value". When the instance has no owner, the code writes no owner (`store.go:100-103`), so the owner stays absent. The requirement "The CLI sets the owner once, at creation" says "restate the owner the instance already holds".
- The CLI `apply-pruning` spec says that with a forced empty render "all 5 previous resources SHALL be pruned" (`apply-pruning/spec.md:166-168`). The code sends the forced empty render through the usual split and prune (`apply.go:292-346`), which keeps claims and protected kinds and lets the verdict refuse an object. The requirement "An empty render needs force to prune" says the prune runs under its usual rules (review T4.R24).
- The same spec says an instance's identity "changes when the module's path changes" (`apply-pruning/spec.md:390`) and, in the same paragraph, that it derives from the path "without the major version". The code judges with the rendered identity label, which carries no major, so only a change of the registry path moves it. The requirement "The prune judges with the recorded identity" says so (review T4.R24).
- The CLI spec says the operator-readiness check "locates the operator by its fixed names, as `operator-lifecycle` defines". The requirement "Operator-owned delete hands cleanup to the finalizer" says only "check that the operator is ready"; the check itself is the `operator-lifecycle` seed's.

## Checked against the converted 0012

The supervisor asked (DECISIONS.md 2026-10-11 13:00) that the ownership guard of CLI `apply-pruning` be seeded here unless the converted 0012 states the same rule. I read all five specs of `0012-kubernetes-first-class-kernel-platform` on branch `refactoring-enhancements/p4-0012`.

0012 states, and this seed does not repeat (review T4.R18 finding 3):

- the verdict itself: which existing objects are refused, that a foreign object is refused on every apply and a new object never, that a terminating object is refused, the one adopt-annotation override, that no message names another override, the unknown-identity rule (`apply-verdict`);
- that an object adopted elsewhere is not applied or deleted, is dropped from the inventory and the others go on (`apply-verdict`, `inventory-identity`);
- that a frontend deletes only what the plan names, that a skipped object is never deleted, that objects OPM does not own and Namespaces and CRDs are skipped with a reason, and the hold verdict (`deletion-protocol`);
- the stale set that ignores component and version (`inventory-identity`), so the CLI's "stale resource detection" requirement is 0012's;
- the order of apply and delete (`object-ordering`), so the reverse weight order of the prune is 0012's.

The seed holds what 0012 does not state: the report of every refused resource, the read-failure outcome, the dry run, the earlier-identity line, the let-go warning and closing line, the left-behind listing, the recorded identity of the prune, the failed-delete rules, the UID precondition, the acceptance and discovery rules, the dry-run preview, the empty-render gate, the switch-off, the claim rule, the record read, and the first-install warning.

## Rest of `apply-pruning` (review T4.R18, question 3)

Every requirement of the CLI `apply-pruning` spec at `09b0b812` and where it went:

- "Stale resource detection": 0012 (`inventory-identity`). Not seeded.
- "Stale resources pruned after successful apply": order is 0012 (`object-ordering`); Namespace and CRD protection is 0012 (`deletion-protocol`); the listing is here ("The prune lists what it leaves behind"); the claim rule is here ("A stale claim is kept by default"); 404 as success is here ("A prune counts what the API server accepts").
- "No prune and no inventory write on apply failure": here.
- "Unreadable instance record stops the apply": here, with the missing-namespace rule.
- "Failed prune keeps the entry and fails the command": here.
- "Empty render safety gate": here.
- "--no-prune flag skips pruning": here ("Pruning can be switched off").
- "--max-history flag caps change history": **not seeded**. The spec is stale: no flag or history cap exists in the code (`git grep -i max-history` over `*.go` at `09b0b812` finds nothing). The code wins. The CLI's spec fix goes to the last phase.
- "Apply flow orchestration": a sequence of the other requirements. Its scenarios on the failed prune and on the new identity are in "A failed delete keeps its entry" and "The prune judges with the recorded identity". The sequence itself is a mechanism and is not seeded.
- "Dry-run prune preview lists left-behind resources": here (two requirements).
- "First install over OPM-managed resources warns": here, without the Secret and release wording.
- "Prune keeps stale PersistentVolumeClaims unless delete-data is set": here (two requirements).
- "Prune asks the ownership verdict for each stale resource": the verdict is 0012's; the rest is here.
- "Resource adopted by another instance is let go": the rule is 0012's; the warning and the closing line are here.
- "Prune follows the shared deletion plan": the plan is 0012's; the acceptance and discovery rules are here. Propagation policy and the per-kind order stay with 0012 and `object-ordering`.
- "Ownership guard judges every apply and dry run": the verdict is 0012's; the rest is here. That a refusal changes nothing, namespace creation included, is stated by the `apply-preflight-gates` seed ("A refused apply writes nothing") and is not repeated.

## For the owner at 0021's accept

The converted 0021 states "The operator never touches its own instance" (`operator-install-module`, 0021:D11:R9): the operator SHALL apply, prune and finalize nothing for the instance that deploys it, whatever its owner field says. Under the ruling of 13:30 the seed holds none of the detail the repos add to that rule. The detail, for the owner to take up in 0021 or to drop (operator spec `module-instance-ownership` at `cb97ffb0`; code `internal/reconcile/owninstance.go:28-77`, `moduleinstance.go:1212-1233, 1287-1340`):

- Recognition, from the stored object and without a render: name `opm-operator` in namespace `opm-operator-system`; module path `opmodel.dev/modules/opm_operator` with any major suffix removed; an inventory entry that is a CustomResourceDefinition whose name after its first dot is the operator's own group. A name or path that only resembles these does not match.
- The refusal: an own instance whose owner is `operator` or absent is refused before the finalizer is registered and before the suspend check, so a suspended own instance reads `SelfManagementRefused`, not `Suspended`. Ready is False and Stalled is True with reason `SelfManagementRefused`; the message names the matched signal and says to set the owner to `cli`; the observed generation is set; one Warning event is emitted; inventory, digests, UUID and history stay as they were; there is no requeue; Reconciling, ModuleResolved, Drifted and Healthy are removed; a repeated refusal is a no-op; setting the owner to `cli` clears it.
- The finalizer: a leftover cleanup finalizer on an own instance is removed without deleting any object in the inventory, whatever the prune setting, on a live and on a deleting instance; a deleting own instance gets no status write; an own instance with owner `cli` is left to the CLI-owned rules.
- The last sentence of "A hand-over to the operator is adopted": a flip to `operator` on the own instance leads to the refusal, never to an adoption.

## Left out

- The CLI's own refusals around the instance that deploys the operator (delete of an operator-owned own instance, and delete while any instance carries the cleanup finalizer): CLI `deploy` spec, "Instance delete of an instance that deploys the operator is guarded". They belong to the delete command's capability, which the capability map assigns to enhancement 0012, and to `operator-lifecycle`.
- The refusal of the option that skips unprovided provider-fulfilled demands on an operator-owned instance: in no seed. The skip switch is repo behaviour that no archived entry backs, so `cli-kernel-render` left it out (DECISIONS.md 2026-10-11 12:30 and 14:45).
- The version-skew ceiling and the CRD field floor (the installed CRD must carry the owner field) that run before the ownership branch: the `apply-preflight-gates` seed. The status-permission pre-flight skip for an operator-owned instance is the `apply-preflight-gates` seed's ("Operator-owned instances skip the status check"); the requirement "Apply edits an operator-owned instance's spec only" does not name it.
- `opm operator install` refuses where a let-go would proceed, and prints no first-install warning: `operator-lifecycle`.
- The delete command's `--delete-data` warning, its prompt wording, the `dataPolicy` rules for operator-owned deletes and the `--wait` semantics: CLI `deploy` spec (the capability the map assigned to 0012, which does not state them). The apply side of the same warning is seeded here.
- What a deleted instance's prune setting does to workloads, and the deletion protocol: enhancement 0012 (`deletion-protocol`). The requirement "Delete reports the outcome that occurred" states only that the CLI reports the outcome and that the prune setting has no default.
- That a Platform event, a ServiceAccount event and the requeue interval skip CLI-owned instances: `platform-reconciliation` (Platform events), operator `serviceaccount-impersonation` and `reconcile-loop-assembly` (not seeded here). The requirement "The operator leaves a CLI-owned instance alone" keeps only the sentence "does not requeue it for work", which the operator spec states in this capability.
- The ownership labels that stamp rendered objects with the instance identity: `instance-identity`.
- The `ManagedExternally` event the operator emits on each acknowledgement (`moduleinstance.go:1271`): code only, an event is not a stated behaviour.

sampled: 2026-10-11 18705155
