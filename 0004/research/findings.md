# Findings: where the CUE modules sit

Measured 2026-09-29, for D7 and D11. The question: how many CUE modules does each affected repo track, and how deep do they sit? D7:R1 says the updater walks a directory and finds every module at any depth, with no per-repo list. D11 says fixture modules are bumped like any other.

## Method

Run from the workspace root, on each repo's `main` at the commit shown. Only git-tracked files count, so a local CUE cache is excluded. Depth is the number of directories between the repo root and the module root: a module at the repo root has depth 0.

```bash
for r in core library catalog_opm cli opm-operator modules; do
  l=$(git -C $r ls-files | grep 'cue.mod/module.cue$')
  n=$(printf '%s\n' "$l" | grep -c .)
  d=$(printf '%s\n' "$l" | awk -F/ '{print NF-2}' | sort -n | tail -1)
  echo "$r $(git -C $r rev-parse --short HEAD) modules=$n maxdepth=$d"
done
for r in core library catalog_opm cli opm-operator modules; do
  git -C $r ls-files | grep 'cue.mod/module.cue$' | awk -F/ '{print NF-2}' | sort -n | head -1
done
git -C library ls-files | grep 'cue.mod/module.cue$' | grep -c '^testdata/'
```

## Result (measured)

| Repo | Commit | Tracked CUE modules | Deepest module root |
| --- | --- | --- | --- |
| core | 4c68be0 | 1 | 1 |
| library | bec8ddd | 21 | 4 |
| catalog_opm | dc33389 | 2 | 1 |
| cli | e9a9e4e | 18 | 5 |
| opm-operator | 8529e00 | 9 | 4 |
| modules | 5ca1ec1 | 8 | 1 |

- 59 tracked CUE modules across the six repos.
- No repo has a module at its root: every module root sits at least one directory down, and in `opm-operator` at least four.
- In `library`, 20 of the 21 modules are under `testdata/`.

## What this supports

- **D7:R1 (discovery walks, no list).** Module roots sit between one and five directories down, and five of the six repos hold several. A fixed per-repo list would need 59 entries kept in step by hand.
- **D11 (fixtures included).** Fixtures are most of the modules in `library`, so excluding them would leave most of that repo's modules unbumped. D11 cites about 63 fixture modules as of 2026-06-18. Today's tracked count is 20. The decision does not rest on the number, only on fixtures being bumped like any other module.
