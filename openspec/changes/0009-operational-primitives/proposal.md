# 0009: Operational Primitives

OPM describes what must exist but not what should happen around it. This entry gives the kernel a second half that plans an ordered list of typed steps from the same module. The owner parked it until hooks are wanted.

## Why

A module cannot say that a migration runs between two deploy phases, or that a seed step runs on demand. Those steps live in side scripts, hand-written Jobs and runbooks that nothing types, composes or governs. Helm hooks show the other failure: an arbitrary script as a hook is flexible and unmaintainable. OPM's answer elsewhere is a small typed vocabulary that authors compose.

## What Changes

- An author declares ordered steps in the same module that renders to Kubernetes. Rendering does not change.
- The step kinds are a closed set that OPM owns. Authors compose them into reusable actions, state-bound lifecycles and on-demand workflows.
- The library plans, then advances one step per call. The caller runs the loop and keeps the state.
- Each frontend registers the backends it wants. A plan it cannot run is refused before the first step.
- Catalogs publish the operations, so a platform gains one without a library release.

## What this is not

- Not a change to the render half. Execution is additive.
- Not a scripting language. Composing a closed set is the point.
- Not a meta-controller toolkit. The design must allow one, and this entry does not build it.
- Not a final backend for every artifact form. The form is open.

## Example

```cue
lifecycle: phases: "pre-upgrade": [
    ops.#WaitOp & {condition: "db.ready", timeout: "120s"},
    actions.#DBMigration & {steps: migrate: {image: "flyway/flyway:10", command: ["flyway", "migrate"]}},
]
workflows: "seed-demo": steps: run: ops.#ExecOp & {image: "myorg/seeder:1", command: ["seed"]}
```

## Capabilities

- **New:** `operational-plan`, `operational-constructs`, `lifecycle-phases`, `step-advance`, `op-dispatch`, `op-catalog`

## Impact

- **Module authors** gain a typed place for operations. Modules without them behave as before.
- **Platform teams** choose which backends and catalogs supply operations.
- **Five repos** change: core, library, catalog_opm, cli and opm-operator. The change is additive. It builds on the aspects of enhancement 0025.

## Open questions

- Blocking: What form do cataloged operation artifacts take: WASM, an OCI image, or both? The answer gates the backend set and the dispatch attribute. The proposal on the table is both, chosen per operation by protocol, with WASM for pure logic and containers for side effects.
- Not blocking: Do steps pass typed data to each other, or is ordering the only link? Whatever a step hands on must survive serialisation into a custom resource.
- Not blocking: What is the run-state and idempotency model for a workflow, and how does it differ from a lifecycle? Lifecycles re-plan on each reconcile; an on-demand workflow may not be idempotent and may need run history.
- Not blocking: Is the meta-controller toolkit in scope, and when? It is likely deferred to a follow-up entry.
- Not blocking: How far does cancellation reach inside one advance, and how is a cancelled step recorded? The caller cancels between steps by not calling again. A running CUE evaluation cannot be cancelled, and a registry fetch can be, through the registry seam. The open part is whether an abandoned step is a failure or a distinct outcome.
- Blocking: Does in-module step ordering survive the owner's intent that nothing orders within a module? Lifecycle steps could be a sanctioned exception, move up to a bundle, or go. The answer also owes the half of enhancement 0012's open question on whether the k8s get and apply operations are the Kubernetes tier's action set or sit beside it.
