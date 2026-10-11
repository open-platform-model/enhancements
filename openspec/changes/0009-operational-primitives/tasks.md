<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Contract and schema

- [ ] 1.1 core: publish the four operational constructs with the dispatch attribute convention, and update the core specification
- [ ] 1.2 core: add the operation and action maps to the catalog, and the lifecycle and workflow module traits on an aspect

## 2. Kernel

- [x] 2.1 library: remove the unread logger, tracer and clock slots (library-slot-prune)
- [ ] 2.2 library: check the caller's context at a verb's entry and between its stages
- [ ] 2.3 library: plan a lifecycle phase or a workflow, and advance it one step per call with a run state that survives serialisation
- [ ] 2.4 library: add the backend registry with its fail-fast check, and the backend hosts in the opt-in tier
- [ ] 2.5 library: design cancellation inside one advance, with the injection surface and its first reader

## 3. Catalog

- [ ] 3.1 catalog_opm: publish the initial operations and actions in the new catalog maps

## 4. Frontends

- [ ] 4.1 cli: register the backend set, and run workflows and lifecycle phases
- [ ] 4.2 opm-operator: register the operator backend set, and drive lifecycle phases from the reconcile loop
