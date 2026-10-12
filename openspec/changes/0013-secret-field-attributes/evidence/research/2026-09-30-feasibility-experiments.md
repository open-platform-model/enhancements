# Feasibility experiments, 2026-09-30

Six probes run to settle OQ3 to OQ8 after the secret-source redesign (D18 to D28). Each probe was run by one agent and re-run, and challenged, by a second. Versions: library `v1.0.0-alpha.36-1`, `opmodel.dev/core@v2` at `v2.0.0-alpha.13`, `opmodel.dev/catalogs/opm@v4` at `4.4.2`, `cuelang.org/go v0.17.1`, except where noted: the OQ5 probe ran on library `alpha.35` with core `alpha.12` (its verifier found the behaviour unchanged on `alpha.36`), and OQ8 used synthetic untagged and tagged cores beside the published `alpha.12`. The probes ran in a session scratch area and are not preserved in-tree; this note records what they measured. Measured facts are marked as such; everything else is a recommendation.

## OQ3: checking values against `#config`

- **Measured.** A hidden `_valuesCheck: #module.#config & values` inside `#ModuleInstance` leaves every exported field unchanged (full export identical under a sorted JSON diff). With it, plain `cue vet -c` rejects a value carrying both a literal and a reference, a bare string at a secret path, an unknown field and a wrongly typed value, whether or not a component reads them. The same holds on the authored-package path, the values-file path and the synthesis path.
- **Measured.** CUE never checks concreteness under a hidden or definition label: the validator counts any non-regular label as "in definition" and skips the concreteness check there. So an unfulfilled secret that no component reads still passes `cue vet -c`, with or without the hidden check.
- **Measured.** Binding `values: #module.#config` directly fills `#config` defaults into the exported values (which the CLI writes into the applied CR and hashes), and rejects even a valid instance when values arrive as a separate `values:` file, because fields declared beside an embedding are exempt from the arms' closedness and the disjunction never resolves.
- **Measured.** A hand-written instance package that does not embed `#ModuleInstance` carries no hidden check at all, and the kernel accepts it. A kernel check keyed on the hidden field would be silently skipped there.
- **Measured (verifier).** Every no-default field in 19 fleet modules is read by a component, so a completeness check over all required config fields would reject nothing in today's fleet. A field read only under a condition was not measured. D34 limits the kernel's check to declared secret paths.
- **Recommendation adopted (D34).** Keep the hidden check in core for early vet errors; have the kernel check the values against `#config` for concreteness on every entry path, independent of the hidden field.

## OQ4: platform settings for a source

- **Measured.** A source transformer declaring a closed settings definition, filled by the platform through its catalog entry's transformers, carries the filled value into every object that transformer renders, through the real render, with no change to core, the kernel or the render glue.
- **Measured.** A fill keyed by the transformer's version-bearing FQN is silently lost after a catalog version bump. A fill keyed by a reference to the catalog's exported transformer definition survives the bump, and a misspelled definition reference fails at render.
- **Measured.** Platform files embed `#Platform` at file root, which leaves fields written beside the embedding open: a misspelled setting is accepted and the default used. Wrapping the fill in the source's own settings schema refuses it. A defaulted setting can still be lost through a misspelled key; only a required setting guards against that.
- **Not measured.** The round trip of a settings fill through an operator or CLI carrier; none was built.
- **Measured.** The operator's Platform subscription carries only enable and version, and the CLI's platform generator emits only those; neither can carry a settings fill today. Core documents a catalog entry's transformers as derived readouts, never authored.
- **Measured.** Under a closed input envelope, a per-secret override can only live inside an entry, where the kernel cannot tell it apart from data.

## OQ5: typing a source's entries at render

- **Measured.** A synthesised component carrying a source's contract, resolved from the platform's defined contracts, has its entries typed by the source's own schema: wrong types, unknown fields and wrong spec keys are refused at the exact entry path. The resource's spec key derives in CUE from its definition name.
- **Measured.** A required entry field is caught only when a transformer reads it; a required field no transformer reads renders silently. Authored components are protected from this by the acquisition-time concreteness check, which synthesised components skip because they enter after acquisition. Validating each synthesised spec for concreteness catches every such case at the entry path.
- **Measured.** A literal source whose schema constrains the value (for example a minimum length) prints the deployer's plaintext in its conflict error, at the synthesised component's path.

## OQ6: a component key outside the author key space

- **Measured.** A synthesised component keyed `opm.secrets.db` renders; pairs, compiled output, diagnostics and object sets carry it, and no tool downstream of the render reads the key: inventories take the component from the rendered object's component-name label. A bare hidden identifier is dropped by comprehensions, so the key must be emitted quoted.
- **Measured.** The synthesised component carries no component-name label unless the kernel stamps it; without it an inventory records an empty component.
- **Measured.** An instance-package author can add component keys the module never declared. The render then refuses every pair through closedness, with a misleading message, rather than through an explicit check.

## OQ7: resolving a source name

- **Measured.** Resolving a short name through the annotation works in the render glue and in Go before staging, with the same verdicts. Two defects were found: a catalog carrying two apiVersions of one source resource, both annotated, makes the short name ambiguous for every deployer on the day the platform upgrades; and a provider-fulfilled source with no provider is silently dropped when the skip-unprovided switch is on, while every consumer already references its Secret.
- **Read from source.** OPM's apiVersion ladder (the render glue's version comparator) only orders the alternatives shown in diagnostics; it never selects a version. Apart from the literal-source lookup D30 keeps, nothing in this design resolves a name or picks a version implicitly.
- **Decision (D29).** Sources are named by exact FQN, as components name resources; the short-name lookup is dropped.

## OQ8: detecting a field typed `#Secret`

- **Measured.** A hidden tag inside each core arm, looked up under core's package after values are unified, detects every one of the 18 declaration forms tried (direct, optional, defaulted, nullable, embedded, `let`-aliased, definition-aliased, disjunction arms, patterns, lists, list-element declaration attributes, conditionals) when a value is supplied, and tells the earlier core release's `#Secret` apart. It shows no false positive against structural twins or a tag forged in another package.
- **Measured.** Two failures of a values-only rule: a declared secret whose plain-struct default is left unset resolves untagged and is not detected; and instance values written in CUE that import core's arms make untyped fields carry the tag and be discovered. D33 therefore lets the schema declare and checks the tag only at declared paths.
- **Measured.** Following references misses `let` aliases, and both core releases publish `#Secret` under the same name. Shape matching by subsumption flags unrelated structs and open values as secrets.
- **Measured.** Before values exist, a schema walk that decomposes disjunctions and follows references to the tagged arms detects 17 of the 18 forms; the miss is a field under a condition that has no value yet.
- **Measured.** A field that copies another secret field is discovered as a second secret path. Whether a copy gets its own entry is not decided.
