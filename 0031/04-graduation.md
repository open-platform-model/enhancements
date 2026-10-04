# Graduation Criteria: Module Presentation Contract

These are design acceptance criteria, not implementation milestones: delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`. The entry's documents store nothing about delivery progress.

Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs resolve) live in `gates.cue` and `task vet`, not here. What belongs here is what is true of this design and no other.

## draft → accepted

- **Its substrate is accepted.** Entry 0022 is accepted with its block admitting keys it does not define (the open tail), so a core that predates the card passes a module that carries one. Entry 0027 is accepted with its served-schema questions answered (0027:OQ18 to 0027:OQ22) and the presentation block admitted on the definition (0027:OQ17).
- **The acceptance-blocking questions are answered.** OQ1 (tenant read path), OQ2 (category type), OQ3 (status-carried data), OQ8 (index artifact kind), OQ9 (conditional fields), OQ10 (where hints travel), OQ11 (schema and form agreement), OQ12 (secret paths), OQ13 (bound fields and secret bindings), OQ17 (card images) and OQ18 (rune or byte caps) are resolved into decisions or moved to 0027 with a citation.
- **The size line is the card's only byte bound.** The field caps count runes and the size line counts bytes, so a card within every field cap can still be refused (`schemas/examples.cue` records a 13,641-byte CJK card at every cap). An ASCII card at every cap stays pinned under 8192 bytes, and every surface that documents the card says the size line can refuse a card that passes the field caps.
- **The hint vocabulary compiles and is closed.** `contracts/hints.cue` lists every key, every refused attribute form, and every name deliberately left out, and every refusal in 0031:D4:R3 maps to an entry there.
- **The index publish path exists in the design.** 0031:D7:R1 names a check that runs instead of the module gates; OQ8's answer says which artifact kind carries it.
- **Every contract decision is observable from outside one repo.** Each `Rn` names something an author, a platform operator or a reader can see hold or fail, with no Go symbol, flag or file path.
- **No document prescribes mechanism.** Paths in the entry are evidence (where something was measured or is emitted), never the address of an edit.
- **`semver` is set.** The card, index and presentation definitions are additive to core; the amendment of 0013:D2 changes what a reader may do with a field's attributes.
