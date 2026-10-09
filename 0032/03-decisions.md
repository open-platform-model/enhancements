# Design Decisions: The Operator Becomes the Controller

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent**, never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** How that stays true depends on the entry's `status`:

- While the entry is **`draft`**, decisions are living text: a changed choice is an **in-place edit** to the existing `DN`, and the log never contains two conflicting decisions. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* (marked as previously adopted) before overwriting; a mere sketch may be replaced outright. A decision retracted outright keeps its number as a one-line tombstone (`### DN: (retracted, YYYY-MM-DD)`).
- Once **`accepted`**, decision bodies are **protected**. A change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields; existing bodies are edited only through the `enhancement-compaction` skill, which weaves stacked reversals into the decisions they reverse (lower number survives, vacated number keeps a tombstone), at latest in the mandatory pass immediately before the `implemented` flip.
- **`implemented`** entries are frozen; **`superseded`** entries are stubbed via compaction.

Either way the log stays safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed.

Each decision carries a `**Kind:**` line plus the body fields: Decision, Requirements (numbered `Rn` items cited as `NNNN:DN:Rn`; `none` with a reason on a `policy` or `scope` decision), Alternatives considered, Rationale, Source. The Source field is specific: `"User decision YYYY-MM-DD"`, a URL, or a file path, so the provenance of a choice never gets lost. A decision revised in place or by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line. *Alternatives considered* always survives revision and compaction: it is what stops a rejected option being re-litigated later.

A decision that rests on another entry's decision also carries a `**Depends:** MMMM:DN` line (tokens only, comma-separated) directly after `Kind`, and `config.yaml.depends_on` lists exactly the entries those lines name; `task vet` enforces both directions and refuses a cycle. The test for whether the line is owed: *if that other decision were reversed, would this one need an `Amends:`?* If yes, it depends. A citation for precedent, contrast, or a delegated enforcement site is prose, not a dependency.

A decision that **changes** another entry's decision says so on the same relation fields it uses locally, with the token qualified: `**Amends:** MMMM:DN` when that decision survives narrowed, `**Supersedes:** MMMM:DN` when it is dead. `config.yaml.amends` lists exactly the entries those tokens name; `task vet` enforces both directions, requires a live heading, refuses a superseded or rejected target (amend the successor), refuses a cycle, and refuses one decision both depending on and superseding the same token. The amended entry is never edited, closed or not: `task show ID=MMMM` derives "amended by" from lines like these, so the reverse can never go stale and can say whether the change has landed. Depends is *I rest on it*; Amends is *I change it*; a decision may carry both for the same token when it narrows what it rests on.

**The Kind gate.** A decision belongs in this log only if it passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Three kinds pass it:

- `contract`: changes what a consumer can observe or rely on: a schema shape, a command's semantics, a compatibility or refusal rule, a naming guarantee.
- `policy`: a posture OPM commits to ("publish never invents a version").
- `scope`: a boundary decision: what this entry defers, what a successor owns, what a supersession keeps.

A *mechanism* decision is how a repo achieves the contract: algorithm choice, code placement, internal wiring. It fails the admission test and belongs in the implementing slice's OpenSpec change in the target repo, decided when the code in front of the implementer is current. Measured evidence that *constrains* a contract (an experiment proving a primitive cannot express a rule) stays here, attached to the contract decision it constrains. The winning implementation design does not carry it.

**Prescriptive versus evidential.** The line that keeps mechanism out in practice: an entry never tells a repo *how to name a file, spell an identifier, lay out a directory, or structure its code*.

