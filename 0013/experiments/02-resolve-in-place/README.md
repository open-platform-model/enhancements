# 02-resolve-in-place — Attribute-Declared Secret Fields

Status: Concluded

## Hypothesis

With `#Secret` narrowed to `#SecretLiteral | #SecretRef`, the kernel can **resolve every secret in place** — rewriting each declared secret's value to its `#SecretRef` form before the component graph is built — such that:

1. the **same published module** fulfils two ways (supplied in dev, referenced in prod) with no republish and no module edit;
2. **both arms converge**: after resolution the render cannot distinguish a resolved literal from a deployer-written reference;
3. **no** secret plaintext is present anywhere in the component graph;
4. the author's existing wiring (`from: #config.db.password`) carries the resolved ref with no author-side change, and a transformer needs **one branch and no name computation**;
5. a secret interpolated into a rendered string is rejected by **CUE itself, at authoring time**, before the kernel is involved.

These are the claims underneath **D10**, **D11**, and **D12**. Experiment 01 established that the routing mark is readable; this one establishes that the fulfilment half works and that the kernel can act on both.

## Setup

This is not a probe — it is a **working prototype of the proposed kernel pass**, so the design can be judged on running code.

- **`secret/secret.go`** implements the package `02-design.md` proposes for `library/opm/secret`, with the proposed API: `Discover(configSchema) []Decl`, `Resolve(decls, values, instance) *Resolution`, and `RewriteValues(ctx, values, res) cue.Value`. It mirrors `../../schemas/target.cue` type for type — `Decl`/`#SecretDecl`, `Marker`/`#SecretMarker`, `Secret`/`#Secret`, `Ref`/`#SecretRef`, `GroupPlan`/`#SecretGroupPlan`, `Resolution`/`#SecretsResolution` — including the error cases the schema implies: conflicting markers on one field, group members disagreeing on `type` or `immutable`, and one key claimed twice.
- **`main.go`** drives the five claims and prints each phase.
- **`module/`** is a module written against the real core schema, carrying five secrets across three groups (one derived-everything, one `basic-auth` pair, one immutable `tls` pair), plus **two value sets for the one module** — `valuesDev` supplies the TLS pair inline, `valuesProd` points it at a platform-managed wildcard certificate.
- **`module-leak/`** is a second module that interpolates a secret into a string. It is *expected not to compile*; claim 5 asserts exactly that.
- **`cue-deps/core/`** is a copy of `core/src` at `7500c5d`, copied not referenced. **`schemas.cue` in that copy is modified** to carry the shape this enhancement proposes — `#Secret` narrowed to the two arms, the `$`-field vocabulary and the whole discovery pipeline removed. That modification is the point of the experiment: core has not changed yet, and per the experiments protocol the copy is modified rather than the original. The file's header comment states the delta line by line.

One fixture detail matters. The instance is declared **without** `values`, and the two environments sit in sibling `valuesDev` / `valuesProd` fields. This mirrors production, where values reach the kernel from an instance file or a `ModuleInstance` CR rather than from the module's own package — and it is required, because CUE unification cannot *replace* a concrete value. `RewriteValues` therefore decodes to Go and re-encodes rather than filling. **Whether that is sufficient on the real kernel path is OQ2**, and it is the one step of this design still unmeasured.

## Run

```bash
go run .
```

Requires network access on first run to fetch `cuelang.org/go v0.17.1`. No registry access is needed — the CUE dep resolves to the local copy.

## Outcome

**Hypothesis held on all five claims.**

**Phase 1.** Discovery returned five declarations from the module alone, with derived keys (`db.password` → `db_password`), per-group types, and the `immutable` flag parsed off the bare attribute argument.

**Claim 1 — one module, two environments.** Identical module source, different plans:

```
[dev]  myapp-secrets           Opaque                        [db_password]
       myapp-basic-auth        kubernetes.io/basic-auth      [password username]
       myapp-tls-6bf0199259    kubernetes.io/tls  immutable  [tls.crt tls.key]

[prod] myapp-secrets           Opaque                        [db_password]
       myapp-basic-auth        kubernetes.io/basic-auth      [password username]
```

prod creates **no** TLS object, correctly — the deployer pointed at one the platform team owns. This is what OQ1 was really about, and it works because the choice lives in the field's type.

**Claim 2 — convergence.** After resolution every secret is a `#SecretRef` in both environments:

| path | dev | prod |
| --- | --- | --- |
| `db.password` | `myapp-secrets/db_password` | `myapp-secrets/db_password` |
| `tls.key` | `myapp-tls-6bf0199259/tls.key` | `wildcard-example-com/tls.key` |

`db.password` was written as a literal and became a ref; prod's `tls.key` was written as a ref and stayed one. Nothing downstream can tell them apart.

**Claim 3 — no plaintext.** Scanning the whole rendered `inst.components` subtree for each supplied plaintext found none. Worth being precise about why: this is not the kernel remembering to strip anything. `#SecretRef` is a closed struct with no `value` field, so after resolution plaintext is **structurally unrepresentable** in the graph.

**Claim 4 — one branch, one name.** The env entries hold `{ref, key}` structs, and a five-line transformer body turned both the resolved literal and the deployer-written ref into `secretKeyRef` from the *same* branch — no prefix test, no variant dispatch, no context lookup, no name computation. The volume-side and env-side references to the `basic-auth` group compared equal, because there is exactly one such string and it lives in the value.

**Claim 5 — CUE catches the leak, at author time.** `module-leak/` fails to build with:

```
theModule.rendered: invalid interpolation: cannot use {value:"hunter2"} (type struct)
as type (bool|string|bytes|number)
```

No kernel, no OPM tooling, no scanner. Under the superseded handle design (D4) this same module vetted clean and failed only at render.

**Cross-check worth noting.** The immutable object name `myapp-tls-6bf0199259` is produced here by the Go `ContentHash` and independently asserted in `../../schemas/examples.cue` by the CUE `#ContentHash`. The two implementations agree, which is the property the real kernel needs.

**What this experiment does NOT establish.** `RewriteValues` sidesteps unification by decoding to Go and re-encoding. Whether anything on the real `library/opm/kernel` path re-unifies the *original* values against the rewritten ones — and therefore hits `{value: …} & {ref: …, key: …}` = bottom — is **OQ2**, the sole blocker to acceptance.

Feeds: `03-decisions.md` D10, D11, D12, and OQ2; `02-design.md` (the pass and the `library/opm/secret` API sketch).
