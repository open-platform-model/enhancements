# Migration map: 0008

source: 0008 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0008/03-decisions.md`. The 9 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` target is `capability/Requirement name` in `specs/` of this folder. No requirement is cut, moved or left to a repo: the count stays at 9. 0008 restarts as a draft, so the open questions stay in the proposal. A decision row names one target for each of its dispositions, written `<disposition>: <name>`; a free note goes in the Note column.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0008:D1:R1 | kept | crd-source/A custom resource has one authored definition |  |
| 0008:D1:R2 | kept | crd-source/A generated schema rejects what core rejects |  |
| 0008:D1:R3 | kept | crd-source/Generation changes no resource |  |
| 0008:D4:R1 | kept | crd-facets/A resource's facets are authored in core |  |
| 0008:D4:R2 | kept | crd-facets/An invalid facet value is refused in core |  |
| 0008:D4:R3 | kept | crd-facets/A resource carries a version and defaults names |  |
| 0008:D6:R1 | kept | crd-validation-rules/A CEL rule is carried unchanged |  |
| 0008:D6:R2 | kept | crd-validation-rules/No CEL rule is invented or translated |  |
| 0008:D6:R3 | kept | crd-validation-rules/The Platform CRD carries its singleton rule |  |

Totals: kept 9, cut 0, repo 0, moved 0 (merged 0). Sum 9, equal to the 9 old ids (D1 3, D4 3, D6 3; D2, D3, D5, D7 and D8 state `Requirements: none` with a reason, kept in `decision-log.md`).

Each of the 9 new requirements has exactly one `kept` row. No `cut-requirements.md` is needed, so the file is absent.

## Decisions

Every `### Dn:` heading of the old log. The full reasoning, the alternatives and the sources of each decision are in `decision-log.md`. The design keeps one line for each rejected option. No decision is dropped.

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: CUE in `core/` is the single source of truth; Go types and CRD YAML are generated | design | design: One authored definition, in core | the rejected directions are one line each in Considered and rejected |
| D2: Generation runs downstream over the *published* `core`; `core/` stays pure CUE | design | design: One authored definition, in core | the shared generator repository is deferred, and stays a question in the proposal |
| D3: The CRD schema body is emitted via CUE's `encoding/openapi` in structural mode | design | design: The schema body comes from the CUE encoder |  |
| D4: Non-schema CRD facets are modelled as CUE data, not Go markers | design | design: Facets are CUE data | the rejected options are in Considered and rejected |
| D5: deepcopy stays controller-gen's job, run over the generated Go | design | design: Deepcopy stays with controller-gen |  |
| D6: CEL `x-kubernetes-validations` rules are carried verbatim, never translated | design | design: CEL passes through as text |  |
| D7: Drift is blocked by a regenerate-and-diff CI gate | design | design: A regenerate-and-diff gate blocks drift | building at build time only is deferred, and stays a question in the proposal |
| D8: `gengotypes` is an optional implementation detail, not a load-bearing dependency | design | design: Deepcopy stays with controller-gen | the generator's own boundary for Go emission is in the same theme |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | proposal (still open, not blocking) | Open questions |
| OQ2 | proposal (still open, blocks acceptance) | Open questions |
| OQ3 | proposal (still open, not blocking) | Open questions |
| OQ4 | proposal (still open, blocks acceptance) | Open questions |
| OQ5 | proposal (still open, blocks acceptance) | Open questions |

Counts: 5 questions. None was resolved in the old text, so all five stay in the proposal. OQ1 and OQ3 are not blocking (OQ3 was marked partial in the old register); OQ2, OQ4 and OQ5 blocked acceptance in the old register and still do. OQ5 asked for the semver impact on core. The `semver` field is gone, so the proposal asks the underlying question: does anchoring the CRDs change an existing field shape, which would make the change breaking. The old register is in `questions.md`.
