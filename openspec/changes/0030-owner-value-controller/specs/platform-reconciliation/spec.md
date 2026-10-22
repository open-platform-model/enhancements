## MODIFIED Requirements

### Requirement: Only operator-managed instances are re-enqueued

A Platform event SHALL re-enqueue only the ModuleInstances that render against the Platform: those the controller manages (owner absent or `controller`) and that are not suspended. An instance owned by the CLI, or suspended, SHALL NOT be enqueued by a Platform event.

#### Scenario: CLI-owned and suspended instances stay out

- **WHEN** the Platform becomes Ready with reason Generated, and one instance is CLI-owned, one is suspended and one is controller-managed
- **THEN** only the controller-managed instance is enqueued
