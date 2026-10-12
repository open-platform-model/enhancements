<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Contract and schema

- [x] 1.1 core: add the layering contract, rules L1 to L6, to the core specification (commit 3bd988d)
- [ ] 1.2 core: project an optional trait's field as absent until set, fail a trait that states no posture, reword rule L5 into a kernel guarantee and add the plain-CUE compatibility clauses to the specification

## 2. Kernel

- [ ] 2.1 library: finalize validated config to plain values before composition on the instance, layered-source and debug-values paths, with config-shaped errors

## 3. Catalog

- [x] 3.1 catalog_opm: remove the twelve unused defaults definitions (commit eab9b12)
- [ ] 3.2 catalog_opm: narrow each workload blueprint to its kind and mark one leaf default per field, loosen the update strategy union, and add transformer fixtures built through a blueprint

## 4. Frontends

- [ ] 4.1 cli: drop the hand-set strategy and restart lines from the templates and add a render smoke test for each generated template

## 5. Modules

- [ ] 5.1 modules: delete the extracted boilerplate from the seven stateless-workload modules, with an empty render diff
