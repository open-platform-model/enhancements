# 0014: Export a Deployed Instance as GitOps Manifests

A user can write a running instance out as a directory and commit it. OPM first checks that the published module still renders what is running. Flux then applies the directory and the controller adopts the instance unchanged.

## Why

The old handoff command moved an instance to the controller, but not its definition. The only record left is a live object. A user who wants git as the source of truth copies it by hand and gets it wrong. A plain dump of the object applies under the controller's identity and orphans the workloads on delete. Nothing checks the result.

## What Changes

- One command writes a directory for one instance, or for every instance in a namespace or cluster.
- The directory holds the instance, its namespace, the service account that applies it, that account's role binding, and a kustomization.
- Nothing is written unless the published module reproduces the deployed render. A forced export skips only the digest check.
- Fields the live object lacks are completed and reported. Values are copied unchanged, with a warning.
- Once enhancement 0013 lands, an exported instance carries its secret values encrypted.

## What this is not

- Not repo-level Flux wiring. That is one object per repository, not per instance.
- Not a CUE-native export. That is a later output mode.
- Not an import. After the commit, Flux applies and reports drift.
- Not secret detection. Enhancement 0013 provides it.
- Not a change to core, library or the controller.

## Example

```text
$ opm instance export postgres -n prod --out-dir ./gitops
-> wrote ./gitops/prod/postgres/ (5 files)
```

## Capabilities

- **New:** `instance-export`, `export-verification`

## Impact

- **Users of the CLI** move a running instance into git in one step, with a check.
- **One repo** changes: cli. The CLI reference follows from its command definitions.
- The change is additive, so it is not breaking.

## Open questions

- Blocking: What does the export write for the service account name and the prune setting, which a CLI-written instance does not carry? Three candidates: mirror the live object and say so loudly; complete both to the demo shape and report each completion; require explicit flags and refuse when the live object is silent. The design assumes the second. The prune completion changes deletion from orphan to prune, so the question is whether an export may improve on what it exports.
- Blocking: What does the role document contain? The demo binds cluster-admin and flags it as a demo shortcut. Candidates: a cluster-admin binding with a prominent comment; an empty skeleton the user fills in; a least-privilege role derived from the instance's inventory, correct only for the current render.
- Blocking: May an instance still owned by the CLI be exported? Applying the exported tree would perform a handoff without its verdict, stale-snapshot guard or bounded wait. Candidates: refuse and point to a handoff first; allow with a warning; allow and keep the CLI as owner, which is not GitOps in any useful sense.
- Blocking: How does the exported instance interact with the field managers that already own its fields? Flux applies with its own manager over fields the CLI and the controller own. Only a runnable experiment in a kind cluster can answer whether Flux's force-apply resolves it cleanly, whether ownership then stays stable, and whether Flux's prune clashes with the controller's finalizer. The experiment must also show that the inventory entry set is unchanged.
- Blocking: Do the instance's own OPM labels belong in the exported document? Keeping them hands them to Flux. Dropping them makes the first GitOps apply remove labels the CLI set. The experiment of the question above probably answers it.
- Not blocking: Should the CLI learn that an instance is now git-managed? After the commit, an apply from the CLI writes a spec that Flux reverts. Candidates: documentation only; an annotation the apply path reads; detect a Flux field manager on the object and warn. The third needs no new field and covers instances that reached git another way.
