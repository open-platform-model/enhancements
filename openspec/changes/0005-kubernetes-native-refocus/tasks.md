<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Generation tooling

- [ ] 1.1 catalog_opm: generate the Kubernetes types from the OpenAPI in a strict and an open rendering, with a generation manifest and a typed catalog from a CRD bundle (the home of the generator is open)

## 2. Catalogs

- [ ] 2.1 catalog_opm: replace the hand-written raw mirror with generated output, keeping the generic objects hatch, and publish
- [ ] 2.2 catalog_opm: point the opinionated catalog at the shared strict types and add the override field to its blueprints

## 3. Lifecycle consumers

- [ ] 3.1 library: read the generated apply phase in place of the hardcoded order list, and expose readiness and prune metadata
- [ ] 3.2 opm-controller: reconcile on the lifecycle metadata for ordering, readiness reports and pruning, and degrade gracefully when it is absent

## 4. Documentation

- [ ] 4.1 opmodel.dev: document the generated catalogs, the generation workflow and the golden-path composition pattern
