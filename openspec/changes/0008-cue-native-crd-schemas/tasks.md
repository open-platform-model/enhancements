<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Contract and schema

- [ ] 1.1 core: publish the CRD envelope with its names, scope, version, printer-column, validation and subresource shapes and the ModuleInstance and Platform values, add the matching section to the core specification, and add a ModulePackage value once core owns its shape

## 2. Generator

- [ ] 2.1 opm-operator: build the generator that reads the published core module, emits the CRD manifests and the Go API types, and runs deepcopy over them
- [ ] 2.2 opm-operator: replace the hand-written types and the controller-gen manifest target with the generated ones, and add the regenerate-and-diff check to CI

## 3. Consumers

- [ ] 3.1 cli: bump the operator dependency and rebuild against the generated types with no source change
