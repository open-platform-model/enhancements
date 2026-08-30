# Decisions: Kernel render path parity with pure CUE

## Decisions

### D1: Pure-CUE unification is the parity oracle, and divergence is closed by removing kernel behaviour

**Decision:** The reference semantics of the render path are whatever plain CUE unification of `#transform` with its three inputs produces. Where the kernel differs, the kernel is defective. Divergences are closed by **deleting** the kernel behaviour that causes them, not by adding kernel behaviour that emulates CUE more faithfully. The equality is enforced by a differential parity harness in `library`, not by review.

**Alternatives considered:**

- **Treat the current behaviour as the contract and document it.** Rejected: it makes every schema-computed projection permanently unreachable from the render path, and forces `core` to design around a Go-side artifact. The workarounds in open-platform-model/core#49 and open-platform-model/catalog_opm#44 are the first instalment of that tax.
- **Keep the strip and add explicit passthrough for specific fields** (for example, plumb `#names` into a new `#TransformerContext` slot). Rejected: it makes every future projection an explicit plumbing job, and each one is a kernel addition rather than a removal.
- **State parity as a principle without a harness.** Rejected: the current divergence survived three months and two structural refactors precisely because nothing measured it.

**Rationale:** OPM's value proposition is that the schema computes things and everything downstream reads what it computed. A render path that silently narrows the value it passes on is not a wrapper around CUE; it is a reinterpretation of it, and the reinterpretation is invisible to authors until their transformer fails. Making CUE the oracle also makes the kernel's surface shrink over time by default, because every parity failure has removal as its natural fix.

**Source:** User decision 2026-08-19: "It is very important that OPM kernel keep compatability with pure CUE in this regards. I rather remove shit from the kernel to be compatible then to keep it." Evidence: `experiments/00-purecue-definitions/` (pure CUE renders all eight probed fields concretely, `cue vet -c` exit 0, with a genuinely closed component), and `experiments/01-purecue-render-flow/` (the whole flow expressed as CUE against the real published catalog, outcome 2026-08-19).

### D2: `#transform` executes once per (component, transformer) pair, and `#component` stays singular

**Decision:** The unit of execution is one component. `#component` carries exactly one `#Component`, and the kernel iterates matched pairs. This is the original design intent of the transformer schema, not an artifact of the current implementation, and it is not revisited by this enhancement.

**Alternatives considered:**

- **Pass the component map and let a transformer select.** Rejected on author-facing complexity and on losing per-pair independence, which is what makes the render deterministic and per-pair errors attributable.
- **Leave the question open.** Rejected: `#moduleInstance` reaches sibling components (see OQ4), so the invariant needs to be stated explicitly before that slot is filled, or it silently becomes a convention nobody wrote down.

**Rationale:** Recording the intent matters more than the mechanism here. The current kernel already behaves this way, so nothing changes in code; what changes is that a future reader can tell the difference between a deliberate contract and an implementation detail.

**Source:** User decision 2026-08-19: "I originally designed the transformers schema so that it took one #component because i wanted to execute each transformer on a single component and not multiple."

### D3: `#moduleInstance` is filled by the kernel; it is not removed from the schema

**Decision:** `#transform.#moduleInstance` is intended surface, added so a transformer author can read instance data. The kernel fills it concretely, matching the contract already stated in `core/src/transformer.cue` ("The runtime supplies all three inputs concretely"). Removing the slot from the schema is rejected.

**Alternatives considered:**

- **Delete the slot.** Rejected by the author: the slot is intentional. Deleting it would also close a capability that the pure-CUE control shows works correctly today.
- **Narrow it to instance metadata only.** Rejected as redundant with `#context.#moduleInstanceMetadata`, and as a divergence from CUE in its own right, since a wrapper would hand over the whole value.
- **Leave it unfilled and document it as reserved.** Rejected on the measured failure mode: a transformer reading it vets clean, publishes, and fails at render with a message naming a disjunction rather than the slot.

**Rationale:** The slot is sound. The pure-CUE control fills all three inputs and renders concretely, including the self-referential case where the instance filled into `#moduleInstance` contains the very component filled into `#component`, with no cycle and no error. Only the filler is missing.

**Source:** User decision 2026-08-19: "The comment in transformer.cue even says `#moduleInstance: _ // Fully concrete #ModuleInstance (D18)`. This is the intended behavior." Tracked as open-platform-model/library#65.

### D4: The work lands as several small slices, ordered by what each one removes

**Decision:** This enhancement is executed as a sequence of narrow per-repo changes rather than one render-path rewrite. The parity harness lands first, so every subsequent slice is checked against the oracle rather than against the existing suite. The flow-test fixture's instance construction is repaired inside the slice that exposes definitions, not after it.

**Alternatives considered:**

- **One change that rewrites the render path.** Rejected against the `library` execution gate, which names "redesigning the compile pipeline in one go" as its example of an oversized request, and on risk: the fixture defect below turns a green suite into a false negative if the ordering is wrong.
- **Land the fills first and the harness afterwards.** Rejected: the harness's first failure is the primary evidence for D1, and writing it after the fix discards that.

**Rationale:** The ordering is not administrative. Exposing definitions before repairing the flow fixture would change that fixture from shipping no value to shipping a broken one, because its instance is built by `LookupPath` plus `FillPath` and never wires `#instance`. That is the one sequencing constraint the measurements actually produced.

**Source:** User decision 2026-08-19: "I suggest we split this into multiple openspec changes." Sequencing constraint measured 2026-08-19 against `TestFlow_WebApp_OnOpmPlatform` (`#names.dns.fqdn` reports `required field missing: namespace` in place, while the `synth.Instance` path resolves it).

### D5: A platform imports its catalog and embeds it whole into the registry entry, which derives everything else

**Resolves:** OQ6 (with D13)

**Decision:** `#Platform.#registry` stops naming a catalog by a version string and starts carrying the catalog itself by import. A registry entry becomes `{enable, #catalog}`: the imported catalog is embedded WHOLE, and every other field is derived from it: `version: #catalog.metadata.version` (a readout of the release-stamped identity, never a choice) and `#transformers: #TransformerMap & #catalog.#transformers`. The registry's pattern constraint binds the map key to the embedded catalog, `#registry: [Path=#ModulePathType]: #CatalogEntry & {#catalog: metadata: modulePath: Path}`, so a key and its import cannot drift. The `version!` scalar is removed as an *authored* field; the operator MAY stamp an expected `version` at platform-generation time, which unifies with the derived readout and turns wrong-bytes into a build conflict naming the entry (the tripwire D13 records as defense in depth). The catalog build is named the way every other CUE dependency is named: by the platform module's own `cue.mod`. Per-transformer selection is deliberately not expressible here.

**Revised:** 2026-08-20 — the entry originally embedded only the transformer map (`{enable, #transformers}`); revised during the OQ6 walk to embed the catalog whole and derive the map and version from it.

**Alternatives considered:**

