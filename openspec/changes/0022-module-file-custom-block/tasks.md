<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Contract and schema

- [ ] 1.1 core: define the block shape and its publish gate, and specify the gate in the publish-gates section of the core specification

## 2. Tooling

- [ ] 2.1 cli: apply the gate at publish, warn on a missing block, report it in the module check, and date the later refusal in the changelog
- [ ] 2.2 cli: write the block when scaffolding a module, setting a version and re-identifying a template, keeping every key it does not own
- [ ] 2.3 cli: write the push-time provenance annotations beside CUE's own keys
- [ ] 2.4 cli: read kind and core major from the block in the instance-initialisation walk, with the dependency fallback

## 3. Fleet

- [ ] 3.1 catalog_opm: run the writer once and commit the block in each catalog
- [ ] 3.2 modules: run the writer once and commit the block in each module

## 4. Documentation

- [ ] 4.1 opmodel.dev: state that the kind is now declared, and document the block in the module-file reference
