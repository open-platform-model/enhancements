#!/usr/bin/env python3
"""fieldowners.py dump.yaml - for each object, list the leaf field paths each
Apply manager owns, then: fields owned ONLY by opm-cli, ONLY by opm-controller,
and co-owned."""
import sys, yaml
def leaves(fv, p=""):
    out = set()
    for k, v in (fv or {}).items():
        if k == ".": continue
        q = f"{p}/{k}"
        sub = leaves(v, q)
        out |= sub if sub else {q}
    return out
for doc in yaml.safe_load_all(open(sys.argv[1])):
    if not doc: continue
    for o in (doc.get("items") or [doc]):
        mf = {m["manager"]: leaves(m["fieldsV1"]) for m in o["metadata"].get("managedFields", []) if m["operation"] == "Apply" and not m.get("subresource")}
        if "opm-cli" not in mf: continue
        cli, ctl = mf.get("opm-cli", set()), mf.get("opm-controller", set())
        print(f'{o["kind"]} {o["metadata"].get("namespace","-")}/{o["metadata"]["name"]}: opm-cli={len(cli)} opm-controller={len(ctl)} co-owned={len(cli & ctl)}')
        for f in sorted(cli - ctl): print(f"   only opm-cli: {f}")
        for f in sorted(ctl - cli): print(f"   only opm-controller: {f}")