- **Embed only the transformer map (`{enable, #transformers}`), previously adopted (2026-08-19).** Superseded in place: it made the platform author (or the operator's generator) write the derivation by hand, and it discarded the catalog's stamped identity, which is exactly the data D7's skew diagnostics and the Platform CR status need. Embedding the catalog whole costs nothing (experiment 07 measured unevaluated definition payloads as free) and makes `version` and the key binding computable instead of authorable.
- **Keep `version!` beside the import as an authored field.** Rejected: two answers to one question, with no way for a reader or the kernel to tell which is load-bearing. Experiment 02 measured that the import is the one that decides. The derived `version` is different in kind: computed off the imported bytes it cannot disagree with them, and the optional generation-time stamp is an assertion unified against that readout, never a second answer.
- **Embed a selected subset of transformers.** Rejected by the author as granularity the design does not need yet, and as a second selection mechanism competing with enhancement 0015, whose provider classes and `TransformerRegistration` own that concern.
- **Leave `#composedTransformers` a kernel-filled slot.** Rejected: with the transformers present in the registry it is a fold over enabled entries, so `library/opm/materialize/index.go` becomes four lines of CUE.

**Rationale:** This is what makes the platform a participant in dependency resolution rather than a bystander to it. A `version` string is inert data that nothing resolves; an import is resolved by the same mechanism that resolves everything else, which is what lets a single build have an answer at all. Enhancement 0010 D14's property survives the change: catalog selection stays a pure function of committed source, because `cue.mod` is committed source. What changes is the sentence, from "the platform file is the resolution" to "the platform module is the resolution". The revision adds no second answer: `#Catalog.metadata.version!` is required, stamped only by the release pipeline (enhancement 0011; no dev default, so an unstamped catalog refuses as incomplete rather than rendering while wrong), and the `Path` binding makes key-versus-import drift a conflict rather than a silent mismatch.

**Source:** User decision 2026-08-19: "If we move to embedd the transformers, we embed the whole list of transformers, not just a subset. That is to much granularity that we don't need at the moment. Remember the point of 0015" and "I would like the experiment to redefine the schema and embed the catalog.#transformers directly in the registry entry instead." Shape exercised by `experiments/02-platform-authority-mvs/platform/schema.cue`, which also records that the proposal is inexpressible as an extension of core's `#Subscription` (closed around `enable` + `version!`), so it is a core schema change rather than an authoring convention. Revision: user proposal 2026-08-20 — "This simplifies what needs to be written in platform.cue" — entry shape `{enable, #catalog}` with `version: #catalog.metadata.version` and `#transformers: c.#TransformerMap & #catalog.#transformers`.

### D6: The Platform CR keeps naming a catalog coordinate; the operator generates the platform package

**Resolves:** OQ11

**Decision:** `PlatformSpec` continues to carry typed Kubernetes fields naming the catalog artifact and version, and the operator encodes those into a `#Platform` CUE package on the backend. Publishing a `#Platform` to a registry is not allowed: the generated package is build-local by construction, and the reserved `opmodel.dev/platforms/…` namespace stays reserved-unpublished.

**Revised:** 2026-08-20 — publishing was originally permitted but not pursued; reversed at the OQ walk (OQ11), which found the permission bought nothing and left a half-supported artifact class standing.

**Alternatives considered:**

- **Permit publishing without pursuing it, previously adopted (2026-08-19).** Reversed: a published module cannot carry a build-local override (`mod/modfile/schema.cue`'s `#Strict` refuses `replaceWith`), so a published platform would express intent without enforcement outside the kernel's own promotion path (D13), and what publishing would even mean was an open question (OQ11) nobody needed answered. Disallowing it deletes the question.
- **Make the CR a reference to a published platform module** (path plus version, under the reserved `opmodel.dev/platforms/…` namespace). Not taken: the author sees no benefit beyond shareability, and it would make every platform edit a publish.
- **Put CUE text in the CR.** Rejected implicitly by D5: a platform with imports needs a `cue.mod`, which a text field cannot carry.

**Rationale:** D5 moves resolution into a `cue.mod`, which the CR cannot express. Generating the package on the backend keeps the operator's API surface typed and validated while giving the build a real module. It also keeps the generation step, which is where a runtime-discovered transformer set has to be folded in anyway (enhancement 0015 D3's `TransformerRegistration`).

**Source:** User decision 2026-08-19: "The Platform CR may still reference the catalog artifact and version, but the operator still encodes that as a #Platform CUE definition in the backend. Should work fine." and "I will allow #Platform to be published but i don't see the benefit of doing it, except sharing is caring." Revision: user decision 2026-08-20: "To simplify all our lives, we will not allow publishing of #Platform as CUE modules. I am taking back my earlier decision." Current shape: `opm-operator/api/v1alpha1/platform_types.go` `Registry map[string]Subscription`.


### D7: Catalog version skew between a module and its platform is detected by the kernel, and the response is caller-configured

**Resolves:** OQ7 (with D18)

**Decision:** When a `#Module`'s declared catalog requirement is **newer** than the build the `#Platform` imports, the kernel detects it and the caller chooses what happens. Two responses are supported: **warn and render anyway**, or **refuse to render**. The choice is kernel configuration, supplied per compile, so `cli` and `opm-operator` can each expose it on their own surface (a flag, a Platform CR field, a controller option) without either of them reimplementing the comparison.

Three things are fixed rather than configurable:

- **The kernel never decides on its own to emit output.** `library/CONSTITUTION.md` forbids the library logging to stdout or stderr, so "warn" means a structured diagnostic returned to the caller, in the shape `compile` already uses for its `warnings` channel. Rendering it is the caller's job.
- **A module requiring an OLDER build is not skew under this decision.** That is the ordinary forward-compatible case and the platform's choice simply stands. It may deserve its own lower-severity signal; that is left to OQ7's residue rather than folded in here.
- **The render module omitting a path is not skew, it is a kernel defect** (OQ6). It is caught by an internal invariant, not by this policy, because no caller should be able to configure it away.

**Alternatives considered:**

- **Always refuse.** Rejected: it makes a platform upgrade a flag day for every module pinned ahead of it, and the measured behaviour shows the render frequently succeeds anyway.
- **Always warn.** Rejected: on a multi-tenant operator a silently downgraded module is exactly the case an administrator wants to stop at admission, and D5 makes the platform authoritative precisely so that intent is enforceable.
- **Compare inside CUE and let the build fail.** Rejected as the sole mechanism: experiment 01's `_versionsAgree` shows the unification is expressible, but a CUE failure cannot be downgraded to a warning by a caller, so it can implement one of the two responses and not the other.
- **Leave it to `cue mod tidy` at authoring time.** Rejected: the skew is between two independently versioned artifacts that meet only at render, and neither author has the other's file.

**Rationale:** Experiment 02 measured that CUE reports nothing here in either direction. Under `pinned` the module's higher requirement is silently downgraded to the platform's build; under `unpinned` the module's requirement silently escalates the platform onto bytes it did not name. `cue vet -c` exits 0 in both. So the fact "this module was authored against a build this platform does not run" exists only if OPM computes it. Making the *response* configurable rather than the *detection* keeps one implementation of the comparison in the kernel while letting an interactive CLI and an admission-time controller take opposite, equally defensible positions.

**Source:** User decision 2026-08-19: "I want to decide that if the #Module is using a newer version of a catalog than the #Platform imports, it should either warn and try anyway or error. This should be configurable in the kernel so that the operator and CLI can both implement configuration options for this." Measured by `experiments/02-platform-authority-mvs/`, whose matrix shows the skew is silent in both directions.


### D8: ADR-002 is superseded, not amended; nothing built is shared between renders

**Resolves:** OQ12, OQ13

**Decision:** `library/adr/002-concurrent-render-shared-materialized-platform.md` is superseded by this enhancement. Its model, "per-goroutine Kernels, one shared read-only `*MaterializedPlatform`, no mutex", is replaced by a rule with no shared built value in it: **each render is its own CUE build in its own `cue.Context`, and that context does not outlive the render.** Concurrency is across renders, never within one.

The supersession lands as a `library` slice: ADR-002 gains a superseded-by header, a new ADR states the shares-nothing rule together with the `cue.Context` lifetime rule (OQ12), and `opm-operator/internal/platform/store.go`'s single held slot loses its reason to exist.

**Alternatives considered:**

- **Amend ADR-002 to put a mutex around the shared platform.** Rejected on measurement. `experiments/08-concurrent-render-at-scale/` runs exactly that shape: it costs 2.5x to 5.5x the throughput of a shares-nothing worker across 2 to 129 components, and it still retains 348 MB per render because it holds one `cue.Context` for the life of the process. A correction that is five times slower and keeps the other defect is a stopgap, not an architecture.
- **Amend ADR-002 to give each worker a private copy of the materialized platform.** Rejected without a dedicated experiment, on two grounds that do not need one. Its safety rests on the copy being genuinely independent, which is the same assumption ADR-002 already made and lost. And it is the per-worker-retained-context shape at a different granularity, which experiment 08 measures at 41.9 MB per render on a 2-component module rising to 581.8 MB at 129, reaching 23.4 GB resident through 32 renders.
- **Leave ADR-002 standing and let the collapse quietly not use it.** Rejected. `store.go` is built around it, so an ADR describing a model nothing runs is worse than no ADR: the next person to touch the render path would implement it again.

**Rationale:** ADR-002 drew its own caveat correctly and then set it aside. It recorded that "the verified guarantee is reads-only", and filling a shared value is a write to that value's evaluation state rather than a read, which is precisely the failure `experiments/06-concurrent-render/` reproduced at 2321 reports (1540 after pre-evaluating the shared value, so laziness is not the cause). What makes this a supersession rather than a bug fix is that the trade the ADR was making no longer exists. It traded a safety assumption for speed; experiments 07 and 08 show the shared model is also the *slower* one, at every module size, once holding the platform forces the serialisation its races require. There is nothing left on its side of the ledger.

**Consequences:** an operator sizes a render pool by memory rather than by core count, because a render is single-threaded and the binding constraint is the working set (see `06-operational.md`). D8 also closes the shape most likely to be proposed as a replacement: building the instance once and then executing the matched pairs in parallel. Measured on experiment 08's harness, forcing `rendered` concrete after `BuildInstance` returns costs 3.0 ms of an 1831 ms render, so the pairs are already evaluated and there is no parallel phase to schedule; and rendering one component of a 129-component instance still costs 46% to 76% of rendering all of them depending on module shape and authoring style, which is an Amdahl bound capping any split of the pairs across parallel builds at 1.31x to 2.16x for K times the working set. The transformer step itself is 1.3 to 2.4 ms per rendered object and is the smaller half of a render; building the components is the larger one, and it is identical work whether or not the pairs are split. Rendering different instances concurrently gets 4.0x to 4.3x for 1x the memory each, so the parallelism worth having is the one D8 already permits. The materialize-once machinery in `opm/materialize` shrinks or goes, which D5 already gated. Nothing in the render path holds a value across a reconcile, so the store's cache-invalidation question disappears rather than being answered.

**Source:** User decision 2026-08-19: "I want to superseed ADR-002. Please incude that in the scope of this enhancement." Measured by `experiments/06-concurrent-render/` (the races), `experiments/07-module-scale-cost/` (the cost model), and `experiments/08-concurrent-render-at-scale/` (the serialised yardstick and the retention figures).


### D9: The render step is one CUE build per render

**Resolves:** OQ1, OQ2, OQ3, OQ8

**Decision:** The kernel stages the synthesized `#ModuleInstance` and the generated platform package into a single generated render module (its `cue.mod` written by the kernel, its unpublished inputs entering through `cue.mod/local-module.cue` directory replacements) and evaluates it once, reading `rendered` and `diagnostics` off the built value. Nothing crosses a build boundary, so nothing is stripped and no value is filled into an independently-built closed value; combined with D8, no built value is shared between renders. Parity (D1) stops being a property the kernel maintains and becomes one it cannot violate. This ratifies OQ1, OQ2, OQ3 and OQ8: ADR-003's federation premise is stale (0010 D14 made multi-version-per-major composition inexpressible, and the only Go code assuming breadth is a self-described defensive path), the instance already participates in a build on disk via `synth`'s in-tree staging plus the directory-replacement mechanism experiment 02 exercised, minimum version selection does not run at load time so a committed `cue.mod` is a resolution rather than a floor, and reuse is an optimisation for sub-dozen-component modules worth at most ~85 ms rather than a precondition. What the generated render module owes its own `cue.mod` (the omission trap, the complete tidied dependency set, the refuse-to-render condition) remains OQ6, the one open design question inside this decision.

**Alternatives considered:**

- **Keep federation and land only the Phase A parity fixes.** Rejected: it keeps the two-value split's cause in place, keeps the shared-platform model that races under concurrent render and retains 348 MB per render, and leaves parity as a discipline the harness polices rather than a structural property. The strip would stay deleted but the next Go-side transformation would have the same boundary to justify it.
- **Batch many instances into one build.** Rejected: it reintroduces cross-instance resolution coupling (one module's pin would decide another module's transformer bytes), which is the authority failure experiment 02 exists to prevent.
- **Seal the platform into catalog-independent CUE and keep separate builds.** Refuted by experiment 03: `cue def --inline-imports` emits source that does not re-parse, is not self-contained, and carries dangling references.

**Rationale:** Every feasibility and affordability question this collapse raised has a concluded experiment behind it: expressibility end to end (01), platform authority under MVS with the failure mode reframed as omission (02), sealing refuted (03), per-render cost bounded and fixed-term (04, 07), concurrency ~4x on eight cores independent of module size with the shared model racing (06, 08), and matching's move measured separately (05, ratified as D10). The collapse is also the smaller kernel: the deletion candidates in `02-design.md` all follow from this decision, which is the direction D1 points.

**Source:** User decision 2026-08-19 (rescoping: both phases kept in this entry, the collapse stated as its own decision rather than implied by D5-D8). Evidence: `experiments/01-purecue-render-flow/` through `experiments/08-concurrent-render-at-scale/`, all concluded 2026-08-19.

### D10: Matching moves into the render build; verdicts are data; the D30 carve-out is deleted

**Decision:** Inside the render build, matching is expressed in CUE per experiment 05's measured glue shape: the reverse-index buckets (required ∪ optional), the always-unify rung and the predicate rung are comprehensions whose verdicts (pairs, missing FQNs, unify disqualifications with their conflicting FQNs, unresolved demands, warnings) are **data fields** a caller reads, with bottoms confined behind `== _|_` guards. The fail-closed gate (0010 D28) is one unification (`resolved & true`) inside the build, and the kernel reads the `diagnostics` value via `LookupPath`, which stays fully readable and concrete beside the failing gate. The always-unify rung runs as plain `&`: in one build both embedded copies resolve to the same catalog bytes, so the D30 provenance carve-out (`excludeProvenance` and its denylist) is **deleted rather than ported**, and the parity harness's one stated exemption is deleted with it. Matching *semantics* are unchanged. The gate for this slice is reproducing the kernel's exact pair set against a vendored kernel record.

Two measured boundaries are part of the decision rather than surprises for the implementer. An unhandled trait with an **unstated** optional posture refuses as an incomplete-value error naming `core/trait.cue`'s own `optional` field. Fail-closed survives, but as a build error rather than a diagnostics row, because posture-statedness is default-detection, which CUE only exposes through evaluation; making that case data needs a publish-side gate enforcing 0010 D46's stated-posture rule, which belongs to the publish-gate family (0011), not here. And an **incomplete** (non-error) pair output is invisible to `== _|_` (it lands non-concrete in `rendered` where the per-pair concreteness validation the kernel already owns catches it at a path naming the pair key), so failure isolation as data covers error-class failures, and incompleteness stays a per-pair-attributable build refusal.

**Alternatives considered:**

- **Keep matching in Go, reading the single build's value.** Viable, and it remains the fallback if the moved matcher's error quality regresses unacceptably during the slice: the verbatim CUE cause `oerrors.UnifyError` carries today is not recoverable from inside the build without a second diagnostic evaluation. Not chosen because the glue reproduces the exact pair set in ~230 lines, the verdicts-as-data shape is what D28's refusal and the diagnostics contract need anyway, and D1's direction is removal. `match.go`'s label predicate also silently narrows a type `core` widens (`cue.Value.String()` skipping non-strings), which plain unification covers.
- **Port the D30 carve-out into the CUE rung.** Impossible as stated (CUE cannot express "unify but ignore conflicts at these paths") and unnecessary: experiment 05 asserts the denylisted fields are equal in one build, and pins the negative case: a genuinely conflicting required copy is still disqualified through plain `&`, reported with its conflicting FQN.
- **Report failures as bottom and let the build fail.** Rejected: one failing pair would poison sibling verdicts, and a caller could not distinguish refusal from breakage. Experiment 05's healthy-plus-sabotaged fixtures measure the data shape isolating error-class failures while five healthy pairs render beside them.

**Rationale:** This was the collapse's least-evidenced region until experiment 05 ran: the design's "What matching costs" section held four undecided items, and all four now have measured answers recorded in place there. One finding constrains the glue beyond matching: the catalog's D25 provenance stamp refuses a foreign transformer unified into its member map, so multi-catalog composition is a map fold, never a unification into one catalog's member map.

**Source:** User approval of the rescoping 2026-08-19. Evidence: `experiments/05-match-in-one-build/`, concluded 2026-08-19 (18/18 verdict rows, kernel pair set vendored from the real kernel via its `capture/` recorder).

### D11: Sibling access through `#moduleInstance` stays reachable and is discouraged by contract, never narrowed structurally

**Resolves:** OQ4

**Decision:** OQ4's `siblingAccess` resolves to `discouraged`. The kernel fills `#moduleInstance` whole, sibling components included, and no kernel or schema mechanism prevents a transformer from reading them. D2's one-component invariant is stated as an authoring contract instead: a transformer that reads sibling components forfeits per-pair attributability of its errors and any future per-pair reordering or caching, and `catalogs/opm`'s own transformers must not do it.

**Alternatives considered:**

- **`prevented`: strip or mask `components` from the filled instance.** Rejected: it is a new strip in the entry whose thesis is deleting the strip. D1 names narrowing the handed-over value a divergence to be closed by removal, and D3 already rejected the metadata-only wrapper as "a divergence from CUE in its own right".
- **`reachable`: leave the state D3 produces undecided.** Rejected: exactly the "convention nobody wrote down" that D2's alternatives warned against when the slot is filled.

**Rationale:** Two locked decisions already forbid the structural option, so the real choice was between stating the convention and inheriting it silently. Within one render every pair already evaluates in a single build, and the timesplit follow-up on experiment 08 measured CUE evaluating one build single-threaded, so per-pair parallelism inside a render is not a live scheduling asset that prevention would protect. What per-pair independence still buys (attributable errors, reorderable and cacheable pairs) is preserved by convention for every transformer that honours it, with the catalog's own transformers setting the example (experiment 07 measured that none reads even a definition field off `#component`).

**Source:** User decision 2026-08-20; recommendation accepted as presented.

### D12: `#TransformerContext` becomes a projection of the other two inputs; the kernel fills `#runtimeName` alone

**Resolves:** OQ5

**Decision:** `core` computes every `#TransformerContext` field except `#runtimeName` as a projection of `#moduleInstance` and `#component`. The kernel's filling obligation narrows to the one runtime-owned string, and `opm/schema/context.go`'s hand-maintained decode/re-encode mirror is deleted. The change lands in this entry, as a `core` slice in Phase B beside `core-registry-import`, with the `SPEC.md` co-update under the `core-schema-edit` protocol. It is staged: the kernel keeps filling values identical to what the projection computes until the parity harness confirms agreement, after which the Go fills are removed and the harness's `equality` field collapses to `"structural"` permanently.

**Alternatives considered:**

- **Defer to its own enhancement.** Rejected: D9 locked the single-build collapse, so deferral would have the `library-render-build` slice hand-roll the derivation in generated glue CUE and a later entry move the same logic into `core`. That is churn in exactly the glue this entry creates. The evidence the deferral was waiting for already exists (experiment 01), and `affects` already grew to include `core` for the D5 registry reshape.
- **Keep the kernel as the sole filler and document the derivations.** Rejected: it preserves the hand-maintained mirror that can drift, and it moves computation in the direction opposite to D1.

**Rationale:** Experiment 01's `_contextFor` derives every field from the two inputs in 18 lines of CUE against the real published catalog, so the derivation is demonstrated rather than argued. The migration is safe to stage because for one release the kernel can fill values identical to what the projection computes and unification simply agrees. Under D9 the question stopped being independent: the glue would otherwise hand-roll in generated CUE what `core` could compute.

**Source:** User decision 2026-08-20: "projection, in this entry."

### D13: The render module's `cue.mod` is derived by promotion, never computed, and a render refuses when derivation cannot cover a path

**Resolves:** OQ6 (with D5), OQ10 (shared-path half)

**Decision:** The kernel writes the generated render module's dependency list by promotion from the two committed resolutions it already holds. The platform module's tidied dependency list is promoted WHOLE into the render module's roots; the staged instance module's list is unioned in for paths only the module carries; on every shared path the platform's entry wins, and the disagreement itself is D7's skew surface, reported through its diagnostics.

No tidy-equivalent runs at render time: tidying happens once, at platform-package generation (D6, cold path). After writing the file the kernel verifies that no OPM-namespace path would resolve from the module graph rather than from the roots, and refuses the render otherwise; an incomplete list is a kernel defect, never caller-configurable (D7).

D5's derived fields are the in-build defense in depth: the stamped-expected-versus-derived `version` unification and the key-to-`modulePath` binding turn wrong bytes into a build conflict naming the registry entry even if the promotion logic is ever defective.

**Alternatives considered:**

- **Run a tidy-equivalent at render time.** Rejected: tidy is what WRITES a resolution; the render build's job is to inherit one. A render-time tidy consults the registry on the hot path and re-derives what the platform already decided, against 0010 D14's principle that the committed platform module is the resolution.
- **Compute the list from the module graph.** Rejected for the same reason with worse mechanics: the graph's answer is maximum-version selection, which is precisely the resolver whose involvement this decision exists to prevent (experiment 02's one lost cell).
- **Rely on the D5 tripwires alone.** Rejected: they detect rather than prevent, refusal-by-conflict on every render is a worse steady state than a correctly written list, and the tripwires cover only stamped OPM artifacts while the promotion rule covers every path, `cue.dev/x/k8s.io`'s default-major trap included.

