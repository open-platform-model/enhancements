# Mockup: enhancements as an OpenSpec store

This branch (`openspec-store-design`) tries out a new structure for enhancements. Nothing here is live. The real entries (`0013/` and the rest) are untouched.

| Path | What it is |
| --- | --- |
| `.openspec-store/store.yaml` | Makes this repo the store `opm-enhancements` |
| `openspec/schemas/enhancement/` | The schema and the four templates a new enhancement starts from |
| `openspec/specs/` | The contract by capability: every accepted requirement, delivered or not. Synced from the deltas at acceptance, never written by hand |
| `openspec/changes/0013-secret-field-attributes/` | 0013 in the new structure: accepted, so ready to implement and still in motion |
| `openspec/changes/archive/` | Empty. Only delivered and rejected enhancements go here |

What is real and what is not in the 0013 mock:

- It is an **excerpt**: five of the 36 decisions (D10, D11, D13, D25, D26) and ten of their requirements.
- The decision and requirement text is shortened from `0013/03-decisions.md`. The meaning is unchanged.
- The **scenarios are new drafts**. The real entry has none, and nobody has reviewed these.
- `openspec/specs/instance-export/spec.md` was seeded with two requirements of 0014, as if 0014 were already accepted, so that 0013 has something to modify.
- `delivery.yaml` is a two-line excerpt of the real log.
- The specs were synced by running `openspec archive` and moving the folder back. OpenSpec has no command that syncs without archiving; the accept step needs one.
- `evidence/` is a pointer. The real experiments, research and CUE schemas were not copied.
