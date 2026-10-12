<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->
<!-- Nothing is shipped yet. Section 3 also waits for the aspect definitions of enhancement 0025. -->

## 1. Contract and schema

- [ ] 1.1 core: define the module definition, the served-instance shape and the projection of a definition and an instance to a module instance, and add them to the core specification

## 2. Kernel

- [ ] 2.1 library: read the projection off a built value and render it unchanged, and answer whether a module's configuration schema encodes as a structural schema

## 3. Catalog

- [ ] 3.1 catalog_opm: publish the `offering` module trait, handled by no transformer, and the definition resource contract with the transformer that renders it

## 4. Frontends

- [ ] 4.1 opm-operator: accept a definition by claim, verify and activate, refuse its deletion while instances exist, report disagreement with the module's declaration, and accept a definition reference on a module instance in place of a module
- [ ] 4.2 opm-operator: serve the kind of a definition by generating the CRD from the module's configuration schema, run one data-driven controller that projects each instance and mirrors status, and apply the tenant guardrail
- [ ] 4.3 cli: draft a definition from a module's declaration, project and render a definition and an instance offline, and pre-flight a cluster's definitions before apply
