<!-- Sections run in order. This comment holds a task-looking line that must not count:
- [ ] 9.9 nowhere: ignored -->
## 1. Contract and schema

- [ ] 1.1 core: publish the authored platform, the admission entry and the resolved platform
- [ ] 1.2 catalog_opm: add the provider window to the registration contract

## 2. Kernel

- [ ] 2.1 library: hold each module's pinned catalog version, generate the resolved platform per resolution, and refuse pins outside the range

## 3. Frontends

- [ ] 3.1 opm-operator: take the range-form Platform and judge registrations by window and by declaring major
- [ ] 3.2 cli: render from an authored platform file and drop the CLI's own platform-less generation
