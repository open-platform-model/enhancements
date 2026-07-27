# Problem Statement — Attribute-Declared Secret Fields

This document answers the question: "Why does this enhancement need to exist?" Every claim below names the file it comes from, at commits `core 7500c5d` and `catalog_opm db05149`.

## Current State

OPM models a sensitive field as a **contract type**: a struct the module author places on the field instead of the scalar the field actually is.

`#Secret` is a two-variant disjunction sharing a `$`-prefixed marker block. `#SecretLiteral` adds `value!: string` and means "the instance supplies the data, OPM creates the Kubernetes Secret"; `#SecretK8sRef` adds `secretName!` and `remoteKey!` and means "the object already exists, only wire a reference". Both carry `$opm: "secret"` as a discovery discriminator, plus `$secretName` and `$dataKey` as routing information the **author** writes into the schema declaration.

The definition exists twice, verbatim, in two separately published CUE modules:

| File | Lines | Package |
| --- | --- | --- |
| `core/src/schemas.cue` | 455 | `core` |
| `catalog_opm/src/resources/secret.cue` | 439 | `resources` |

The catalog does not import core's copy. It re-declares `#Secret`, `#SecretType`, both variants, `#SecretSchema`, `#ContentHash`, `#SecretContentHash`, `#ImmutableName`, `#SecretImmutableName`, `#GroupSecrets`, `#AutoSecrets`, and the whole of `#DiscoverSecrets`.

Discovery is `#AutoSecrets`, composed of `#DiscoverSecrets` and `#GroupSecrets`. `#DiscoverSecrets` is roughly 240 lines of hand-unrolled nested comprehension, one block per nesting level, ten levels deep. Detection is `v.$opm != _|_`; the recursion guard is `(v & {...}) != _|_`.

Consumption happens at two sites in `catalog_opm`. Environment variables go through `#ToK8sContainer` (`transformers/container_helpers.cue:52-89`), which reads `$secretName`/`$dataKey` off the value. Volumes go through `#ToK8sVolumes` (`:368-388`), which reads the `spec.secrets` struct instead. Materialisation is `#SecretTransformer` (`transformers/secret_transformer.cue`), which emits one Kubernetes Secret per entry in a component's `spec.secrets`.

Until recently `core` closed the loop by synthesising an `opm-secrets` component whenever a resolved config carried `#Secret` fields. Commit `7500c5d` deleted that, because the synthesis had to name a catalog primitive's FQN and a catalog stamps its own version into every FQN it publishes — a value core cannot know. `core/SPEC.md:521` records the reasoning; enhancement 0010's OQ9 is where the question was raised.

## Gap / Pain

**The routing is now written twice, by hand, with nothing checking that the two copies agree.** With the `opm-secrets` synthesis gone, a module carrying secrets must declare its own secrets component. So the author states `$secretName`/`$dataKey` once in `#config`, then restates the same mapping as a literal `spec.secrets` map in `components.cue`. The `$`-fields — the entire justification for the contract type — are now redundant with a hand-written map, and no validation compares them.

**Three independent derivations compute the same Kubernetes object name, and they disagree.**

| Site | Formula |
| --- | --- |
| `secret_transformer.cue:64-65` | `{instance}-{secretName}` **iff** the component is literally named `opm-secrets`, else `{instance}-{component}-{secretName}` |
| `container_helpers.cue:78` (env `from:`) | `{instance}-{$secretName}` — always the first branch |
| `container_helpers.cue:374-379` (volumes) | `{instance}-{component}-{secret.name}` |

The `opm-secrets` magic string is a leftover: nothing has produced a component with that name since `7500c5d`. So the env-var path resolves to a name the transformer never emits. This is live, not latent — it is masked today only because the one fleet module carrying a secret consumes it through a volume rather than an environment variable.

**The discovery pyramid is unused and cannot cover the shape it claims to.** No call site for `#AutoSecrets` exists anywhere in `core`, `catalog_opm`, `modules`, `library`, or `cli`. Both copies are dead. Were they live, they would still walk only structs — a `#Secret` inside a list is invisible — and silently drop anything past level ten.

