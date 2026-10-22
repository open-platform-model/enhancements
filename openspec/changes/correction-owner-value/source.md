# Source note: correction-owner-value

Corrects: `instance-ownership` and `platform-reconciliation`. The owner value a ModuleInstance accepts is `controller`, and the controller is no longer called the operator, but these requirements still say `operator`.

## Shipped by

| Capability | Requirement | Change | Shipped by | Code read |
| --- | --- | --- | --- | --- |
| `instance-ownership` | A ModuleInstance records its owner | MODIFIED | `opm-controller` PR 297 | `api/v1alpha1/moduleinstance_types.go:34-37`, `api/v1alpha1/moduleinstance_types.go:44-47` in `opm-controller` |
| `instance-ownership` | The CLI sets the owner once, at creation | MODIFIED | `cli` PR 379 | `internal/workflow/apply/apply.go:633`, `internal/workflow/apply/thineditor.go:45-52` in `cli` |
| `instance-ownership` | Delete reports the outcome that occurred | MODIFIED | `cli` PR 379 | `internal/cmd/instance/delete.go:579-590`, `internal/workflow/apply/delete.go:21-23` in `cli` |
| `instance-ownership` | Apply refuses modules the operator cannot fetch | REMOVED | `cli` PR 379 | |
| `instance-ownership` | An unconfirmed operator edit fails the apply | REMOVED | `cli` PR 379 | |
| `instance-ownership` | The CLI reads ownership from the owner field | REMOVED | `cli` PR 379 |  |
| `instance-ownership` | Apply edits an operator-owned instance's spec only | REMOVED | `cli` PR 379 |  |
| `instance-ownership` | A dry run previews the spec edit only | REMOVED | `cli` PR 379 |  |
| `instance-ownership` | Operator-owned delete hands cleanup to the finalizer | REMOVED | `cli` PR 379 |  |
| `instance-ownership` | A hand-over to the operator is adopted | REMOVED | `opm-controller` PR 297 |  |
| `instance-ownership` | Data deletion does not change an operator-owned instance | REMOVED | `cli` PR 379 |  |
| `instance-ownership` | Apply refuses modules the controller cannot fetch | ADDED | `cli` PR 379 | `internal/workflow/apply/thineditor.go:109-126` in `cli` |
| `instance-ownership` | An unconfirmed controller edit fails the apply | ADDED | `cli` PR 379 | `internal/workflow/apply/thineditor.go:64-76` in `cli` |
| `instance-ownership` | The CLI reads ownership from the stored owner | ADDED | `cli` PR 379 | `internal/inventory/ownership.go:25-34` in `cli` |
| `instance-ownership` | Apply edits a controller-owned instance's spec only | ADDED | `cli` PR 379 | `internal/workflow/apply/thineditor.go:30-76` in `cli` |
| `instance-ownership` | A dry run previews only the spec edit | ADDED | `cli` PR 379 | `internal/workflow/apply/thineditor.go:89-105` in `cli` |
| `instance-ownership` | Controller-owned delete hands cleanup to the finalizer | ADDED | `cli` PR 379 | `internal/cmd/instance/delete.go:339-362` in `cli` |
| `instance-ownership` | A hand-over to the controller is adopted | ADDED | `opm-controller` PR 297 | `internal/reconcile/moduleinstance.go:1225` in `opm-controller` |
| `instance-ownership` | Data deletion does not change a controller-owned instance | ADDED | `cli` PR 379 | `internal/workflow/apply/delete.go:21-23`, `internal/cmd/instance/delete.go:218-221` in `cli` |
| `platform-reconciliation` | The skew policy is recorded with the package | MODIFIED | `opm-controller` PR 297 | `internal/controller/moduleinstance_controller.go:386-392` in `opm-controller` |
| `platform-reconciliation` | Deleting the Platform clears the held platform | MODIFIED | `opm-controller` PR 297 | `internal/controller/moduleinstance_controller.go:386-392` in `opm-controller` |
| `platform-reconciliation` | A Platform change re-enqueues consuming instances | MODIFIED | `opm-controller` PR 297 | `internal/controller/moduleinstance_controller.go:344-359`, `api/v1alpha1/platform_types.go:221-226` in `opm-controller` |
| `platform-reconciliation` | A restart recovers instances blocked on no platform | MODIFIED | `opm-controller` PR 297 | `internal/controller/moduleinstance_controller.go:331-359`, `api/v1alpha1/platform_types.go:221-226` in `opm-controller` |
| `platform-reconciliation` | Only operator-managed instances are re-enqueued | REMOVED | `opm-controller` PR 297 |  |
| `platform-reconciliation` | Only controller-managed instances are re-enqueued | ADDED | `opm-controller` PR 297 | `internal/controller/moduleinstance_controller.go:386-392` in `opm-controller` |

## Left out

- Requirements that use "the operator" only as the actor, with no owner value, no owner state and no CLI output. They keep the old name of the product and describe unchanged behaviour. In `instance-ownership`: "The operator leaves a CLI-owned instance alone", "The operator releases a CLI-owned instance's leftover finalizer" and "The operator acknowledges a CLI-owned instance once". In `platform-reconciliation`: "Only the cluster Platform is reconciled", "An unchanged package is not rebuilt", "A failure records the observed generation", "A failed build requeues on a bounded interval", "A registry failure does not outlive its reconcile" and "One generated platform is held for readers". A later correction can rename them.
