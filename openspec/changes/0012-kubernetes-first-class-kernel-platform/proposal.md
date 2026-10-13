# 0012: Kubernetes as a First-Class Library Tier

The kernel renders and stops. The controller and the CLI each decide what happens to a rendered object, so the same Kubernetes decisions exist twice and have drifted. This entry moves them into one library tier.

## Why

The two copies already differ where they decide. The CLI deletes CustomResourceDefinitions and the controller refuses to. The controller checks live ownership before it deletes and the CLI does not. The CLI refuses to apply over a foreign object and the controller does not. Neither frontend holds both guards.

## What Changes

- One library tier, beside the kernel, holds every Kubernetes decision. Both frontends delete their own copies.
- Deletion is one protocol. The library gives the plan, names each next action and says when the hold may be released. A frontend performs the actions.
- Apply stays with each frontend's engine. The library gives each object a verdict and the order.
- The apply guard runs on every apply. A foreign object is applied over only when the user marks it with an adopt annotation.
- Both frontends compute the same stale set and the same digests.

## What this is not

- Not a library apply engine, a reconcile loop or a home for credentials.
- Not a portability layer. Kubernetes is the one platform.
- Not the CRD Go types, which are entangled with entry 0008.
- Not a change to rendering. CUE still stamps the labels.

## Example

A module drops a feature that shipped a CRD. The CRD becomes a stale inventory entry. Today the controller skips it, and the CLI deletes it with every custom resource of that type. After this entry both skip it, with the same reason.

## Capabilities

- **New:** `shared-decisions`, `deletion-protocol`, `apply-verdict`, `object-ordering`, `inventory-identity`

## Impact

- **Users of either tool** get the same deletion and ownership outcome. The stored digests change once, with a migration note.
- **Three repos** change: library, opm-controller and cli.

## Open questions

- Blocking: Does OPM stamp `ownerReferences` at all? Kubernetes garbage-collects a dependent when its owners are gone, whatever `spec.prune` says, which contradicts `prune: false`. The recommendation is none: inventory, labels and a hold. This is half of what the entry was opened to answer.
- Not blocking: Does `spec.prune` keep defaulting to false? Flipping it makes every existing instance delete its workloads on delete, so it needs its own decision and a migration note.
- Not blocking: Does a CLI-owned instance carry a deletion hold? Today `kubectl delete` on its record orphans every workload. The options are a hold the CLI releases, a hold the controller honours, or an accepted leak with a warning.
- Blocking: Does the library own the CRD Go types? Entry 0008 generates them from CUE into the controller. The position must be agreed and recorded in both entries.
- Not blocking: Is the operation vocabulary for Kubernetes get and apply expressed as this entry's action set or beside it? Deferred to entry 0009, which carries it. No answer changes what this entry delivers.
