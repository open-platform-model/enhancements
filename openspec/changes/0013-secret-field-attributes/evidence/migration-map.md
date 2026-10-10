# Migration map: 0013

source: 0013 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0013/03-decisions.md`. The 100 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` and `merged` target is `capability/Requirement name` in `specs/` of this folder. A `cut` or `repo` target is the line of `cut-requirements.md` that starts with the old id. A `moved` target is `NNNN capability/Name` in the receiving entry; 0014 is still in the old layout, so the capability and the names are proposed, and the migration of 0014 (wave C) settles them. 0013 restarts as a draft, so the open question OQ9 stays in the proposal.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0013:D2:R1 | merged | secret-declaration/A secret is declared by type and attribute |  |
| 0013:D2:R2 | merged | secret-declaration/A secret is declared by type and attribute |  |
| 0013:D2:R3 | merged | secret-declaration/A secret is declared by type and attribute | the defaults are in the first scenario |
| 0013:D3:R1 | kept | secret-declaration/A module's secrets are listable without values |  |
| 0013:D3:R2 | merged | secret-declaration/Every declared form of a secret is discovered | second scenario |
| 0013:D3:R3 | merged | secret-declaration/Every declared form of a secret is discovered | first scenario |
| 0013:D5:R1 | kept | secret-resolution/A secret group renders to one object name |  |
| 0013:D5:R2 | merged | secret-resolution/A secret group renders to one object name |  |
| 0013:D6:R1 | merged | secret-resolution/A secret group renders to one object name |  |
| 0013:D6:R2 | merged | secret-resolution/A secret group renders to one object name | components that consume one group reach the same object |
| 0013:D6:R3 | kept | secret-resolution/Members of a group must agree |  |
| 0013:D6:R4 | repo | cut-requirements.md: 0013:D6:R4 | dead special-case component name; the catalog and library changes remove it |
| 0013:D7:R1 | cut | cut-requirements.md: 0013:D7:R1 | superseded by the named-source arm: a third form is now accepted (D18 R1, merged into the sources capability) |
| 0013:D7:R2 | merged | secret-declaration/The deployer chooses how a secret is supplied | literal materialises, reference materialises nothing |
| 0013:D8:R1 | merged | secret-sources/A platform carries several secret sources | a module names no backend |
| 0013:D8:R2 | merged | secret-sources/A platform carries several secret sources | a catalog adds a source with no core or kernel change |
| 0013:D8:R3 | cut | cut-requirements.md: 0013:D8:R3 | superseded: the deployer names the source by contract name, the platform no longer supplies one FQN |
| 0013:D9:R1 | merged | secret-declaration/Core alone defines the secret type | second scenario |
| 0013:D9:R2 | repo | cut-requirements.md: 0013:D9:R2 | the hand-authored Secret shape takes string data only |
| 0013:D10:R1 | merged | secret-declaration/A secret is declared by type and attribute; secret-declaration/A malformed secret value is rejected | the declaration is in the first, the bare scalar and arm shape in the second |
| 0013:D10:R2 | merged | secret-declaration/A secret is declared by type and attribute; secret-declaration/A malformed secret value is rejected | routing only in the attribute; a routing field in a value is rejected |
| 0013:D10:R3 | kept | secret-declaration/The deployer chooses how a secret is supplied |  |
| 0013:D10:R4 | merged | secret-declaration/The deployer chooses how a secret is supplied |  |
| 0013:D10:R5 | merged | secret-declaration/A malformed secret value is rejected |  |
| 0013:D10:R6 | merged | secret-resolution/An unfulfilled secret fails every render | CUE validation with concreteness names the path |
| 0013:D11:R1 | kept | secret-resolution/Every secret renders as a reference |  |
| 0013:D11:R2 | kept | secret-resolution/Supplied plaintext stays out of the render |  |
| 0013:D11:R3 | merged | secret-resolution/Supplied plaintext stays out of the render | third scenario |
| 0013:D11:R4 | repo | cut-requirements.md: 0013:D11:R4 | a diagnostic for a module that reads a resolved secret value |
| 0013:D12:R1 | kept | secret-declaration/Core alone defines the secret type |  |
| 0013:D12:R2 | merged | secret-declaration/Core alone defines the secret type | the arms are a ref and a key |
| 0013:D12:R3 | merged | secret-declaration/Core alone defines the secret type | the withdrawn vocabulary fails to type-check |
| 0013:D12:R4 | repo | cut-requirements.md: 0013:D12:R4 | core specification text: the secret type is a config-value type, not a primitive |
| 0013:D13:R1 | kept | secret-declaration/An unmarked secret field is still discovered |  |
| 0013:D13:R2 | merged | secret-declaration/An unmarked secret field is still discovered |  |
| 0013:D14:R1 | kept | secret-tooling/A SOPS-encrypted values file is accepted |  |
| 0013:D14:R2 | kept | secret-tooling/The CLI lists and reports a module's secrets |  |
| 0013:D14:R3 | merged | secret-tooling/The CLI lists and reports a module's secrets | second scenario |
| 0013:D14:R4 | moved | 0014 instance-export/Secret-bearing export output can be SOPS-encrypted | the export half of D14 |
| 0013:D15:R1 | kept | secret-tooling/An instance resource may carry a literal |  |
| 0013:D15:R2 | merged | secret-tooling/An instance resource may carry a literal | documentation scenario |
| 0013:D16:R1 | merged | secret-declaration/A malformed secret value is rejected | the part that survives is validation of the values as written; the value in the error is replaced by redaction |
| 0013:D16:R2 | repo | cut-requirements.md: 0013:D16:R2 | the build shape: the instance artifact validates on its own, apart from the render |
| 0013:D17:R1 | merged | secret-resolution/Supplied plaintext stays out of the render | the deployer's values file stays unmodified |
| 0013:D18:R1 | merged | secret-sources/A platform carries several secret sources | a named source is a third way to supply a secret; the same module accepts it |
| 0013:D18:R2 | merged | secret-sources/A platform carries several secret sources |  |
| 0013:D18:R3 | merged | secret-sources/A literal renders through the literal source |  |
| 0013:D18:R4 | repo | cut-requirements.md: 0013:D18:R4 | the shared input envelope, and a source schema that must accept it fails vet in its catalog |
| 0013:D19:R1 | kept | secret-sources/A platform carries several secret sources |  |
| 0013:D19:R2 | merged | secret-sources/A platform carries several secret sources | the sources apply per secret and per environment |
| 0013:D19:R3 | merged | secret-sources/A source is named by its contract name | the list of installed sources is in the error |
| 0013:D19:R4 | cut | cut-requirements.md: 0013:D19:R4 | superseded: with exact contract names an ambiguous short name cannot arise (D29) |
| 0013:D19:R5 | merged | secret-resolution/Members of a group must agree |  |
| 0013:D19:R6 | merged | secret-resolution/Every secret renders as a reference |  |
| 0013:D20:R1 | repo | cut-requirements.md: 0013:D20:R1 | a catalog marks a primitive for a kernel feature by an annotation under the reserved prefix, with no core schema change |
| 0013:D20:R2 | repo | cut-requirements.md: 0013:D20:R2 | one annotation key per kernel feature, several features per primitive |
| 0013:D20:R3 | repo | cut-requirements.md: 0013:D20:R3 | the kernel interprets only the reserved prefix |
| 0013:D21:R1 | kept | secret-sources/A platform sets a source's settings |  |
| 0013:D21:R2 | merged | secret-sources/A platform sets a source's settings |  |
| 0013:D22:R1 | merged | secret-sources/A literal renders through the literal source | the first-party catalog ships the literal source |
| 0013:D22:R2 | merged | secret-resolution/A secret group renders to one object name | the rendered Secret carries exactly the computed name |
| 0013:D22:R3 | repo | cut-requirements.md: 0013:D22:R3 | the hand-authored secrets resource renders unchanged |
| 0013:D23:R1 | merged | secret-sources/Synthesised secret components pass authored checks |  |
| 0013:D24:R1 | kept | secret-sources/A secret source in use is a dependency |  |
| 0013:D25:R1 | merged | secret-resolution/Supplied plaintext stays out of the render | third scenario |
| 0013:D25:R2 | merged | secret-resolution/Supplied plaintext stays out of the render | third scenario |
| 0013:D26:R1 | moved | 0014 instance-export/Exported secret values are encrypted |  |
| 0013:D26:R2 | moved | 0014 instance-export/An exported instance renders as the original |  |
| 0013:D27:R1 | merged | secret-tooling/An instance resource may carry a literal | first scenario |
| 0013:D27:R2 | merged | secret-tooling/An instance resource may carry a literal | second scenario |
| 0013:D28:R1 | kept | secret-resolution/Diagnostics never carry a secret value |  |
| 0013:D28:R2 | merged | secret-resolution/Diagnostics never carry a secret value |  |
| 0013:D29:R1 | kept | secret-sources/A source is named by its contract name |  |
| 0013:D29:R2 | merged | secret-sources/A source is named by its contract name |  |
| 0013:D29:R3 | merged | secret-sources/A source is named by its contract name | second scenario |
| 0013:D30:R1 | kept | secret-sources/A literal renders through the literal source |  |
| 0013:D30:R2 | merged | secret-sources/A literal renders through the literal source |  |
| 0013:D30:R3 | repo | cut-requirements.md: 0013:D30:R3 | a catalog release rule: graduating the literal source leaves platforms routable, enforced by the catalog's own vet |
| 0013:D31:R1 | merged | secret-resolution/Members of a group must agree |  |
| 0013:D31:R2 | merged | secret-sources/A platform sets a source's settings | second scenario |
| 0013:D31:R3 | merged | secret-sources/A platform sets a source's settings | platform defaults scenario |
| 0013:D32:R1 | merged | secret-sources/A platform sets a source's settings |  |
| 0013:D32:R2 | merged | secret-sources/A platform sets a source's settings |  |
| 0013:D32:R3 | merged | secret-sources/A platform sets a source's settings |  |
| 0013:D32:R4 | repo | cut-requirements.md: 0013:D32:R4 | the platform carrier for source settings; its round trip is not yet measured |
| 0013:D33:R1 | kept | secret-declaration/Every declared form of a secret is discovered |  |
| 0013:D33:R2 | merged | secret-declaration/Every declared form of a secret is discovered |  |
| 0013:D33:R3 | merged | secret-resolution/An unfulfilled secret fails every render | second scenario |
| 0013:D33:R4 | merged | secret-declaration/A module's secrets are listable without values |  |
| 0013:D33:R5 | merged | secret-declaration/Every declared form of a secret is discovered | second scenario |
| 0013:D34:R1 | kept | secret-declaration/A malformed secret value is rejected |  |
| 0013:D34:R2 | kept | secret-resolution/An unfulfilled secret fails every render |  |
| 0013:D34:R3 | repo | cut-requirements.md: 0013:D34:R3 | the hidden values check adds no module default to the exported values |
| 0013:D34:R4 | merged | secret-resolution/Diagnostics never carry a secret value |  |
| 0013:D35:R1 | merged | secret-sources/Synthesised secret components pass authored checks |  |
| 0013:D35:R2 | repo | cut-requirements.md: 0013:D35:R2 | every object a synthesised component renders is recorded under it in every inventory |
| 0013:D35:R3 | merged | secret-sources/Synthesised secret components pass authored checks |  |
| 0013:D35:R4 | merged | secret-sources/Synthesised secret components pass authored checks | second scenario |
| 0013:D35:R5 | repo | cut-requirements.md: 0013:D35:R5 | an instance declaring a component its module does not declare fails naming it; not specific to secrets |
| 0013:D36:R1 | merged | secret-resolution/Diagnostics never carry a secret value |  |

