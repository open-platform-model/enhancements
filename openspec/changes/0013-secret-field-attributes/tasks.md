<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Contract and schema

- [ ] 1.1 core: publish the tagged secret arms, the source input and the instance values check, and withdraw the old secret vocabulary

## 2. Kernel

- [x] 2.1 library: report every contract a render required, synthesised components included (expose-render-demand-and-instance-reads)
- [ ] 2.2 library: discover secrets from the schema, resolve them in place, synthesise a component per group and redact diagnostics

## 3. Catalog

- [x] 3.1 catalog_opm: remove the legacy secret mechanism and narrow the hand-authored Secret data to strings (catalog-remove-legacy-secrets)
- [ ] 3.2 catalog_opm: ship the literal secret source and read the resolved reference at every consumption site

## 4. Frontends

- [x] 4.1 opm-operator: record an instance's contract demand from the kernel's render (read-demand-from-kernel)
- [ ] 4.2 opm-operator: carry a platform's source settings, and state plaintext at rest for a literal in a resource
- [ ] 4.3 cli: accept SOPS-encrypted values, write a skeleton values file, report unfulfilled secrets together and carry source settings in the generated platform

## 5. Modules

- [x] 5.1 modules: strip the legacy secret vocabulary from the fleet (modules-drop-legacy-secrets)
- [x] 5.2 modules: re-pin the fleet to the catalog major that removed it (fleet-repin-catalog-v4)
- [ ] 5.3 modules: type each sensitive field as a secret, wire it by reference, and move RBAC scoped by the renamed object

## 6. Documentation

- [ ] 6.1 opmodel.dev: regenerate the schema reference and rewrite the secrets guide around routing and fulfilment
