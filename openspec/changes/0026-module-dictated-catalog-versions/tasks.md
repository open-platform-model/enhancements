<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Contract and schema

- [ ] 1.1 core: publish the authored platform, the admission entry and the resolved platform, and rename the shipped render-time registry
- [ ] 1.2 catalog_opm: add the provider window to the registration contract, each bound defaulting to the registration's version

## 2. Kernel

- [ ] 2.1 library: hold each module's pinned catalog version, generate the resolved platform per resolution, refuse pins outside the range and count providers per resolution

## 3. Frontends

- [x] 3.1 opm-controller: judge a claim's shared-path requirements against the entry of the provider's own major (index-build-compat-by-major)
- [ ] 3.2 opm-controller: take the range-form Platform and judge registrations by window and by declaring major
- [ ] 3.3 cli: render from an authored platform file and drop the CLI's own platform-less generation
