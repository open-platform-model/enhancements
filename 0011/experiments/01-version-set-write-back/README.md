# 01-version-set-write-back — Module and Catalog Publishing

Status: Running

Pins: D3's version writer, and the editing-mechanics question `02-design.md` leaves open ("a surgical AST rewrite preserves formatting and comments where a reformatting round-trip does not"). Also exercises D5's `@opm()` marker from the WRITE side, which is where its one real gap shows.

## Hypothesis

`opm catalog version set <semver>` can be implemented as a surgical AST edit that finds the version field **by its `@opm()` marker**, fills it when open and replaces it when concrete, is a no-op when the value already matches, and leaves a one-line diff that preserves the surrounding comments, the alignment, the attribute, and any type assertion the author wrote — where the obvious implementation (replace the whole value) does not.

## Setup

Self-contained; nothing outside this directory is read or modified. No registry, no network, no CUE module — every fixture is a single file, because what is under test is a text rewrite rather than an evaluation.

- **`fixtures/`** — six pristine identity files, never modified by a run:
  - `catalog_open.cue` — `Version: #VersionType @opm(identity, owner=publish)`, the open state.
  - `catalog_concrete.cue` — a concrete version, `cue fmt`-clean, with the two identity fields column-aligned.
  - `catalog_conjunction.cue` — `Version: #VersionType & "1.2.0"`, and **deliberately not `cue fmt`-clean**, to show what a whole-file reformat does to lines the edit did not touch.
  - `catalog_role.cue` — the **proposed** marker form `@opm(identity, role=version, …)`, on a field deliberately named `CatalogVersion` so it cannot be found by name.
  - `catalog_unmarked.cue` — a `Version` field with no marker.
  - `module_identity.cue` — a module's one-line identity (0010 D7), which carries no version at all.
- **`main.go`** — the writer. `versionSet()` locates the field, `replaceConcrete()` rebuilds the value expression, and a `--naive` flag switches to whole-value replacement so the two can be diffed rather than argued about. `go.mod` requires `cuelang.org/go v0.17.1`, matching `cli`.
- **`run.sh`** — copies fixtures into `work/`, runs eight cases, prints the diff each produced, and re-vets every rewritten file.

`work/` is scratch, recreated on every run.

## Run

```bash
bash run.sh
```

Requires `cue` v0.17.1 and Go 1.26 on PATH.

## Outcome

Observed 2026-07-26 with cue v0.17.1, Go 1.26.2.

| Case | Result |
| --- | --- |
| open → `1.2.0` | `#VersionType` → `#VersionType & "1.2.0"`; 1-line diff |
| concrete → `1.10.0-rc.1` | `"1.2.0"` → `"1.10.0-rc.1"`; 1-line diff, alignment recomputed |
| set the value it already has | no-op, **file not written**, empty diff |
| conjunction, surgical | `#VersionType & "1.2.0"` → `#VersionType & "1.3.0"`; assertion kept |
| conjunction, naive | `#VersionType & "1.2.0"` → `"1.3.0"`; **assertion silently deleted** |
| role-marked field named `CatalogVersion` | found by role; written |
| unmarked `Version` | refused — "OPM does not own this field" |
| module identity | refused — "nothing to write" |

Every rewritten file still parses and passes `cue vet -c`.

**Hypothesis held**, with one qualification and one design gap.

### The rewrite itself is unproblematic

`parser.ParseFile(..., parser.ParseComments)` → mutate one `ast.Field.Value` → `format.Node` preserves doc comments, inline comments, the `@opm()` attribute verbatim, and recomputes column alignment so a longer value does not smear across neighbouring lines:

```diff
-Version:    "1.2.0"                        @opm(identity, owner=publish)
+Version:    "1.10.0-rc.1"                  @opm(identity, owner=publish)
```

Idempotency is free and worth taking: comparing the formatted value expression against the target catches both `"1.2.0"` and `#VersionType & "1.2.0"`, and the file is then not written at all — so `version set` on an unchanged version produces no mtime change, no diff, and nothing for a pre-commit hook to react to.

### Qualification: format.Node formats the WHOLE file

The edit is surgical; the write is not. `format.Node` re-renders every line, so a file that is not already `cue fmt`-clean churns lines the edit never touched — visible in the conjunction case, where a stray double space turns a one-line diff into two. This is a precondition rather than a defect: `version set` should either refuse on an unformatted file or fmt it deliberately and say so. A byte-splicing writer that touched only the value's source range would avoid it, at the cost of hand-rolling what `format` already does correctly. Not worth it.

### Preserving the conjunction is not optional

The obvious implementation — `field.Value = ast.NewString(version)` — turns `Version: #VersionType & "1.2.0"` into `Version: "1.3.0"`, deleting a constraint the author wrote, in a file the tool claims to own, with no error and a diff that looks like a version bump. `replaceConcrete()` instead rebuilds the `&` chain keeping every operand that is not a string literal, so filling an open `#VersionType` yields `#VersionType & "1.2.0"` and the committed file goes on asserting SemVer after the tool has written to it. (A bare predeclared `string` is dropped rather than kept: `string & "1.2.0"` says nothing that `"1.2.0"` does not.)

This bears on **0010's choice of open form**. D6 writes the open field as `Version: string`; if it is `Version: #VersionType` instead, the writer must be conjunction-aware — which it should be anyway, since an author may write the typed-and-concrete form by hand.

### Design gap: the marker does not say WHAT it marks

`@opm(identity, owner=publish)` says a field is identity and that publish owns it. It does not say *which* identity field it is. So a writer looking for "the version" has nothing to match on and falls back to `name == "Version"` — reintroducing exactly the hardcoded name the marker was introduced to remove. In the run above, every case except the role-marked one reports `found by name-fallback`.

The fix is one attribute argument. `@opm(identity, role=version, owner=publish)` makes the field findable by what it *is*, and the run shows it working on a field named `CatalogVersion`, which no name-based lookup would have found. It also makes `owner=publish` meaningful as a separate axis — role says what, owner says who writes it.

Two smaller points fall out of the same place:

- **Refusing an unmarked field is the right default and needs to stay explicit.** `catalog_unmarked.cue` declares a `Version` with the right name and the right value shape; the writer refuses because the marker is the authority. A name-based writer would have written it.
- **`version set` for modules has nothing to do**, and the refusal says so by name (0010 D2 removes the module version entirely). That is 0011 OQ4's concrete shape: if the module form of the command is to exist, it needs a different job than writing a version.

### What to change in the enhancement

1. **D5's marker gains a `role` argument** — `@opm(identity, role=version|modulePath, owner=publish)`. Without it the marker is not sufficient for the write path, only for the read path. This is the load-bearing finding; it touches 0010 D5 as well as this entry.
2. **`02-design.md`'s "surgical AST rewrite" note is confirmed, with the whole-file-format caveat recorded** — the mechanics work; the precondition is a formatted tree.
3. **The writer must be conjunction-preserving**, and that requirement should be stated wherever the command is specified, because the naive implementation is the one someone will reach for.