**Rationale:** Experiment 02 measured that authority fails by omission, never by override: `cue/load` answers a listed path from the main module's own list (`RootSelected`) and consults maximum-version selection only for unlisted paths, so a complete promoted list makes consumer pins inert on every path the platform names, including the catalog path consumer modules import for blueprints, which is how one build holds one catalog version for both authoring and execution and makes library#57's skew deterministic. The consumer's residue, paths only the module carries, cannot reach what executes: the transformer set is a fold over the platform's registry entries, whose bytes arrive through the platform's own imports. The carried finding that `local-module.cue` is the complete main-module dependency view rather than a patch is what makes promotion sufficient: nothing else supplements the list.

**Source:** User decision 2026-08-20: "I want to lock this down, and make sure to document the core schema changes", confirming the promotion rule with the platform always winning shared paths and the derived-entry tripwires as defense in depth. Evidence: `experiments/02-platform-authority-mvs/` (outcome 2026-08-19).

### D14: CUE's natural, unfinalized ordering is the render output contract

**Resolves:** OQ14

**Decision:** The byte ordering the collapse emits (CUE's natural evaluation order, with no finalization pass) is the contract. Today's ordering is explicitly an artifact of the strip, with no compatibility promise attached: `finalize.go` re-emits components through `Syntax(cue.Final())`, which hoists comprehension-produced fields ahead of plainly-declared ones, and the catalog's env map-to-list conversion carries that hoisting into rendered objects. The kernel does not re-sort output to preserve today's bytes. The migration note ships with the `library-finalize-removal` slice (Phase A, where the ordering change actually originates): one server-side-apply diff on the first reconcile after upgrade for modules that assemble environments conditionally, nothing after that.

**Alternatives considered:**

- **Preserve today's ordering by re-sorting the collapse's output.** Rejected: it adds kernel behaviour to emulate an artifact of the strip, which is D1's definition of the wrong direction, and the ordering it would preserve is one no module author chose.
- **Declare ordering unspecified.** Rejected: parity (D1) wants a byte-level oracle; an unspecified ordering forces the harness to compare modulo list order forever, weakening exactly the guarantee the entry exists to state.

**Rationale:** Experiment 07 compared every render byte for byte across both arms: 16 of 28 points identical, 12 identical modulo list order, nothing genuinely different. The 12 are exactly the fixtures whose container environment is assembled from several guarded sources. The cost of adopting the natural ordering is a one-time SSA diff per affected module; the cost of preserving the artifact is a permanent re-sorting pass in the kernel.

**Source:** User decision 2026-08-20: "CUE's natural, unfinalized ordering is the contract." Evidence: `experiments/07-module-scale-cost/` (outcome 2026-08-19).

### D15: Transformers read `#component.#names` for the primary object; they never derive its name

**Decision:** A transformer reads the name of the component's **primary object** (the workload or resource the component exists to render) from `#component.#names.resourceName`, and its DNS variants from `#component.#names.dns.*`, and never derives that name itself: no interpolation from `#context` fields, no read of `#component.metadata.resourceName` (the input to the cascade rather than the finalized projection), no hand-rolled formula. Name *generation* stays upstream on `#Component`; a transformer's relationship to primary identity is read-only. The rule is scoped, not absolute. Measured against the shipped catalog (50 transformers, not the 35 this entry previously counted), the sweep carries three carve-out classes:

- **Exact-name kinds** whose names are contracts with something outside the module render authored names verbatim: APIService (`<version>.<group>`), CRD (`<plural>.<group>`), webhook configurations (patched by name at runtime), Namespace, Role/RoleBinding and ServiceAccount names, `k8s_object`'s user-supplied segment.
- **Secondary and multi-object names** stay derived, with `#names.resourceName` as their prefix where one applies: per-item ConfigMap/Secret names (including hash-suffixed immutable forms), per-volume PVCs, policy-plus-binding pairs, the Service exact-name knob (`#ExposeSchema.name`), headless and governing service names.
- **Cross-object references** (HPA/PDB `scaleTargetRef`, route `backendRefs`, StatefulSet `serviceName`) follow the *referenced* object's naming rule, never an independent formula; these are the sites where drift fails silently rather than at `cue vet`.

The catalog's own exact-name mechanism is **deleted rather than reconciled**: `#ResourceNameTrait` (`traits/v1beta1/resource_name.cue`) and the `#WorkloadName` helper duplicate what core's `metadata.resourceName` override already expresses, and after D16 the core field is strictly better: the DNS variants follow the override, which the trait never provided. Trait fixtures (istio-cni-node, istiod, database) migrate to `metadata.resourceName`. Alpha stance: removed outright, no deprecation cycle. Like D11's sibling-access rule, the read-only contract is enforced by catalog review and the parity harness's fixtures, never structurally (CUE cannot forbid string interpolation). The sweep lands as `catalog-names-readonly`, gated on `library-component-fill` (what makes `#names` readable inside `#transform`) **and** `core-resourcename-default` (what makes the read byte-identical to the hand-rolled output), absorbing the catalog half of open-platform-model/catalog_opm#44 and open-platform-model/core#49. Its gate is byte-identity: no default-named golden fixture changes.

**Revised:** 2026-08-20. Originally an unscoped "never derive a name" gated only on the `#component` fill. Revised the same day after a source-verification sweep found 50 transformers rather than 35, eight exact-name kinds, multi-object emitters, cross-object couplings, and the catalog's own competing `#ResourceNameTrait` authority. The rule is scoped to the primary object, the trait is deleted, and the slice gains the D16 gate so the rewrite is output-neutral.

**Alternatives considered:**

- **Leave the sweep to the standalone issues, as the entry's out-of-scope list did until now.** Rejected: those issues predate Phase A and work around the strip by copying a computed value into a regular field, which, as `01-problem.md` notes, fixes one value and leaves the next projection to hit the same wall. Once `#names` is readable, the right fix is to read it, and the rule and its enforcement should land under the same entry that made reading possible.
- **Point transformers at `#component.metadata.resourceName`, which is equal in value today.** Rejected: `metadata.resourceName` is the author-facing input slot with the default cascade; `#names` is the finalized projection `core/SPEC.md` names the single source of truth, and the only place the DNS variants exist. If the derivation ever grows another step, `#names` is where the result is guaranteed final, and a transformer reading `metadata` directly is a second, silently diverging source: the many-formulas problem reintroduced at a different path.
- **Surface names through `#TransformerContext` instead.** Rejected as the primary read: under D12 the context is itself a projection of `#component` and `#moduleInstance`, so a context slot would be a third spelling of the same value; and plumbing named fields through context is exactly the per-projection tax D1 rejected.
- **Keep `#ResourceNameTrait` and map it onto `metadata.resourceName`.** Rejected: two authoring surfaces for one override is the two-answers-to-one-question shape D5 removed from the registry; the core field subsumes the trait's one use case (external name contracts) and carries the DNS variants with it.

**Rationale:** `01-problem.md` counts the cost of the missing rule, now corrected by measurement: all 50 transformers in `catalogs/opm` rebuild object names by hand in five distinct formula shapes (25 passthroughs interpolate from `#context`, 6 from `#component.metadata`, 7 route through `#WorkloadName`, 4 compose multi-segment names, 8 render authored names verbatim), and any two disagreeing silently breaks the cross-references between the objects they emit; the HPA/PDB target-name sites are the measured silent-failure case. Phase A's `#component` fill removes the only reason the formulas exist. Stating the read-only contract as a decision (rather than assuming the sweep implies it) is what stops formula six from being written after the sweep lands.

**Source:** User decision 2026-08-20: "the transformer should be reading from `#Component.#names.resourceName`; resource-name generation is done upstream, transformers only read; the sweep lands as a slice of this entry." Revision: user decision 2026-08-20 (scrutiny walk): carve-outs recorded, `#ResourceNameTrait` deleted under the alpha stance ("we should just yank it out and change stuff"), gating extended to the D16 flip.

### D16: `metadata.resourceName` defaults to the instance-qualified name, and the flip lands before the sweep

**Decision:** The `resourceName` cascade's default changes from the bare component name to the instance-qualified form, written as `*("\(#instance.name)-\(name)" & #NameType) | #NameType`. An explicit `resourceName` still wins, and the default is unified with `#NameType` so an overlong or invalid concatenation refuses the render rather than shipping an invalid DNS label, with one measured caveat the slice must close: on cue v0.17.1 that refusal surfaces as a bare `incomplete value` naming `#NameType`'s constraints, not the offending string (the failed default branch falls back to the bare non-concrete `#NameType` arm), so the slice adds a hidden assertion in the style of `_matchLabelsAreDerived` that names the overlong concatenation legibly. The change ripples by construction into `#names.dns.*`, so service DNS becomes `<instance>-<component>.<namespace>.svc.<clusterDomain>`.

It lands as `core-resourcename-default` with no dependency on any other slice, **before** the D15 sweep. The ordering is the point: rendered objects are *already* named `<instance>-<component>` by every hand-rolled catalog formula, while `#names` computes the bare name; that disagreement is exactly core#49. Flipping the default first makes the computed name agree with what fleets already render, so the flip is **output-neutral for rendered output** (nothing reads `#names` at render time yet), and the subsequent sweep becomes a byte-identical refactor provable against the catalog's golden fixtures. Renames are confined to three narrow cases, absorbed by the `modules-fleet-rename` slice: a component that sets `metadata.resourceName` explicitly today (silently ignored now, starts winning at sweep time), a component using the deleted `#ResourceNameTrait` (same rendered name, moved to the core field), and any module whose authored formula deviates from the convention. Alpha stance: the residual renames land without a deprecation cycle, recorded in the fleet slice.

**Revised:** 2026-08-20. Originally gated *on* the sweep ("flipping the default while transformers still hand-roll names would widen the computed-versus-rendered divergence") and framed as breaking-by-intent for rendered fleets. Both were backwards. The divergence is computed-bare versus rendered-qualified, so flipping first *closes* it; and the sweep-first order would have renamed every default-named object twice (to the bare name when the sweep landed against the old default, and back to the qualified name at the flip), a double fleet rename no document acknowledged. The flip now precedes the sweep, and the breaking claim shrinks to the three residual cases above.

**Alternatives considered:**

- **Keep the bare component name.** Rejected: within one instance the components map's keys already prevent collision, so the bare default's only real ambiguity is two instances of the same module in one namespace, and there it collides outright, both rendering a `web` Deployment that clobber each other.
- **Sweep first, flip second (the original 2026-08-20 order).** Rejected on the double rename: the sweep against the bare default strips the instance prefix from every default-named object in a rendered fleet, and the flip then restores it: two replace-not-update events where the inverted order has none.
- **A uuid fragment suffix.** Rejected: `#instance.uuid` is stable but unreadable, and the instance name already disambiguates while staying meaningful to a human reading `kubectl get`.
- **Include the namespace.** Rejected: the namespace is already the DNS scope and already appears in `dns.local`/`dns.fqdn`; folding it into the object name is pure redundancy.
- **The unvalidated spelling `*"\(#instance.name)-\(name)" | #NameType`.** Rejected, and measured: a chosen disjunction default is the bare interpolated string, never unified with the `#NameType` branch, so an over-63-rune concatenation ships silently invalid (verified on cue v0.17.1: a 69-rune interpolation exports clean). This is also the spelling open-platform-model/core#49 proposed; the validated form plus the hidden assertion supersedes it.

**Rationale:** The instance-qualified form matches the `<release>-<chart>` fullname convention every Helm operator already knows, fixes exactly the collision the bare default admits, and keeps the escape hatch (`resourceName` explicit) for authors who want exact names back, which is also what lets `#ResourceNameTrait` be deleted (D15). Being a default-only change, it is inert for any component that already sets `resourceName`, and, with the corrected ordering, inert for rendered fleets too.

**Source:** User decision 2026-08-20: "that default name sounds good — write it down", confirming the recommended form. Revision: user decision 2026-08-20 (scrutiny walk): flip-first ordering confirmed ("resourceName ... is always set and it represents the out resource name; the default name is `\(#instance.name)-\(name)`"); residual renames accepted under the alpha stance; `modules-fleet-rename` slice added.

### D17: `#Platform.#matchers` is removed, and the render build's glue owns the reverse index

**Decision:** `#matchers` leaves `#Platform` entirely. D5 removes the `Materialize` step that filled it, and D10 moves matching into the render build, where experiment 05's measured glue builds its own buckets from the composed transformer map. Core therefore ships no reverse index: `#composedTransformers` (derived, D5) is the only materialization-shaped field left on a platform, and a caller that wants "which transformers cover this contract" folds it in four lines. The removal lands in the `core-registry-import` slice beside D5's reshape, with the `SPEC.md` §3.4 co-update under the `core-schema-edit` protocol; `library/opm/errors/match.go`'s message text, which names the index, is reworded in `library-match-in-build`.

**Alternatives considered:**

- **Derive `#matchers` on `#Platform` from `#composedTransformers`.** The shape the delta carried first, and the one `experiments/02-platform-authority-mvs/platform/schema.cue` anticipated ("a real core change would also derive `#matchers` the same way"). Rejected on measurement: the glue does not consume it. `#Match` takes exactly two inputs, `#transformers` and `#components`, and builds `_bucketsResources` / `_bucketsTraits` internally, keyed contract FQN to a SET of transformer FQNs, where core's buckets are lists of transformer values. Deriving it in core would compute a second index, in a shape nothing reads, beside the one the render actually uses. That is the two-answers-to-one-question shape D5 removed from the registry, reintroduced one field lower.
- **Keep one index in core and have the glue read it,** reshaping `#matchers` to the set form the glue consumes. Rejected as a wider change than the evidence supports: the bucket value type is part of `SPEC.md` §3.4's stated shape, and it couples the render glue to a core field where experiment 05 deliberately kept it self-contained (its only inputs are the two values the kernel already stages). Available later as an additive optimisation if an inspection consumer ever appears.

**Rationale:** The slot exists because a Go step filled it. Both halves of that sentence are being deleted: `Materialize` by D5, and the Go matcher that read it by D10. Measured 2026-08-20, its only reader today is `library/opm/compile/match.go` (through the materialized twin); nothing in `opm-operator` or `cli` reads it at all. Keeping a derived version would be core reproducing a slot the kernel used to fill, which is the direction D1 names as wrong, and the cost of not having it is a fold any consumer can write against a field that is already derived.

**Source:** User decision 2026-08-20, on the residue recorded while authoring the core delta: recommendation ("drop the slot") accepted as presented. Evidence: `experiments/05-match-in-one-build/matchdef/match.cue` (the glue's inputs and its own bucket construction), and a 2026-08-20 sweep of `library`, `opm-operator` and `cli` for readers of `#matchers`.

### D18: Skew policy defaults to warn-and-render; the comparison reads the two committed resolutions; older-than-platform is data

**Resolves:** OQ7 (with D7)

**Decision:** Three fixings that complete D7's shape. **Default:** when a caller supplies no policy, the kernel warns and renders: the newer-module diagnostic returns on the warnings channel and the render proceeds. The policy stays configurable per compile between exactly two responses, warn-and-render and refuse; there is no third. **Source:** the comparison reads the module's requirement from the staged instance module's `cue.mod` and the platform's answer from the platform module's tidied dependency list, per OPM-namespace path. The render module's promoted list is never an input: promotion makes the platform win every shared path (D13), so reading the output would compare the platform against itself and skew would be structurally undetectable. **Older:** a module requiring an older build than the platform runs gets no warning; the resolved-versions comparison (what the module asked for, what the platform ran) is always present in compile diagnostics as plain data with no severity attached, so a caller can display which build executed without the ordinary forward-compatible case nagging.

**Alternatives considered:**

- **Default refuse.** Rejected by the author: the out-of-the-box behaviour favours rendering with a visible warning, and admission-time strictness is an explicit `refuse` on the operator's surface rather than a strict library default. D7 already rejected always-refuse for making a platform upgrade a flag day; making it the silent default would reintroduce that for every caller that forgot to configure.
- **No kernel default (required parameter).** Rejected: it pushes a mandatory decision onto every embedding, while the two callers that matter (`cli`, `opm-operator`) will set the policy explicitly on their own surfaces anyway. A library with a sensible default and an override is the friendlier contract.
- **Read the render module's promoted list.** Rejected by construction, as above.
- **An authored requirement field on `#Module` metadata.** Rejected: a second answer to a question the committed `cue.mod` already answers, the two-answers shape D5 removed from the registry.
- **A low-severity warning for older-than-platform.** Rejected: platforms routinely run ahead of module pins, so it would fire on nearly every render and train callers to ignore the warnings channel.

**Rationale:** The default follows the measured reality that the render frequently succeeds under skew (experiment 02) and keeps the library permissive while both real callers choose deliberately. The source choice keeps the comparison between two committed resolutions, which is 0010 D14's principle applied to detection: committed source in, diagnostics out. Older-as-data completes the account: newer-than-platform is a policy question, older-than-platform is provenance, and provenance belongs in diagnostics unconditionally.

**Source:** User decision 2026-08-20 (gate walk): "Warn and render as default. But I want it to be configurable. Configurable between warn or flat refuse"; comparison source and older-as-data accepted as recommended. Resolves OQ7's residue.

### D19: The D15 sweep extends to `catalogs/k8s`, with that catalog's exact-name carve-outs enumerated on their own evidence

**Amends:** D15

**Decision:** The read-only-names sweep covers `catalogs/k8s` alongside `catalogs/opm`. All 25 of its transformers hand-roll `{instance}-{component}` today and honour no override; after the sweep they read `#component.#names.resourceName` for the primary object under the same contract, gated the same way (byte-identical goldens against the default-named fixtures, output-neutral because D16's flip makes the computed name agree with what those formulas already render).

The exact-name carve-out class is **re-enumerated for this catalog rather than inherited**: its current members are `apiservice` (`<version>.<group>`), `crd` (`<plural>.<group>`) and `object`'s user-supplied segment, and the sweep adds **`CSIDriver`**. Its name is a contract with kubelet's `CSINodeInfo` registration and with every `StorageClass.provisioner`, dotted by convention (`zfs.csi.openebs.io`), and a mechanical rewrite to read `#names.resourceName` would break it exactly the way it would break APIService if APIService were not already listed. `StorageClass` is the contrasting case and stays in the sweep: its name is also an external contract (`storageClassName` on live PVCs), but it is label-shaped, so it wants the override honoured, not verbatim authoring. Two typed resources ride with the sweep because the catalog lacks the kinds: `#CSIDriverResource` (exact-name) and `#VolumeSnapshotClassResource` (override-honouring).

One further sweep rule, measured into existence: **no transformer may copy `resourceName` into a label value.** Label values cap at 63 runes while D20's override ceiling is a 253-rune subdomain. The shipped catalogs are safe today only by construction (`app.kubernetes.io/name` and the selector labels carry the component name, `#NameType` ≤63, never `resourceName`), and the sweep review is what turns that accident into a contract. This is a documented kubectl failure mode: `kubectl create deployment <253 chars>` fails on its derived `app: <name>` label, not on `metadata.name`.

**Alternatives considered:**

- **A standalone `catalogs/k8s` naming change outside this entry.** Rejected: this entry owns transformer naming (D15/D16), and a second mechanism landing beside the sweep would be a second answer to the same question, swept away when the entry lands.
- **Inherit `catalogs/opm`'s carve-out list.** Rejected: the classes transfer but the membership does not. `catalogs/k8s` carries kinds the opm catalog has no analogue for, and the sweep's failure mode (a silently renamed external contract) is exactly the one D15's carve-outs exist to prevent.
- **Leave `catalogs/k8s` out and let downstream users author raw manifests for exact-name kinds.** Rejected: sanctioned as a stopgap (the raw-manifest-beside-the-ModuleInstance precedent), but it splits ownership of a module's most load-bearing objects permanently.

**Rationale:** D15's scope line ("all 50 transformers in `catalogs/opm`") was a measurement of the catalog that existed when the decision was written, not a boundary of the principle. The principle (transformers read primary identity, never derive it, except where the name is an external contract) is catalog-independent, and the first downstream consumer to need `catalogs/k8s` (an `openebs_zfs` storage module, whose `CSIDriver` must render verbatim) hits the gap immediately.

**Source:** User decision 2026-08-24: "I still want you to gate on 0019 because I will make sure that both catalogs get the same treatment during the refactor"; CSIDriver carve-out and the two resources accepted as recommended. Empirical basis: the k8s name-rule matrix in `experiments/09-name-constraint-propagation/` (measured against a live v1.33.0 API server).

### D20: Three name types, the label stays the safety floor, the subdomain becomes the override ceiling, DNS-1035 closes the Service gap

**Amends:** D16

**Decision:** `core` splits naming into three types, each mirroring a rule the API server actually enforces. **`#NameType`** (RFC 1123 DNS label, ≤63, unchanged) remains the type of `#Component.metadata.name`, `#instance.name` and `namespace`: everything that composes into DNS or into the D16 default.

**`#ObjectNameType`** (NEW: RFC 1123 DNS subdomain, dot-separated label segments, ≤253) becomes `metadata.resourceName`'s ceiling: `resourceName: *("\(#instance.name)-\(name)" & #ObjectNameType) | #ObjectNameType`. An explicit override may therefore carry dots, because the kinds most components render (Deployment, DaemonSet, ConfigMap, Secret, StorageClass, CSIDriver, CRD, APIService) admit them; measured, not assumed.

**`#ServiceNameType`** (NEW: RFC 1035 label, leading character alphabetic) exists for the kinds that refuse what `#NameType` admits: `#NameType` accepts a leading digit, the API server rejects Service `1prod-web` at apply. The length boundaries are measured, not assumed: 253/254 bisected on ConfigMap and Deployment (the subdomain kinds), 63/64 on Service. No fourth, length-only type is needed, because the dot-restricted kinds carry the 63-rune budget *with* the dot ban (StatefulSet refuses 64 runes as "must be no more than 63 characters"): the label rule travels whole.

It also types `#ExposeSchema.name`, today a bare unvalidated `string`. The default's safety is structural, not policed: both halves of `<instance>-<name>` are labels, so the default can never carry a dot. Only an explicit override can meet a dot constraint, which is where D21 bites.

**Alternatives considered:**

- **Widen `#NameType` itself to admit dots.** Rejected: `#NameType` guards the `#names.dns.*` projection, where a dot does not make an unusual name but a *different FQDN*: `foo.bar` in the first label position resolves as two labels. The strictness is correct at that site; the error was applying the same type to a field most consumers never project into DNS.
- **Rewrite dots to hyphens in `#names` automatically.** Rejected by the author (2026-08-24): it creates two spellings of one component (`foo.bar` the Deployment, `foo-bar` the Service) at exactly the cross-object reference sites D15 names as silent-failure points; it is lossy (`a.b` and `a-b` collide in Service-space only); and it trades a loud vet error for a silent divergence, the inverse of the call D16 made when it chose the validated default branch.
- **One permissive type plus apply-time trust.** Rejected: the leading-digit case shows the API server catching at apply what vet should catch at authoring; a type system that is strictly looser than the server validates nothing the server does not already refuse later and worse.

**Rationale:** The three types are not an OPM taxonomy; they are transcriptions of the server's three validators (subdomain for most `metadata.name`, DNS-1035 for Service, label composition for the DNS-bearing kinds), verified by server-side dry-run: dots accepted on Deployment/DaemonSet/ConfigMap/StorageClass/CSIDriver at the 253-rune budget, refused on Service ("DNS-1035 label", 63) and on StatefulSet and Namespace ("must not contain dots", StatefulSet's cap bisected at 63). A name is dot-restricted iff it becomes a DNS label, the dot-restricted kinds carry the 63-rune budget with the ban, and the type system now says so.

**Source:** User decision 2026-08-24: "I like the idea of adding #ObjectNameType and #ServiceNameType… I want to allow developers to have dots in their #Component.metadata.resourceName overrides because it is allowed by k8s"; "#Component.metadata.name still needs constraining" confirmed — it is the safety floor. No-rewrite confirmed same day ("Ok no rewrite"). Validated by `experiments/09-name-constraint-propagation/` — outcome 2026-08-24.

### D21: Dot-hostile primitives declare a `#nameConstraint`; the component asserts the resolved name against their conjunction, the matchLabels pattern applied to naming

**Amends:** D16

**Decision:** `#Resource`, `#Trait` and `#Blueprint` gain a hidden slot `#nameConstraint: _`, a type the owning component's `resourceName` must additionally satisfy, defaulting to **top**. `#Component` collects every attached primitive's slot into one hidden conjunction, `_nameConstraints: _`, **unconditionally** (comprehensions over the three attachment maps, no existence guard), and asserts the **resolved** name against it on a hidden field: `_nameFits: "\(metadata.resourceName)" & _nameConstraints`. The conjunction is never unified into `metadata.resourceName` itself; the field keeps the spelling D16 landed (`*"\(#instance.name)-\(name)" | #ObjectNameType | error(...)`, the ceiling per D20), so its default arm stays unvalidated, `_resourceNameDefaultFits` keeps running, and the `error(...)` arm keeps naming an invalid override. Unifying top is the identity, so an indifferent primitive costs nothing; declaring a constraint narrows the assertion.

The three dot-hostile primitives declare theirs where the reason lives: `#ExposeTrait: #nameConstraint: #ServiceNameType` (the Service name is the first FQDN label), the stateful-workload blueprint `#NameType` (pod DNS `<sts>-<n>.<svc>…`; the server enforces the label rule on *both* axes there, refusing 64 runes as well as dots, so this single constraint captures length and dots at once), the Namespace resource `#NameType` (the second label of every FQDN). Core carries no per-kind knowledge and no precedence rule: two constraints compose by unification (Expose ∧ StatefulWorkload = DNS-1035, the intersection). Two spellings are load-bearing, not stylistic.

The top-default-no-guard slot: measured on cue v0.17.1, `t.#nameConstraint != _|_` is **false for a non-concrete value**, so the natural optional-slot-plus-guard spelling silently never propagates. The interpolation in the assertion: `"\(field)"` forces the disjunction default to a string, and `string & C` is either that string or an error naming it, the violated bound and the constraint type's definition site. A refusal therefore reads `invalid value "<name>" (out of bound <regex>)` or `(does not satisfy strings.MaxRunes(63))`; it does not name the attached primitive or a remedy, because an `error()` guard cannot be built on this field (below). The hidden field IS the legible assertion; no further D16-style assertion is owed.

**Revised:** 2026-08-26. Originally "the component unifies every attached primitive's slot **into** `metadata.resourceName`", validated by experiment 09 against `target.cue`'s validated-default spelling, and carrying a caveat that the landing would add D16-style hidden assertions for legible refusals. Experiment 11 re-ran the mechanism against the D16 spelling core actually landed (PR 51: unvalidated default arm, guarded length assertion, `error()` arm) and refuted the into-the-field spelling on legibility: a constraint unified into the field distributes into the default arm, a default that fails it drops out of the disjunction, the field is left a bare constraint, and the refusal surfaces as `non-concrete value … in operand to ==` at the D16 guard with the offending string nowhere; an override refusal is caught by the `error()` arm, whose text then mis-describes it ("is not a DNS subdomain" for a name a primitive refused). Nothing passed silently, so the safety claim stood. The hidden-assertion spelling above held across the full matrix (six refusals legible, three admissions, bare `#Component` clean). Two remedies were refuted on the way and are recorded so nobody re-tries them: a plain `_nameFits: metadata.resourceName & _nameConstraints` (no interpolation) **silently admits** every default-arm failure, the experiment-09 failure mode in a second form; and every `error()`-guarded form (`if (… & C) == _|_`) fires on the bare `#Component` definition, because `(incomplete & C) == _|_` is true when `#instance.name` is unresolved, while prefixing a concreteness term trades that for a circular-conditional error on the override path. Consequence for D16: `_resourceNameDefault` and `_resourceNameDefaultFits` are retired, because under D20's 253-rune ceiling a default built from two `#NameType` operands (at most 127 runes) can never overflow; the 64-to-127-rune case is refused, where it must be, by the rendering primitive's constraint through the assertion.

**Alternatives considered:**

- **Key the tightening off `matchLabels["core.opmodel.dev/workload-type"] == "stateful"` and friends.** Rejected: it hard-codes knowledge of specific primitives into `#Component`, needs a guard per key, and does not extend. The next dot-hostile kind means editing core rather than the primitive that introduced it.
- **`#nameConstraint?: string` with an existence guard.** Refuted by measurement (experiment 09, first run): the guard is false for non-concrete values, so propagation silently never fires. The failure mode is invisible in review.
- **Unify the conjunction into `metadata.resourceName` (the 2026-08-24 spelling).** Refuted by measurement (experiment 11) on the landed D16 field: default-arm refusals lose the offending string and override refusals are mis-described by D16's `error()` arm. See the revision note.
- **Constrain at the transformer instead of the component.** Rejected: the transformer sees the name after the module is authored. Refusal moves from `cue vet` at authoring time to render time, and D15 has just made transformers read-only consumers of names; giving them veto power over the value re-opens the many-formulas problem as a many-validators problem.
- **Enumerate dot-hostile kinds as a core-level list.** Rejected: same shape as the first alternative. The list is core's to maintain and every catalog addition is a core edit. The matchLabels precedent already answers this: the component contributes nothing of its own, every fact traces to a primitive.

**Rationale:** The mechanism is the third application of a pattern core already trusts twice (matchLabels derivation and the D16 validated default): facts live on the primitive that owns them, the component is a unification site for the constraints and an assertion site for the name, and CUE's lattice does the composition with no procedural code. It also completes D16's safety story: the qualified default is intrinsically dotless (both halves are labels), so the propagation machinery only ever fires on an explicit override. The default path is structurally incapable of producing a name any attached primitive refuses, and validation cost lands solely on deliberate overrides.

**Source:** User decision 2026-08-24: the propagation question posed as "how do we ensure we allow dots in all components metadata.resourceName override except for when we define a #StatefulWorkload or Service or Namespace"; primitive-declared constraints accepted as recommended. Validated by `experiments/09-name-constraint-propagation/` — outcome 2026-08-24 (hypothesis held after the guard-spelling refutation). Revision: `experiments/11-name-constraint-on-landed-d16/` — outcome 2026-08-26 (into-the-field spelling refuted, hidden interpolated assertion held); user decision 2026-08-26 ("Amend D21").

### D22: The Service name is one always-read field on the Expose trait, defaulting to the component's short DNS name

**Kind:** contract

**Amends:** D15, D20

**Decision:** The name of the Service a component renders is carried by exactly one field, the Expose trait's `name`, and the Service transformer reads that field and nothing else: no hand-rolled formula, no fallback. The field is **required** and typed DNS-1035 (`#ServiceNameType`, D20), so a dot or a leading digit refuses at authoring time. Its **default is the component's `#names.dns.short`**, which after D16 and D21 is the instance-qualified `resourceName` already guaranteed to be a valid Service name by Expose's own `#nameConstraint`; so by default the Service, the workload and the `#names.dns.*` projection agree by construction.

The default is supplied at the **component level** (the catalog's Expose component wrapper), the only site where the projection is in scope: the trait's spec schema has no path to the owning component (measured), and the wrapper reaches `#names` only by re-declaring it, because CUE resolves references lexically and unification with `#Component` does not bring the slot into scope (measured: `reference "#names" not found` without the re-declaration). That re-declaration rule is the same authoring obligation D11 records for `#transform` slots, now stated for component wrappers too.

An **explicit `name` renames the Service only**: the workload keeps `metadata.resourceName`, and `#names.dns.*` follows the workload, not the Service (measured: Service `istiod`, workload `istio-istiod`, projection `istio-istiod.istio-system.svc.cluster.local`). An author who wants the workload, the Service and the projection to share an exact name sets `metadata.resourceName` instead, which Expose's constraint admits when it is DNS-1035-shaped.

Attaching the Expose trait without the wrapper leaves the required field unset and refuses at vet (measured: `field is required but not present`), so a Service can never render unnamed. D15's carve-out bullet naming the Service exact-name knob as a derived secondary name is amended accordingly: the knob is the primary source of the Service name, defaulted from the projection rather than derived beside it. D20's typing of the field stands.

**Alternatives considered:**

- **Derive the field from `resourceName` outright (read-only, no override), exact Service names authored on `metadata.resourceName`.** Rejected by the author (2026-08-24): it forces the workload to carry the Service's exact name whenever the Service needs one, and removes the expose block as the place a reader expects the Service name to be written.
- **"Path C": the field acts as a constraint the trait feeds into `resourceName` through its `#nameConstraint`, so a Service override renames the workload too and the projection can never diverge.** Refuted by experiment 10 in both spellings: on the `#traits` entry the field is only ever the type, never the author's value (that lands on the component's `spec`), so the constraint degrades to `#ServiceNameType` and the override never reaches `resourceName`; feeding the component's value back onto the entry creates a cycle through the `spec` comprehension guard, which drops the field and refuses the author's own `spec.expose` as not allowed.
- **Keep the default inside the transformer (today's list-index at `service_transformer.cue:95-98`).** Rejected: it keeps the name a render-time fact that the component cannot see, so `#names.dns.*` and the rendered Service can only agree by coincidence, which is the divergence D15 exists to end.
- **Make the `dns` projection follow the Service instead of the workload.** Not rejected, not decided here: it requires the projection to derive from a primitive-declared network identity rather than from `resourceName`, the claim experiment 09 explicitly left open. Until it is measured, the divergence under an explicit `name` is a documented fact of the projection, and D22's `resourceName` spelling is the way to avoid it.

**Rationale:** One field, always read, gives the Service exactly the read-only-names contract D15 gives every primary object, with the exact-name case written where the Service is declared. Defaulting from the projection makes the common case correct by construction and the divergent case an explicit author act. The measured lexical rule is recorded because it is invisible in review: a wrapper that omits the re-declaration fails to compile, which is loud, but the reason is not obvious to someone who has never met the `#transform` version of the same rule.

**Source:** User decision 2026-08-24: "I still think expose.name should always be used, so the transformers always look at that for services, but the field is by default the #names.dns.short"; wrapper-hosted default confirmed same day ("it should work because it technically has access to the #names.dns.short field"). Validated by `experiments/10-service-name-source/` — outcome 2026-08-24 (held for the always-read field with a wrapper-hosted default; Path C refuted).

### D23: A primitive computes its `#nameConstraint` from its own state; the stateful constraint lives on the container resource

**Kind:** contract

**Amends:** D21

**Decision:** A primitive's `#nameConstraint` may be a **function of the primitive's own fields**, not only a constant type. The stateful label rule is declared on the **container resource**, keyed off the value of its own `workload-type` matching key: `#NameType` when the key reads `stateful`, top otherwise. The stateful-workload blueprint's declaration (D21) becomes redundant rather than the sole source. This closes a gap in D21 as first written: the StatefulSet transformer matches on the label, not on the blueprint, and a raw container component answers the key on its own `#resources` entry with no blueprint attached, so under D21 alone it rendered a StatefulSet with no name constraint and a dotted override reached the API server. The condition is readable because the key is answered **on the primitive**: core's `_matchLabelsAreDerived` refuses a component-authored key, so the value is concrete exactly where the component's comprehension reads it (measured: raw stateful default resolves `prod-cache` with the entry's constraint reading as `#NameType`; raw stateless with a dotted override keeps the dots; raw stateful with `cache.internal` refuses naming the DNS-1123 label regex). The list-index spelling is load-bearing: a default arm would win over the concrete one.

**Alternatives considered:**

- **Blueprint-only constraint (D21 as written).** Insufficient: it protects only components that attach the blueprint, while the transformer that renders the StatefulSet keys on the label.
- **Key the constraint off the component's derived `matchLabels` in core.** Already rejected by D21: it hard-codes primitive knowledge into `#Component` and every new dot-hostile kind becomes a core edit.
- **Constrain at the transformer.** Already rejected by D21: refusal moves from authoring time to render time, and D15 makes transformers read-only consumers of names.

**Rationale:** The matchLabels precedent D21 invokes says every fact traces to a primitive; a fact that depends on the primitive's own configuration still lives on the primitive, computed there. The label is the thing the StatefulSet transformer keys on, so the constraint must key on the same thing, and the only place both are visible together is the resource that declares the key.

**Source:** User decision 2026-08-24 (the resource-owned conditional spelling accepted: "I like this approach"). Validated by `experiments/09-name-constraint-propagation/` — extension outcome 2026-08-24 (held).

### D24: A computed `#nameConstraint` must resolve on every attachment path, because an unresolved slot silently disables the length validators for the whole component

**Kind:** contract

**Amends:** D23, D22

**Decision:** A primitive-computed `#nameConstraint` (D23) is a contract only where its input is concrete on **every** path the primitive can be attached through. D23's stated spelling, the conditional on the container resource reading the entry's own `workload-type` key, does not meet that bar and is withdrawn as the required spelling: when a workload blueprint answers the key, the container entry's key stays unanswered, the conditional stays unresolved, and core's conjunction then holds an unresolved term. Measured on cue v0.17.1 against core `v2.0.0-alpha.6`: with such a term present the regex bounds still fire against the resolved string but every `strings.MaxRunes` / `MinRunes` validator in the conjunction is deferred, so a 64-rune override on a stateful workload, and on the Expose Service attached beside it, is admitted at vet while a dotted one is refused. A presence guard does not rescue it (`key != _|_` is `false` on the unanswered key, but `false && <unresolved>` does not short-circuit). The catalog therefore computes the container's constraint from a value that is concrete wherever a key is answered, the component's derived matching identity, at its own component-level surface. The slot still lands on the container entry, and D23's principle stands: the fact is owned by the container, keyed on the same label the StatefulSet transformer keys on. Where a catalog exposes the container resource without that surface, the blueprint's constant constraint (D21) is the source. D22's "refuses at vet" for a raw Expose attachment is qualified: an unset required field is reported by concrete evaluation (`cue vet -c`, export, the kernel's render), not by a bare non-concrete `cue vet`.

**Alternatives considered:**

- **Keep D23's entry-level spelling and rely on the blueprint constant for the blueprint path.** Rejected by measurement: the unresolved slot is not merely inert on that path, it disables the blueprint's and Expose's own length validators. The dotted refusal in experiment 09 masked this; it was found only when the length bound was tested.
- **Guard the conditional on the key's presence.** Refuted by measurement (see Decision).
- **Have core skip unresolved slots in its collection.** Rejected: core cannot tell an unresolved conditional from a legitimate non-concrete constraint type, and D21 already records that presence guards on this slot are silently false.

**Rationale:** The length bound is the safety claim D20 and D21 make; a spelling that keeps the dot check and loses the length check passes every obvious test and fails at apply. The rule generalises beyond the container: any catalog author computing a slot must prove it resolves on every attachment path, testing a length violation and not only a dot.

**Source:** `catalog_opm` OpenSpec change `catalog-name-constraints`, design.md § Research & Decisions and `docs/name-constraints.md`, measured 2026-08-26; user decision 2026-08-26 ("Apply recommendation for the suggestions").

### D25: `#ResourceNameTrait` retires in three sweeps, and the deletion crosses a catalog major

**Kind:** scope

**Amends:** D15

**Decision:** D15's "removed outright, no deprecation cycle" is replaced by a staged retirement. Sweep 1 introduced the `#names` read in the seven workload transformers behind one ordering seam (`#WorkloadName`: the trait's exact name when set, else `#component.#names.resourceName`) and marked the trait, its component wrapper and its schema deprecated, shipping in `catalogs/opm` 2.0.0-alpha.7. Sweep 2 migrated the fleet's one user, `istio_ambient`, to `metadata.resourceName`. Sweep 3 deletes the trait, the wrapper, the schema and the seam, so the seven transformers read `#component.#names.resourceName` directly, and the exact-name fixtures attach `metadata.resourceName`. The alpha stance D15 relied on expired before sweep 3: `catalogs/opm` closed its alpha line at 2.0.0 (2026-08-29) and cut 3.0.0 (2026-08-30) for enhancement 0013's secret removal, and the publish compat gate (0011) refuses a member removal within a major, so sweep 3 lands as a `feat!:` cutting `opmodel.dev/catalogs/opm@v4`. The deletion is output-neutral: nothing in the workspace attaches the trait (measured 2026-08-30 across `modules`, `cli`, `opm-operator` and `library` fixtures), and no consumer has re-pinned to `@v3` yet, so the fleet moves from `@v2` to `@v4` in one re-pin.

