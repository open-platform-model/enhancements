# Design: The Operator Becomes the Controller

The in-cluster component is named the controller everywhere a user meets it, in one cut, with no alias and no migration.

## Design Goals

- Every observable contract that named the in-cluster component by the old word names it "controller": the owner value, the version field on the Platform's status, the CLI command group, the repository, the image, the workload names, the deploying module and the documentation addresses. The namespace drops the component's name and becomes `opm-system`.
- The old names stop working. Nothing accepts, reads, writes or translates them.
- The vocabulary is fixed: "controller" is the product, and its per-kind loops are "reconcilers".

## Non-Goals

- Changing what the controller does. Every behaviour 0006 and 0021 decided stands; only names move.
- Migrating clusters that run the controller under its old names. Nobody runs OPM yet.
- Renaming the human role. A "platform operator" is still a person, and the Kubernetes `operator:` field of a label selector is untouched.
- Renaming upstream application operators that OPM modules deploy.

## High-Level Approach

One decision, 0032:D1, amends the seven delivered 0006 decisions whose contracts carry the name. Each keeps its behaviour and changes only the name it publishes. The draft entries that restate those contracts, 0021 among them, are edited in place to the new names after the repository carries its new name; the ordering is in 06-operational.

```text
before                                  after
owner value       operator          ->  controller
Platform status   operator version  ->  controllerVersion
CLI command       opm operator ...  ->  opm controller ...
image, repo, module                 ->  opm-controller, opm_controller
namespace         opm-operator-system  ->  opm-system
workload          opm-operator-controller-manager  ->  opm-controller-manager
selector value    controller-manager  ->  manager
```

## Affected Surfaces

- **ModuleInstance API.** The owner enum is `cli | controller`. An absent owner means the controller owns the instance, as before.
- **Platform API.** The controller reports its version in `controllerVersion` on the Platform's status. The CLI's ceiling reads that field.
- **CLI.** The command group is `opm controller`, with install and uninstall and the CRDs-only form. Handoff sets the owner to `controller`.
- **Distribution.** The repository is `open-platform-model/opm-controller`, the image `ghcr.io/open-platform-model/opm-controller`, and the deploying module `opmodel.dev/modules/opm_controller` on its own train. The default install lands in namespace `opm-system` as instance `opm-controller`. Its Deployment and ServiceAccount are `opm-controller-manager`, and its pods carry the label `control-plane` with the value `manager`.
- **Documentation.** The reference, install and conditions pages live under controller addresses, with no redirect from the old ones.

## Before / After

Before, the docs' conditions page said that "the operator" sets `Ready`, and the reader could not tell OPM's component from k8up's. After, the page says the controller's ModuleInstance reconciler sets `Ready`. "Operator" appears only for upstream application operators and the human platform operator.
