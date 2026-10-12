<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Release workflows

- [ ] 1.1 catalog_opm: attest and sign every catalog release, attaching the claims beside the artifact
- [ ] 1.2 modules: attest and sign every module release, attaching the claims beside the artifact
- [ ] 1.3 core: attest and sign the core release, attaching the claims beside the artifact

## 2. Contract and schema

- [ ] 2.1 core: declare the platform trust policy, platform-wide with an override per subscription

## 3. Kernel

- [ ] 3.1 library: verify an artifact's claims against a policy before its content is used, in acquire and in materialize

## 4. Frontends

- [ ] 4.1 cli: attest and sign in the release path and its templates, check one artifact on demand, and report the verdict
- [ ] 4.2 opm-operator: enforce the policy when reconciling a platform and report a failing subscription in its status
