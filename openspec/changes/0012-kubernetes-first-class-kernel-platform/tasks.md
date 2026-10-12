<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Library: the fence and the tier

- [x] 1.1 library: record the Kubernetes tier, its fence and the clarified and amended rules of the kernel-plans-caller-runs record, before any tier package exists (record-kubernetes-tier)
- [x] 1.2 library: ship the label and object packages: conversion of compiled output, the one kind-class order table and the Kubernetes apply identity moved out of the helper tier (add-kubernetes-object-packages)
- [x] 1.3 library: ship the inventory package: the component-blind stale set, the canonical inventory digest and the render digest that ignores the runtime name (add-kubernetes-inventory-package)
- [x] 1.4 library: ship the ownership package: the apply and delete verdicts and the adopt annotation (add-kubernetes-ownership-package)
- [x] 1.5 library: refuse an object another instance adopted, inside the inventory and outside it (refuse-an-object-another-instance-adopted)
- [x] 1.6 library: ship the lifecycle package: the deletion plan, the transition, the serialisable state and the hold verdict (add-kubernetes-lifecycle-package)
- [x] 1.7 library: ship the health package: readiness evaluation (add-kubernetes-health-package)
- [x] 1.8 library: align the kind-class weights with the order Flux applies in (order-kinds-like-flux)

## 2. Frontends adopt the tier

- [x] 2.1 cli: delete the local object, label and resource-order copies and use the tier (adopt-kubernetes-object-packages)
- [x] 2.2 cli: use the tier's stale set and digests, and drop the component rename filter (adopt-kubernetes-inventory-package)
- [x] 2.3 cli: judge readiness only through the tier's health package (adopt-kubernetes-health-package)
- [x] 2.4 cli: read the live object and ask the ownership verdict on every prune and delete, and leave behind an object adopted by another instance (adopt-kubernetes-ownership-package)
- [x] 2.5 cli: ask the apply verdict for each rendered object on every apply, with the adopt annotation as the only override (guard-every-apply-by-ownership)
- [x] 2.6 cli: delete an instance, uninstall the operator and prune by the library deletion plan and its release verdict (adopt-kubernetes-lifecycle-package)
- [x] 2.7 cli: order apply, prune and delete by the kind-class weights of the pinned library (adopt-library-beta7)
- [x] 2.8 opm-operator: delete the local object, label and resource-order copies and use the tier (adopt-kubernetes-object-packages)
- [x] 2.9 opm-operator: use the tier's stale set and digests (adopt-kubernetes-inventory-package)
- [x] 2.10 opm-operator: judge prune and delete by the ownership verdict, and record a ModulePackage's instance identity in its status (adopt-kubernetes-ownership-package)
- [x] 2.11 opm-operator: ask the apply verdict for each object on every reconcile (guard-every-apply-by-ownership)
- [x] 2.12 opm-operator: delete by the library deletion plan and release the finalizer on the library verdict (adopt-kubernetes-lifecycle-package)
- [x] 2.13 opm-operator: pin the order of Flux's staged apply against the library kind weights with tests, so Flux refines the library order and never contradicts it (pin-flux-order-to-library-weights)
- [x] 2.14 opm-operator: add a Healthy condition judged by the library health package (add-healthy-condition)
