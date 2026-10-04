# Problem Statement: Gated Ownership Transfer from CLI to Operator

A user who deployed an instance with the CLI has no safe way to hand it to the operator. The command that did it was removed because it stranded instances, and the only path left is a hand edit of the owner field that nothing checks.

## Current State

Every instance the CLI applies is recorded in the cluster as a `ModuleInstance` custom resource. Its owner field says who acts on it: `cli` or `operator` (0006:D3).

- **The operator ignores a CLI-owned instance.** It renders, applies and prunes nothing, adds no finalizer, and only acknowledges the record as managed externally. Read from `opm-operator/internal/reconcile/moduleinstance.go`: the owner check runs before the finalizer is registered.
- **A flip of the owner field to `operator` is an adoption.** The next reconcile runs the ordinary path: finalizer, render, apply, prune, status. The operator's ownership spec names this behaviour, and its reconcile test flips a record and watches it adopt.
- **The operator has no gate of its own on that flip.** It does not read the CLI's local-provenance annotation (`module-instance.opmodel.dev/source: local`); a search of the operator's code and API types for it returns nothing (verified against opm-operator release 1.0.0-beta.5).
- **The CLI records what a transfer would need to verify.** Each CLI apply writes the module coordinate, the values, the inventory, and the render digest of what it applied. The removal of the old transfer command kept the digest on purpose, so a future transfer has a value to verify against.

The CLI once had that transfer: `opm instance handoff`, designed in 0006:D7 and refined by 0006:D16 (forward only), 0006:D38 (local provenance) and 0006:D40 (what success means). It ran a gate chain, flipped the owner, and waited for an inventory-stable reconcile. It was removed in cli PR 196.

## Gap / Pain

The removal reason, quoted from the cli change that removed it: the command "flips a CLI-owned instance to operator ownership irreversibly without checking that the operator's effective applier identity can apply the instance's inventory." Three gaps follow, and a fourth comes from the operator dogfood work in 0028.

1. **Applier identity is never established.** The CLI writes neither `spec.serviceAccountName` nor `spec.prune`. The operator then applies as its default account, which is empty unless an operator flag sets it, and falls back to its own controller identity. That identity has no rights on workloads by design: its role grants impersonation, not apply (read from `opm-operator/config/rbac/role.yaml`). Every apply is refused, the instance stalls, and with no reverse transfer (0006:D16) the CLI cannot take it back.
2. **Reachability is proven from the wrong side.** The old chain fetched the module through the CLI's registry mapping. The operator resolves through its own mapping, set by its own flag, environment, or a built-in default, and nothing in the cluster reports which one it uses. A module the CLI pulls from a developer's local registry passes the gate and fails in the operator.
3. **The local-provenance marker has a hole, and the operator ignores it anyway.** For an instance file, the CLI marks a render local only when the instance's module carries a local replacement file. Read from the CLI's render package (`cli/internal/workflow/render/`): the comment on the result type says "main module is a local directory, or a replaceWith", but the instance-file path tests only the replacement. And a `kubectl edit` that flips the owner bypasses every CLI gate, because the operator reads neither the marker nor anything else before adopting.
4. **The operator's own instance must never be adopted.** 0028 deploys the operator as a CLI-owned instance of its own module. Adopted by the operator, that instance would prune its own Deployment and RBAC on delete and then wait forever on its own finalizer. Nothing today stops that flip.

The result is that the "grow from CLI to GitOps" story 0006 was written for has no supported step in the middle. Entry 0014 (export) still cites the removed command as its precondition.

## Concrete Example

A platform engineer develops a `grafana` module locally and applies it with `opm module apply ./grafana`. Later she installs the operator and wants it to take over.

```text
today, by hand                          what actually happens
--------------------------------------  -----------------------------------------------
kubectl patch moduleinstance grafana    API server accepts: owner is a plain enum field
  spec.owner=operator
                                        operator adopts: finalizer, then render
                                        render pulls grafana at the recorded coordinate
                                          (a) not published  -> resolution fails, retried
                                          (b) published, different bytes -> applies them
                                        apply runs as the controller's own identity
                                          -> forbidden on every workload, instance stalls
                                        no command returns ownership to the CLI
```

Case (b) is the dangerous one: the coordinate exists in the registry, so the operator silently replaces what is running with something else. The local annotation the CLI wrote on the record says exactly why, and nobody reads it.

The same shape applies to the operator's own instance from 0028, with a worse ending: an adopted operator instance can delete the operator.

## User Stories

- As a platform engineer, I want to hand a CLI-deployed instance to the operator so that it is reconciled continuously. Today: no command does it, and the manual flip strands the instance under an identity that cannot apply it.
- As a module author iterating locally, I want a transfer of a locally rendered instance to refuse and tell me to publish first, so that the operator never runs bytes it cannot reproduce. Today: the CLI marker exists, but no actor refuses on it.
- As a cluster administrator, I want the operator to refuse an adoption no gate checked, so that a hand edit cannot do what the CLI would refuse. Today: the operator adopts whatever the owner field says.

## Why Existing Workarounds Fail

- **Patching the owner field by hand.** It skips every check above, and it is the shortcut the CLI's end-to-end suite uses to reach operator ownership. A server-side apply of the owner alone also drops the CLI's ownership of the fields it omits; the old command's verification pass found the API server rejects such a flip outright with `spec.module: Required value`.
- **Delete and re-apply through the operator.** Deleting the CLI-owned record and creating an operator-owned one loses the recorded digest and inventory. Depending on how the delete runs, it also deletes the workloads, which is the downtime the transfer exists to avoid.
- **Export to GitOps (entry 0014).** It is a draft, it reuses the same gate chain, and committing an exported tree for a CLI-owned instance is itself a transfer without a verdict.
