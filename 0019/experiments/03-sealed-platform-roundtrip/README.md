# Experiment 03: sealed-platform-roundtrip

Status: Concluded

## Hypothesis

An evaluated platform's transformer map can be **sealed**: emitted as self-contained CUE that no longer depends on the catalog module, that still carries the field classes a transformer needs (definitions, hidden fields, closedness), and that renders what the imported original renders.

Sealing is the alternative to re-evaluating the catalog on every render. Experiment 02 established that the kernel-generated render module's `cue.mod` already confers platform authority, so sealing is **not** needed for that. What it would buy is reuse: a platform materialized once per Platform generation and shared across many instance renders, which is the model `opm-operator/internal/platform/store.go` implements today and which a per-render single build otherwise dissolves.

The risk being tested is specific. Flattening an evaluated value back into source is the same class of round trip that `cue.Final()` gets wrong, and getting it wrong there is the defect this whole enhancement exists to remove.

## Setup

`platform/` is copied from `../02-platform-authority-mvs/`, unchanged. The platform is authored under the proposed schema: it imports `opmodel.dev/catalogs/opm@v2.0.0-alpha.3` and embeds `catalog.#transformers` directly into its `#registry` entry.

The sealing mechanism under test is `cue def --inline-imports`, which is CUE's own facility for expanding references to non-builtin imports into a single file.

`run.sh` runs five steps:

1. **Seal.** `cue def --inline-imports -e '#registry["…"].#transformers'` over the platform package.
2. **Self-containment.** Classify every import surviving in the emitted source as stdlib or not. A non-stdlib survivor means the seal did not seal.
3. **Load.** Put the emitted source in a module whose `cue.mod` deliberately omits the catalog, and vet it. A sealed platform that still needs the catalog on the module graph has not been sealed.
4. **Field classes.** Count `#transform` blocks, hidden fields, `close()` calls and definition fields in the emitted source.
5. **Semantics.** In a separate module that *keeps* the catalog dependency on purpose, reach the same transformer both ways and compare. Step 3 asks whether the seal is self-contained; step 5 asks the independent question of whether the round trip preserved meaning, and answering that needs both sides in one build.

`repair.py` is part of the measurement, not a convenience. It undoes two printer defects found in step 1's output so that the later steps can reach the substantive questions instead of stopping at a syntax error. What it had to repair is reported in the outcome.

**Deviation from the copy-never-reference rule**, on the same grounds as experiments 01 and 02: `core@v2.0.0-alpha.4` and `catalogs/opm@v2.0.0-alpha.3` resolve from the registry. Both are exact published versions and therefore immutable.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
./run.sh
```

Pinned to `cue v0.17.1`. Artifacts, including the emitted seal and every error file, are left under `_out/`.

## Outcome

**Hypothesis refuted.** `cue def --inline-imports` is not a viable sealing mechanism for this catalog today, and it fails in three independent ways.

### 1. The emitted source does not parse

```
   PARSES AS EMITTED: no
      expected '{', found '||':      ./sealed.cue:2307:13
      expected operand, found '||':  ./sealed.cue:2308:13
```

Two printer defects, both in how `cue def` renders source it has just read successfully:

- It appends a trailing `// explicit error (_|_ literal) in source` comment to a line ending in `_|_`. When that line is one arm of a multi-line boolean, the comment swallows the rest of the expression. 486 occurrences.
- It breaks a multi-line boolean **before** its operator, so a continuation line begins with `||` or `&&`. CUE terminates the expression at the newline and the continuation is a syntax error. 21 occurrences.

Neither is a CUE-language problem, and the input is a published catalog that vets clean. It means the output of `cue def --inline-imports` cannot currently be treated as CUE source without post-processing.

### 2. The seal is not self-contained

After repair, the file parses and then fails for the substantive reason:

```
   LOADS: no
      import failed: cannot find package "opmodel.dev/catalogs/opm/resources/v1beta1"
```

Two catalog packages survive the inlining:

```
      NON-STDLIB  opmodel.dev/catalogs/opm/schemas
      NON-STDLIB  opmodel.dev/catalogs/opm/resources/v1beta1
```

So the emitted value still requires the catalog module on the graph. The one property sealing exists to provide, a platform artifact that no longer depends on its catalog, is not delivered.

### 3. Inlining leaves dangling references

Step 5 cannot even measure semantic fidelity, because the inlined value refers to definitions the inliner did not emit:

```
      let[].#x.metadata.#definitionName: reference "#KebabToPascal" not found
      let[].#x.allOf:                    reference "#JSONSchemaProps" not found
```

`#KebabToPascal` is `core`'s; `#JSONSchemaProps` is the Kubernetes schema's. Whatever `--inline-imports` classifies as a "core import" and declines to expand, it nonetheless strips the qualification from, leaving a reference with nothing to resolve against. The result is not merely unsealed, it is broken.

### What did survive

Step 4 is the one encouraging reading, and it is about the emitted *source*, not about a value that evaluates:

```
   #transform blocks:       51
   hidden fields:           159
   close() calls:           0
   definition fields:       683
```

Definitions and hidden fields are emitted rather than dropped, which is the opposite of what `cue.Final()` does and was the specific fear going in. Zero `close()` calls is expected rather than alarming: closedness in this catalog comes from definitions being closed by default, not from explicit `close()`.

### What this redirects toward

Sealing by **flattening an evaluated value** is out on today's tooling. Sealing by **vendoring bytes** is not, and experiment 02 already demonstrated the mechanism: a platform artifact can carry the catalog's source tree and a `cue.mod/local-module.cue` directory replacement, which the loader honours (`cue/load/config.go:581-620`) and which serves the directory without consulting a registry (`modpkgload/replace.go:88-97`). That keeps the platform's build reproducible and catalog-independent at the *artifact* level without asking a printer to reproduce an evaluated value as source.

Whether that is worth doing at all now depends on the reuse question rather than the authority one, since experiment 02 settled authority. It is a performance and operational decision: what the render build costs per instance, and whether the operator's materialize-once model needs preserving.
