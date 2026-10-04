#!/usr/bin/env python3
"""Semantic comparison of two Kubernetes manifest streams.

    hack/compare.py source/install.yaml out/rendered.yaml [--json-dir out/normalized]

Each object is keyed by kind/namespace/name and normalized to sorted JSON
(key order is irrelevant; list order is kept, since it can matter). The
report lists objects present on one side only, then every leaf-level
difference per matched object, with metadata.labels and annotations
reported separately from the spec so the two kinds of drift do not hide each
other. Exit 0 always; the report is the result.
"""
import json
import os
import sys

import yaml


def load(path):
    with open(path) as f:
        docs = [d for d in yaml.safe_load_all(f) if d]
    out = {}
    for d in docs:
        md = d.get("metadata", {})
        key = f'{d["kind"]}/{md.get("namespace", "")}/{md["name"]}'
        out[key] = d
    return out


def diff(a, b, path=""):
    """Yield (path, left, right) for every leaf that differs."""
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            p = f"{path}.{k}"
            if k not in a:
                yield p, "<absent>", b[k]
            elif k not in b:
                yield p, a[k], "<absent>"
            else:
                yield from diff(a[k], b[k], p)
    elif isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
        for i, (x, y) in enumerate(zip(a, b)):
            yield from diff(x, y, f"{path}[{i}]")
    elif a != b:
        yield path, a, b


def short(v):
    s = json.dumps(v, sort_keys=True)
    return s if len(s) <= 160 else s[:157] + "..."


def main():
    left_path, right_path = sys.argv[1], sys.argv[2]
    json_dir = None
    if "--json-dir" in sys.argv:
        json_dir = sys.argv[sys.argv.index("--json-dir") + 1]
    left, right = load(left_path), load(right_path)

    print(f"left  = {left_path} ({len(left)} objects)")
    print(f"right = {right_path} ({len(right)} objects)\n")

    only_l = sorted(set(left) - set(right))
    only_r = sorted(set(right) - set(left))
    print("## objects only in left (by kind/namespace/name)")
    for k in only_l:
        print("  -", k)
    print("## objects only in right")
    for k in only_r:
        print("  +", k)

    if json_dir:
        os.makedirs(json_dir, exist_ok=True)
        for side, objs in (("left", left), ("right", right)):
            for k, v in objs.items():
                fn = os.path.join(json_dir, side + "__" + k.replace("/", "_") + ".json")
                with open(fn, "w") as f:
                    json.dump(v, f, sort_keys=True, indent=1)

    print("\n## differences in matched objects")
    same = 0
    for k in sorted(set(left) & set(right)):
        l, r = left[k], right[k]
        meta = []
        for part in ("labels", "annotations"):
            meta += list(diff(l.get("metadata", {}).get(part, {}),
                              r.get("metadata", {}).get(part, {}), f".metadata.{part}"))
        lb = {**l, "metadata": {x: y for x, y in l["metadata"].items() if x not in ("labels", "annotations")}}
        rb = {**r, "metadata": {x: y for x, y in r["metadata"].items() if x not in ("labels", "annotations")}}
        body = list(diff(lb, rb))
        if not meta and not body:
            same += 1
            continue
        print(f"\n### {k}")
        for p, a, b in body:
            print(f"  spec  {p}: {short(a)} -> {short(b)}")
        for p, a, b in meta:
            print(f"  meta  {p}: {short(a)} -> {short(b)}")
    print(f"\n{same} matched objects identical (labels and annotations included)")


if __name__ == "__main__":
    main()