Totals: kept 20, merged 59, cut 3, repo 15, moved 3. Sum 100, equal to the 100 old ids (D2 3, D3 3, D5 2, D6 4, D7 2, D8 3, D9 2, D10 6, D11 4, D12 4, D13 2, D14 4, D15 2, D16 2, D17 1, D18 4, D19 6, D20 3, D21 2, D22 3, D23 1, D24 1, D25 2, D26 2, D27 2, D28 2, D29 3, D30 3, D31 3, D32 4, D33 5, D34 4, D35 5, D36 1; D1 and D4 have none).

The 22 new requirements carry 20 `kept` and 59 `merged` old ones. An old requirement is `merged` only where the new text or one of its scenarios states its claim.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning and the alternatives of each decision are in `decision-log.md`. The design keeps one line for each rejected option someone would propose again. No decision is dropped.

| Old heading | Disposition | Target |
| --- | --- | --- |
| D1: A sensitive field is marked with a CUE field attribute, not typed with a contract struct | evidence; design | evidence: decision-log.md; design: Considered and rejected. superseded by D10 the day it was written; the full text is in decision-log.md |
| D2: The marker reuses the existing `@opm(...)` namespace, dispatched on position 0 | design | design: A secret is declared once |
| D3: Discovery reads the module's `#config` schema, not the instance's values | design | design: The schema declares, discovery finds |
| D4: The kernel substitutes an opaque handle for every marked value before components are built | evidence; design | evidence: decision-log.md; design: Considered and rejected. superseded by D11 the day it was written; the handle is a rejected option in the design, and the full text is in decision-log.md |
| D5: Secret object naming is owned solely by the kernel | design | design: One object name per group |
| D6: OPM-owned Secret objects are instance-scoped and group-named, not component-scoped | design | design: One object name per group |
| D7: Two fulfilment kinds ship, supplied and referenced | design | design: A secret is declared once; design: Sources are catalog resources. superseded by D18; the two arms are in the first theme and the open arm in the fifth |
| D8: How a supplied secret is materialised is a platform choice, resolved through catalog subscription | design | design: Sources are catalog resources. superseded by D19; its backend-neutral stance lives in the fifth theme |
| D9: The dead and duplicated secret machinery is deleted, not deprecated | design | design: A secret is declared once |
| D10: The secret field is typed `#Secret`, a two-arm disjunction; the attribute carries routing only | design | design: A secret is declared once |
| D11: The kernel resolves in place; it rewrites each secret value to its `#SecretRef` form | design | design: Secrets resolve in place |
| D12: `#Secret` lives in `core`, and `core` is its only definition | design | design: A secret is declared once |
| D13: Discovery keys on the type and the marker, and fails closed | design | design: The schema declares, discovery finds |
| D14: SOPS support lands at the file seams, decrypt on input, encrypt on export; never an arm, a backend, or kernel code | design | design: Encryption stays at the edge. the export half moved to 0014 (D14 R4) |
| D15: The operator path accepts literals in the CR, documented as plaintext at rest; no `valuesFrom` indirection | design | design: Encryption stays at the edge |
| D16: The rewrite is omission at build assembly, measured viable on the real kernel path, one graph build, no new kernel seams | design | design: Secrets resolve in place |
| D17: The Resolve rewrite mechanism is decode → splice → encode, on evaluated data, not AST, not FillPath-graft | design | design: Secrets resolve in place |
| D18: `#Secret` gains an open source arm; the literal stays as sugar; core defines the source input once | design | design: Sources are catalog resources |
| D19: A secret source is a catalog-defined resource; the platform installs any number side by side; the deployer chooses per value | design | design: Sources are catalog resources |
| D20: Kernel-interpreted primitive annotations live under a reserved `opmodel.dev/` prefix, one key per feature | design | design: Sources are catalog resources |
| D21: A source's settings default at the platform; the source decides what a deployer may override | design | design: Sources are catalog resources |
| D22: catalog_opm ships the literal source as a new resource, beside the hand-authored secrets resource | design | design: Sources are catalog resources |
| D23: The synthesised secrets component uses a key no author can write | design | design: Mistakes fail loudly |
| D24: The kernel reports every contract a render required, synthesised components included | design | design: Mistakes fail loudly |
| D25: An authored instance package refuses literal secrets | design | design: Secrets resolve in place |
| D26: Exported instances encrypt the literal values at marked paths | design | design: Encryption stays at the edge. the design says export encryption belongs to enhancement 0014; the requirement lines moved to 0014 |
| D27: The CLI writes raw values to the instance it applies; plaintext at rest covers that path too | design | design: Encryption stays at the edge |
| D28: Diagnostics never carry a value at a marked path | design | design: Mistakes fail loudly |
| D29: A secret source is named by its exact contract FQN; the annotation only marks what is a source | design | design: Sources are catalog resources |
| D30: `#SecretLiteral` resolves to the one source marked `literal`; a platform with two is not routable | design | design: Sources are catalog resources |
| D31: A source's settings are their own field; a group agrees on source and settings | design | design: Sources are catalog resources |
| D32: A platform fills a source's settings through its catalog entry, and the operator and CLI carry that fill | design | design: Sources are catalog resources |
| D33: Core tags each `#Secret` arm; discovery walks the schema for listing and the unified values for completeness | design | design: The schema declares, discovery finds |
| D34: A deployer's values are checked against `#config` on every path, without changing what the instance exports | design | design: Mistakes fail loudly |
| D35: A synthesised component is held to what an authored one is | design | design: Mistakes fail loudly |
| D36: Redaction covers synthesised components, whose spec is never a readable field | design | design: Mistakes fail loudly |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | design (answered by D10) | A secret is declared once |
| OQ2 | design (answered by D16, measured by experiment 03) | Secrets resolve in place |
| OQ3 | design (answered by D34, measured in the research note) | Mistakes fail loudly |
| OQ4 | design (answered by D32, measured in the research note) | Sources are catalog resources |
| OQ5 | design (answered by D35, measured in the research note) | Mistakes fail loudly |
| OQ6 | design (answered by D35, measured in the research note) | Mistakes fail loudly |
| OQ7 | design (answered by D29, measured in the research note) | Sources are catalog resources |
| OQ8 | design (answered by D33, measured in the research note) | The schema declares, discovery finds |
| OQ9 | proposal (still open, blocks implementation) | Open questions |

Counts: 9 questions. OQ1 to OQ8 were resolved in the old text and move into the design as answers. OQ9 is open and stays in the proposal as a blocking question. The old register is in `questions.md`.
