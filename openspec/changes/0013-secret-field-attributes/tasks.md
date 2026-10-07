<!-- MOCKUP. Ticked lines 1.2, 1.3 and 2.2 are real landed changes from 0013/delivery.yaml, named by their OpenSpec change.
     The open lines are illustrative: they show the shape, not the real remaining work. See openspec/MOCKUP.md. -->

## 1. Declaring a secret

- [ ] 1.1 core: release the new secret type
- [x] 1.2 catalog: remove the old secret mechanism (`catalog-remove-legacy-secrets`)
- [x] 1.3 modules: drop the old mechanism from the fleet (`modules-drop-legacy-secrets`)
- [ ] 1.4 modules: mark secret fields with the new type

## 2. Resolving secrets

- [ ] 2.1 library: find every secret and replace it with a reference
- [x] 2.2 library: report every contract a render needed (`expose-render-demand-and-instance-reads`)
- [ ] 2.3 opm-operator: render with the new kernel pass
- [ ] 2.4 cli: render with the new kernel pass

## 3. Exporting

- [ ] 3.1 cli: encrypt literal secrets in an exported instance
