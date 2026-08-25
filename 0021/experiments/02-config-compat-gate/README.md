# 02-config-compat-gate — OPM Versioning Policy

Status: Concluded

## Hypothesis

The module compatibility gate (0021 OQ5/OQ6) needs no new comparison: the catalog gate's field walk (`library/opm/compat.Check`) applied to two releases' `#config` definitions, plus one reverse subsumption to separate additive from fix, classifies every row of D2's table; mapping the class through the stable bump table and comparing it with the SemVer distance the author claimed yields the refusal.

## Setup

- `compat/compat.go`, `compat/level.go`: byte copies of `library/opm/compat/` at cue v0.17.1 (level.go only because compat.go references `ParseLevel`). Package name unchanged; nothing edited.
- `fixtures/<version>/config.cue`: a predecessor `1.3.0` (`database.url!`, `replicas: int | *1`, `logLevel: "info" | "debug"`) and seven candidates, one per row of D2's table: comment-only fix, additive (new optional struct, widened enum), rename, added required field, tightened constraints, changed default, and the rename shipped as a major.
- `main.go`: loads each fixture with `cue/load`, looks up `#config`, classifies (`Check` findings → breaking; else `prev.Subsume(next)` failing → additive; else fix), derives the required level (breaking → major, additive → minor, fix → patch; on a `0.x` predecessor breaking → minor), computes the claimed level from the version strings, and prints GO or REFUSED with the walk's findings.

## Run

```bash
bash run.sh
```

## Outcome

```
predecessor 1.3.0 (0011 D23: newest published below the authored tag, same major)

candidate        class     required  claimed   verdict
1.3.1-fix        fix       patch     patch     GO
1.4.0-additive   additive  minor     minor     GO
1.4.0-rename     breaking  major     minor     REFUSED
    database: field removed
    db: field added without optional or default
1.4.0-required   breaking  major     minor     REFUSED
    region: field added without optional or default
1.4.0-tighten    breaking  major     minor     REFUSED
    replicas: domain narrowed
    logLevel: domain narrowed
1.4.0-default    breaking  major     minor     REFUSED
    replicas: default changed
    replicas: domain narrowed
2.0.0-rename     breaking  major     major     GO
    database: field removed
    db: field added without optional or default

pre-stable (0.x) branch of the same rename, predecessor 0.3.0:
0.4.0-rename     breaking  minor     minor     GO
```

Every row classifies as D2's table says, and the two verdict columns fall out of the stable table: the four breaking candidates claimed as `1.4.0` are refused with the offending path and finding kind, the same break claimed as `2.0.0` passes, the additive and fix candidates pass at minor and patch, and the `0.x` branch lets the break through at a minor.

Two findings for the open questions. **OQ3:** the copied walk already reports a default change as `default changed` *and* `domain narrowed` (`int | *1` vs `int | *3` do not subsume each other), so under the existing comparison a default change is breaking by construction, consistent with 0010 D27; deciding OQ3 as "additive" would mean filtering the walk's findings, not adding a check. **OQ5:** the additive-vs-fix distinction is one extra `Subsume` call in the opposite direction; nothing else new is needed in `library`.

Not shown, because the fixtures are local directories: predecessor selection from a registry (0011 D23's backward scan) and loading a published build, both of which the CLI's catalog gate already does with `predecessorVersions` and `loadPublishedPackage`.

Hypothesis held. The catalog walk plus one reverse subsumption classifies all seven candidates as D2 specifies, and the refusal is a comparison of two levels.
