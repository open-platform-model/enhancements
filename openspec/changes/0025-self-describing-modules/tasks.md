<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Schema

- [ ] 1.1 core: define the aspect, the module trait and the module transformer; add the optional aspects map to the module and module transformers to the catalog and the platform, with the inventory covering module traits; update the specification text; exercise the delta with fixtures that publish no catalog member

## 2. Kernel

- [ ] 2.1 library: add the matching pass keyed on aspects, execute module transformers once per matched pair into the same output set, and report an unhandled aspect demand, landing the inventory coverage with the pass
