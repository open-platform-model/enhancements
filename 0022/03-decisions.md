# Design Decisions: Machine-Readable Artifact Metadata in cue.mod/module.cue

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent**: never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, decisions are living text revised in place, with evidence-backed old positions folded into *Alternatives considered*. Once `accepted`, bodies are protected and a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: The block lives at `custom."opmodel.dev@v0"` in `cue.mod/module.cue`, and the suffix is the block's schema major

**Kind:** contract

**Decision:** OPM's artifact metadata is a struct under the `custom` field of `cue.mod/module.cue`, keyed `"opmodel.dev@v0"`. The `@v0` suffix versions the block's own shape: it is bumped only when a key changes meaning or is removed, never for an added key. A reader ignores keys it does not know. The block holds concrete data only, because CUE parses the module file in data mode.

**Alternatives considered:**

- *Key `"opmodel.dev"` with no suffix.* This is what CUE's documentation calls conventional and what CUE's own unit test uses. Rejected: CUE's schema file also defines a stricter `#Strict` variant whose key regex requires an `@vN` suffix. Nothing enforces it today, but a published convention is permanent, and a key that satisfies both schemas costs nothing.
- *Manifest annotations for everything.* Rejected as the primary channel: annotations are not read by any CUE tooling, cannot be validated by the gate that CUE's evaluation makes cheap, and are not in the artifact's content-addressed bytes. They remain the right channel for push-time facts (D6).
- *A third OCI layer.* Rejected: CUE's client refuses a module manifest that does not have exactly two layers.
- *A sidecar artifact or referrer.* Rejected: a second publish step, a second distribution channel, and content that can drift from the module it describes.

**Rationale:** CUE reserved this field for exactly this use, carries it through every rewrite and ships it byte-verbatim in the registry. Using it means no CUE consumer changes and no OPM-specific fetcher exists. The suffix is a free insurance policy and doubles as the version a reader checks before trusting the shape.

**Source:** User decision 2026-08-24. Verified in cuelang.org/go v0.17.1: `mod/modfile/schema.cue` (the `custom` declaration and the `#Strict` key regex), `internal/mod/modload/tidy.go` (the block is carried across `tidy`), `mod/modregistry/client.go` (module file pushed and fetched verbatim); shipped in CUE v0.9.0.

### D2: The block carries `kind`, `identity`, `core` and `catalogs`, and nothing about toolchains

**Kind:** contract

**Decision:** The block has four required fields:

- `kind`: one of `module`, `catalog`, `template`.
- `identity`: repeats the identity package's `ModulePath` and `Version`.
- `core`: names the core line as `major` and the exact `version` pinned in `deps`.
- `catalogs`: maps every catalog dependency (module path with major) to its pinned version, and may be empty.

Nothing about the toolchain that authored the file lives in the block.

**Alternatives considered:**

- *Only fields the module file does not already state (`kind` alone, or `kind` plus a list of catalog keys).* The tighter shape, and the entry's own first draft. Rejected by the owner: a reader that holds the module file should not have to know how `deps` keys are spelled or where the identity version lives; the duplication is the feature, and D4 makes it safe.
- *`builtWith {cue, opm}` in the block.* Rejected: publish never writes the tree (0011 D2), so the only tooling that could write it is the version writer, and "the opm that last set the version" is neither the publisher nor a floor anyone needs; `language.version` already states the one cue value with semantics. Push-time provenance goes to annotations (D6).
- *`identity` as a single `fqn` string.* Rejected: two named fields are what `#IdentityPackage` authors, and the gate asserts each against its own source.

**Rationale:** The four fields answer the questions a consumer asks before paying for the zip: what is this, which artifact exactly, which core line, which catalogs. Each is either not in the file at all (`kind`, `identity.Version`) or is a projection the gate keeps honest.

**Source:** User decision 2026-08-24.

### D3: Module, catalog and template artifacts carry the block; `core` and `library` do not

**Kind:** scope

