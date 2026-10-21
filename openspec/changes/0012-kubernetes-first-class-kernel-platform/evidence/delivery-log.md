# Delivery log: 0012

The old `delivery.yaml` of 0012, kept as a record. Source: `delivery.yaml` of `0012` at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements`. Decision numbers below are the old ones; the old text is `decision-log.md`.

The old file holds four entries, all for the cli, and each says that no decision is claimed (the controller side was not delivered). The landed repo changes are ticked in `../tasks.md` with their change names. The tasks hold more shipped changes than this log: the converter read the archives of library, cli and opm-controller and ticked each archived change whose proposal declares enhancement 0012. See "Beyond the old log" below.

| Date | Repo | What landed | Change |
| --- | --- | --- | --- |
| 2026-10-08 | cli | cli#343: the cli orders apply, prune and delete by the kind-class weights of library v1.0.0-beta.7 and pins them in a test. D5 is not claimed: the controller had not adopted that library release. | `adopt-library-beta7` |
| 2026-10-08 | cli | cli#347: every cli prune and delete reads the live object, asks the library delete verdict and leaves behind an object adopted by another instance (D8 R8, cli deletes). No decision claimed: the controller side is not delivered. | `adopt-kubernetes-ownership-package` |
| 2026-10-08 | cli | cli#349: the cli asks the library apply verdict for each rendered object on every apply, adoption by annotation only (D8 R1, R5, R8, cli side). The controller install's --rbac objects stay outside the guard. No decision claimed. | `guard-every-apply-by-ownership` |
| 2026-10-08 | cli | cli#350: cli instance delete, controller uninstall and prune follow the library deletion plan, and delete and uninstall its release verdict (D4 R1, R5, R6 for the cli). D4 is not claimed until the controller adopts the deletion protocol. | `adopt-kubernetes-lifecycle-package` |

## Beyond the old log

These archived changes declare enhancement 0012 in their own `proposal.md` and are ticked in `../tasks.md`. Checked on 2026-10-11 by listing the archives of the three repos and reading each proposal; the pull request numbers were not read.

- library: `record-kubernetes-tier`, `add-kubernetes-object-packages`, `add-kubernetes-inventory-package`, `add-kubernetes-ownership-package`, `refuse-an-object-another-instance-adopted`, `add-kubernetes-lifecycle-package`, `add-kubernetes-health-package`, `order-kinds-like-flux`.
- cli: `adopt-kubernetes-object-packages`, `adopt-kubernetes-inventory-package`, `adopt-kubernetes-health-package`.
- opm-controller: `adopt-kubernetes-object-packages`, `adopt-kubernetes-inventory-package`, `adopt-kubernetes-ownership-package`, `guard-every-apply-by-ownership`, `adopt-kubernetes-lifecycle-package`, `pin-flux-order-to-library-weights`, `add-healthy-condition`.

Two archived changes remove what the entry withdrew on 2026-10-09 (D8 R6 and R7), and are not ticked, because they deliver a removal and no requirement: library `remove-admit-and-public-surface-shims` and cli `retire-legacy-manifest-migration`. Each says it claims no decision.

No repo change claimed a decision. Which decisions the shipped changes complete is for the accept review: the old log says D5 and D4 waited for the controller, and the controller changes ticked above have since merged.
