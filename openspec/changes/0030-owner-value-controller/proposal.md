# 0030: Owner value is controller

The ModuleInstance owner field accepts `cli` and `controller`. The delivered specs still name the second value `operator`, the name it had before the controller was renamed. This entry records the shipped value so the delivered specs match the API.

## Why

The API server rejects the owner `operator` and accepts `controller`. Two delivered requirements still tell a reader that `operator` is valid, and they call the OPM controller "the operator". A reader who follows them writes a ModuleInstance that the API server refuses.

## What Changes

- The delivered owner field accepts exactly `cli` and `controller`.
- An instance with no owner is reconciled by the controller, as an instance the controller owns.
- The requirements that name the owner value or the controller as its holder say `controller`.

## What this is not

- Not a new behaviour. The controller and the CLI already ship the value.
- Not a rename of the other delivered requirements that say "operator". Another change corrects them.

## Capabilities

- **Modified:** `instance-ownership`. The owner value and the word for the controller change in the requirements that name them.
- **Modified:** `platform-reconciliation`. The requirement that names the owner value as a filter for re-enqueue changes.

## Impact

- **Authors of a ModuleInstance** write the owner `controller`, not `operator`.
- **Readers of the delivered specs** see the value the API server accepts.

## Open questions

- Not blocking: Which of the remaining delivered requirements say "operator" for the controller, and when does a change correct them?