**Decision:** The block is required (after D8's window) on every artifact OPM publishes as a module, a catalog or a template. `opmodel.dev/core` carries no block, and `library` publishes no CUE artifact.

**Alternatives considered:**

- *Core carries a block with `kind: "core"`.* Rejected: nothing selects core by kind or by compatibility; it is the thing compatibility is measured against.

**Rationale:** Templates are module-kind artifacts published through `opm module publish` (0011 D25) and gain the block by the same path; catalogs are the other artifact publish knows. Adding a kind for the one artifact no reader asks about would be surface without a consumer.

**Source:** User decision 2026-08-24.

### D4: A core-shipped publish gate asserts every duplicated value, and a mismatch refuses

**Kind:** contract

**Decision:** `core` ships a publish gate beside `#IdentityPackage` that states each duplicated field twice: as the block declares it and as the module file and identity package imply it. `identity.ModulePath` is `module:`; `identity.Version` is the identity package's `Version`; `core.version` is the `deps` pin of `opmodel.dev/core@<core.major>`; `catalogs` holds every `opmodel.dev/catalogs/*` dependency at its pin and nothing that is not a dependency. Publish unifies the block against the gate and refuses on conflict with CUE's own diagnostic, naming the writer verb that repairs the tree. Publish never edits the block (0011 D16).

**Alternatives considered:**

- *Auto-fix at publish.* Rejected: 0011 D2 and D16 forbid publish writing into the tree, and an auto-fixed value is one the author never reviewed.
- *A Go-side comparator.* Rejected for the reason 0011 D21 gives: a second statement of the contract drifts, and CUE's diagnostic at the field is the better error.
- *Assert `kind` against the path prefix.* Left open (OQ2): inside OPM-owned domains the path already implies the kind, and asserting agreement is cheap; outside them there is nothing to assert against.

**Rationale:** Duplication is only safe when it is checked at the one moment both copies are in hand, which is publish. The identity gate proved the mechanism; this gate adds inputs, not machinery.

**Source:** User decision 2026-08-24. Mechanism: enhancement 0011 D21, `core/src/identity_package.cue` (`#CatalogMemberFQNGate` states declared beside implied the same way).

### D5: Tooling authors the block in the tree; publish never writes it

**Kind:** policy

**Decision:** The block is written by the same tooling 0011 already trusts with the tree. `opm module init` seeds it when it seeds the identity package; `version set` and `publish --version` keep `identity.Version` in step when they write the identity version; template re-identification rewrites `identity.ModulePath` when it rewrites `module:`. Each write is surgical (comments preserved, no-op when the value already matches), as the identity writer is. Publish reads and refuses, never writes.

This extends 0011 D3 and D8, which name `identity/identity.cue` `Version` as the version writer's only target. Once this entry is accepted, 0011 gains a new decision carrying `**Amends:** D3, D8`: the writer keeps every schema-fixed copy of `Version` in step. The wording is OQ4.

**Alternatives considered:**

- *Publish generates the block into the pushed zip.* Rejected: contradicts 0011 D2 outright; published bytes would no longer be committed bytes, and the block would exist in no commit.
- *A dedicated `opm module sync` verb as the only writer.* Not chosen as the primary path: a separate verb is one more step to forget between `version set` and `publish`, and the version writer already runs at the right moment. A repair verb may still exist for trees that predate the block (D8).

**Rationale:** The block's release-varying value is `identity.Version`, and the tool that changes the version is the one that knows the new value. Everything else in the block changes only when `module:` or `deps` change, which `init`, re-identification and dependency updates already own.

**Source:** User decision 2026-08-24. Enhancement 0011 D3, D8, D12 (the version writer), D16 (publish never edits), D20 (init repairs an existing tree).

### D6: Push-time provenance lives in OCI manifest annotations, never in the tree

**Kind:** policy

**Decision:** Publish writes OCI manifest annotations beside CUE's own `org.cuelang.vcs-type`, `-commit` and `-commit-time`: the publishing `opm` version, the CUE toolchain version, and any further `dev.opmodel.*` key `contracts/` lists. Annotations are written through the client call CUE provides for module metadata, are not part of the zip or the module file, and are never required by any gate.

**Alternatives considered:**

- *Provenance in the block.* Rejected with D2: the tree cannot know who will publish it.
- *No provenance at all.* Rejected: it is the one fact this entry adds that no amount of parsing recovers, and it costs one map on a call publish already makes.

**Rationale:** The manifest is where CUE puts facts about the act of publishing, and a consumer that lists a tag already has the manifest in hand.

**Source:** User decision 2026-08-24. cuelang.org/go v0.17.1 `mod/modregistry/metadata.go` (annotation keys, unknown keys ignored).

### D7: 0016's major walk is the first reader, and a missing block falls back to parsing `deps`

**Kind:** scope

**Decision:** The first consumer of the block is `opm instance init`'s selection walk (0016 D5). For each candidate major it reads `kind` (refusing anything but `module`) and `core.major` (comparing against the CLI's core major). When the block is absent, the walk does what it does today: parse `deps` for the `opmodel.dev/core@vN` key, treating absence as incompatible. The two rules agree by construction on any artifact published with the block.

**Alternatives considered:**

- *Refuse artifacts without the block.* Rejected: it would make every artifact published before this entry unselectable by a command whose purpose is to work against the existing fleet.

**Rationale:** A reader that exists and already fetches the blob is the cheapest proof that the block is worth writing, and the fallback keeps the fleet usable during D8's window.

**Source:** User decision 2026-08-24. Enhancement 0016 D5 and experiment 02.

### D8: A missing block is a warning first and a refusal only from a dated release

**Kind:** policy

**Decision:** Publish warns on a missing block from the release that ships the writer, and refuses from a later, dated release named in the CLI changelog. Already-published artifacts are never affected. `opm module vet` reports the same condition.

**Alternatives considered:**

- *Refuse immediately.* Rejected: every existing tree would fail its next publish until someone ran the writer, for a field nothing reads yet.
- *Never refuse.* Rejected: a block that may be absent forever is a block readers cannot rely on, and D7's fallback would become permanent.

**Rationale:** Additive schema changes carry a floor, and the floor should arrive after the tooling that meets it.

**Source:** User decision 2026-08-24.

Open Questions live in [`07-questions.md`](07-questions.md), the entry's question register.