- Naming a path to **prove** something, or to say where something is emitted today, is evidence, and is wanted.
- The test: would deleting the named path change what an implementer is **obliged** to do, or only what a reader can **verify**? Obliged means prescription; it does not belong here. Verify means provenance; it stays.
- A decision may state that a name is part of the published contract (for example, a member name that reaches a key, or a command's flag) because that is what a consumer observes. It may not state what the file holding it is called.

---

## Decisions

### D1: The operator is named the controller in every contract a user meets

**Kind:** contract

**Depends:** 0006:D3, 0006:D7, 0006:D18, 0006:D24, 0006:D32, 0006:D34, 0006:D35, 0021:D11

**Amends:** 0006:D3, 0006:D7, 0006:D18, 0006:D24, 0006:D32, 0006:D34, 0006:D35

**Decision:** OPM's in-cluster component is named the controller, and every contract that published its former name, "operator", publishes "controller" instead. The behaviour of each amended decision survives unchanged; what changes against it is the name it publishes:

- The ModuleInstance owner field takes `cli` or `controller`, and an absent owner still means the controller owns the instance; the value `operator` is no longer accepted (0006:D3).
- Handoff hands an instance to the controller by setting the owner to `controller`, and requires the controller to be installed and ready (0006:D7).
- The CLI's dual mode keys on the owner `controller` where it keyed on `operator` (0006:D18).
- The controller reports its running version in `controllerVersion` on the Platform's status, and the CLI's version ceiling reads that field and no other (0006:D24).
- The CLI command group is `opm controller`, with install, its CRDs-only form, and uninstall; no `opm operator` command exists (0006:D32, 0006:D34).
- The install artifact comes from the repository `open-platform-model/opm-controller`: its image is `ghcr.io/open-platform-model/opm-controller` (0006:D35).
- The module that deploys the controller is `opmodel.dev/modules/opm_controller`. That the install artifact is a registry module, applied as a CLI-owned instance, is 0021:D11 and stands; this decision rests on it and gives the module and the instance their names.
- The default install creates the instance `opm-controller` in namespace `opm-system`. Its Deployment and its ServiceAccount are named `opm-controller-manager`, and the Deployment selects its pods by the label `control-plane` with the value `manager`. The other objects the install creates carry the name prefix `opm-controller-`; that prefix is not confirmed for the namespace `opm-system` and is 0032:OQ1. Uninstall preserves the namespace `opm-system` as it preserved the former one (0006:D34).

The namespace does not carry the component's name. It is `opm-system`, not `opm-controller-system`.

No alias, fallback read, deprecation warning or migration covers the former names. The amended 0006 decisions keep the former names as written, and this decision is where they change. Within OPM's own text, "controller" names the product and "reconciler" names one of its per-kind reconcile loops. "Operator" keeps two senses only: the human platform operator, and an upstream application operator that a module deploys.

**Requirements:**

- R1: A ModuleInstance's owner accepts exactly `cli` and `controller`; the API server refuses `operator`. An instance with no owner is reconciled by the controller.
- R2: Handoff leaves the instance with owner `controller`.
- R3: The controller writes its running version to `controllerVersion` on the Platform's status, and the CLI's version ceiling reads only that field.
- R4: The CLI offers the controller's lifecycle under `opm controller`, and no `opm operator` command or alias exists.
- R5: The controller's image is published as `ghcr.io/open-platform-model/opm-controller`, the module that deploys it as `opmodel.dev/modules/opm_controller`, and the default install runs the instance `opm-controller` in namespace `opm-system`.
- R6: No OPM component accepts, reads, writes or translates a former name: there is no owner value `operator`, no status field for the operator version, no `opm operator` command, and no install under the former repository, image, module, namespace, workload or selector names.
- R7: OPM's own documentation, command help and condition messages call the product "the controller" and its per-kind loops "reconcilers"; "operator" appears there only for the human platform operator or an upstream application operator.
- R8: After the default install, the namespace `opm-system` holds a Deployment and a ServiceAccount named `opm-controller-manager`, and the controller's pods carry the label `control-plane` with the value `manager`.

**Alternatives considered:**

- **Keep the names 0006 published (0006:D3, 0006:D24, 0006:D32, 0006:D35).** The owner value `operator`, the status field `operatorVersion`, the command group `opm operator`, the `opm-operator` repository and image, the namespace `opm-operator-system`, and the selector value `controller-manager`. Not kept: "operator" means an application-specific controller in Kubernetes, and OPM's component is a generic delivery engine.
- **Rename with a transition window.** Accept both owner values, read both status fields, and keep `opm operator` as a hidden alias for a release. Not chosen: nobody runs OPM yet, so a window would only leave traces to remove later.
- **The namespace `opm-controller-system` (previously adopted by owner decision).** It followed the full rename of every name, namespace included. Not kept by the owner: the namespace is `opm-system`, and the Revised line below dates the change.
- **A glossary line instead of a rename.** Not chosen: every contract value, command and address would keep saying the opposite of the glossary.
- **Host the decision in entry 0021, which already amends five of these decisions (0006:D3, 0006:D24, 0006:D32, 0006:D34, 0006:D35).** Not chosen: 0021 decides versioning policy. The rename rests on one of its decisions, the module install of 0021:D11, and shares no premise with the others.

**Rationale:** The name is the first thing a Kubernetes reader uses to place the component, and "operator" places it beside application operators it does not resemble. A full rename with no window is the cheapest it will ever be: nobody runs OPM yet, and these names become permanent at the first `v1.0.0` release, so the rename runs before it. Splitting product from loops ("controller" and "reconciler") gives the docs a word for each.

**Source:** Owner decision 2026-10-05: full rename of the operator to the controller across repo, image, namespace, module, CLI noun, owner value and status field; no migration, no warning, no alias; "controller" is the product and the per-kind loops are "reconcilers"; the Deployment and the ServiceAccount are named `opm-controller-manager`; the decision amends 0006:D3, 0006:D7, 0006:D18, 0006:D24, 0006:D32, 0006:D34 and 0006:D35. The selector value `manager`: owner decision 2026-10-06. The namespace: owner decision 2026-10-09. Asked "These names become permanent at v1.0.0. Confirm them as decided on 2026-10-05: command `opm controller`, `spec.owner: controller`, `status.controllerVersion`, Deployment and ServiceAccount `opm-controller-manager`, selector `manager`, namespace `opm-controller-system`, CUE module `opm_controller`?", the owner answered "namespace should be opm-system. the rest are ok". Asked the same day "When does the rename run, relative to the remaining operator work and GA?", the owner chose "Kernel work, then rename, then GA (Recommended)". The label key `control-plane` and the former values `opm-operator-system` and `controller-manager` are read from the controller repository's install module and default manifests on 2026-10-09.

**Revised:** 2026-10-09, by owner decision: the namespace is `opm-system`, where the decision of 2026-10-05 had `opm-controller-system`. R5 names it, R8 is added for the workload names and the selector, and the earlier namespace moves to *Alternatives considered*.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