**Alternatives considered:**

- **Remove outright in sweep 1, as D15 stated.** Rejected 2026-08-27: `istio_ambient` attached the trait and the fleet pins catalog releases, so a coexistence window let the fleet migration land as its own reviewed change instead of coupling a catalog release to a fleet edit.
- **Keep the deprecated trait indefinitely.** Rejected: two authoring surfaces for one override is the shape D15 removed, the seam that orders them is a permanent second authority in seven transformers, and the trait renames the workload only while `#names.dns.*` and the Expose default follow `metadata.resourceName`, a divergence D22 exists to end.
- **Hold the deletion until an unrelated `feat!:` needs a major crossing.** Rejected: none is scheduled, and the crossing's cost is one re-pin that no consumer has made yet.

**Rationale:** Staging changed no rendered byte and bought a reviewable fleet migration. The major crossing is the price of the catalog reaching GA between Phase A's sweep 1 and its last slice, the sequencing exposure `06-operational.md` names under Semver Impact; paying it now, while every consumer still pins `@v2`, is cheaper than paying it after the fleet has moved to `@v3`.

**Source:** User decision 2026-08-27 (staged retirement, recorded in `catalog_opm` change `catalog-names-readonly-workloads`); user decision 2026-08-30 (sweep 3 proceeds as its own change on a separate branch). Measured 2026-08-30: `opm-v3.0.0` published, zero `@v3` consumers, zero trait attachments outside the catalog's own fixtures.

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