**Variant dispatch is done three different ways.** `$opm` presence for discovery, `v & #SecretLiteral != _|_` for hashing (`secret.cue:121`), and structural sniffing `_entry.value != _|_ && _entry.secretName == _|_` for materialisation (`secret_transformer.cue:84-86`). A fourth name field compounds it: `#SecretK8sRef` carries both `secretName` and `$secretName`, meaning different things on one value.

**Core's copy is dead weight in a published contract.** Nothing in `core/src/*.cue` references any of it — only two comments in `module_instance.cue:59-65`. It still ships to every consumer of `opmodel.dev/core@v1`, and `core/SPEC.md:28` misdescribes `#Secret` as a Primitive "carrying its own `metadata`, its own versioned identity, and a `spec` schema" — it has none of the three, has no `§2.x` section, and is absent from `.tasks/spec-tracked.txt`.

**The security half was never built.** `cli/docs/rfc/0002-sensitive-data-model.md` (still Draft) set four goals: redaction, encryption at rest, external references, platform dispatch. One shipped. `value!: string` means plaintext sits in the instance values, in git, in the rendered component graph, and in the emitted `stringData` — problems 1 and 2 of the four the RFC was written to solve.

## Concrete Example

`modules/metallb` is the only module in the workspace fleet carrying a secret. It needs one gossip encryption key shared by every speaker pod.

`module.cue` declares the routing:

```cue
memberlistKey: res.#Secret & {
    $secretName: "memberlist"
    $dataKey:    "secretkey"
}
```

`components.cue:374-378` restates the identical routing as data:

```cue
secrets: memberlist: data: secretkey: #config.speaker.memberlistKey
```

The instance then supplies `speaker: memberlistKey: value: "…"`.

Three statements for one secret, two of which encode the same routing. The `$secretName: "memberlist"` and the map key `memberlist:` must match, and nothing enforces it: rename one and the render still succeeds, silently emitting an object under a name the wiring does not expect. Note that the instance's `value:` is *not* part of the problem — that is the deployer answering the one question only they can answer. What is redundant is the routing, stated once as `$`-fields on the value and again as a map the author writes by hand.

The object renders as `metallb-speaker-memberlist` (the component branch). Had metallb wired the key into an environment variable rather than a volume, `#ToK8sContainer` would have emitted `secretKeyRef.name: metallb-memberlist` — an object that does not exist. Both names are computed from the same author declaration, by two functions, in the same CUE module.

## User Stories

- As an **application module author**, I want to mark a config field as sensitive so that the toolchain handles the Kubernetes plumbing. Today: I state the routing as `$`-fields in `#config`, restate the same routing as a `spec.secrets` map in `components.cue`, and declare a secrets component to hold it — with nothing cross-checking the two copies.
- As a **platform team operator**, I want secret values kept out of rendered manifests and out of the `ModuleInstance` CR so that a `kubectl get` or a stored render does not disclose them. Today: `value: "…"` is a plain field in the instance values and flows verbatim into the component graph.
- As a **kernel contributor**, I want one authority for a Secret object's name so that references and materialisation cannot diverge. Today: three formulas in two files, one of which is unreachable and one of which is wrong.

## Why Existing Workarounds Fail

**Restating the routing by hand** is what the fleet does now. It costs a silent-failure mode — the two statements drift — and it scales linearly: every secret is a second edit in a second file.

**Reviving the `opm-secrets` synthesis in core** is the workaround `7500c5d` removed, and it cannot return in that form. Transformer matching is exact-FQN and a catalog stamps its own version into every FQN it publishes, so core would have to guess a version it cannot know. That is enhancement 0010's OQ9, and the reason it stayed open.

**Deepening the comprehension pyramid** past ten levels trades one arbitrary ceiling for a higher one at quadratic evaluation cost, and does nothing for the list blind spot — a CUE comprehension over a struct cannot descend into a list element without a separate arm per shape.

**Keeping the contract type and adding validation** to compare `$secretName` against the `spec.secrets` map key would close the drift, but leaves the field typed as a struct rather than the scalar it is, leaves plaintext in the render, leaves the duplication across two published modules, and adds a fourth thing to keep in sync rather than removing the second.
