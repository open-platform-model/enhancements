#!/usr/bin/env python3
"""objdiff.py before.yaml after.yaml - diff object bodies (kubectl List dumps),
ignoring managedFields, resourceVersion, generation, status. Prints every
changed path per object, and per-object managedFields managers."""
import sys, yaml, json
def load(p):
    out = {}
    for doc in yaml.safe_load_all(open(p)):
        if not doc: continue
        for o in (doc.get("items") or [doc]):
            k = f'{o["kind"]} {o["metadata"].get("namespace","-")}/{o["metadata"]["name"]}'
            out[k] = o
    return out
def strip(o):
    o = json.loads(json.dumps(o)); m = o["metadata"]
    for f in ("managedFields","resourceVersion","generation"): m.pop(f, None)
    o.pop("status", None); return o
def walk(a, b, path, out):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a)|set(b)): walk(a.get(k), b.get(k), f"{path}.{k}", out)
    elif a != b: out.append(f"{path}: {json.dumps(a)} -> {json.dumps(b)}")
A, B = load(sys.argv[1]), load(sys.argv[2])
for k in sorted(set(A)|set(B)):
    if k not in A or k not in B: print(f"{k}: {'ADDED' if k in B else 'REMOVED'}"); continue
    d = []; walk(strip(A[k]), strip(B[k]), "", d)
    mgr = lambda o: [f'{m["manager"]}/{m["operation"]}' + (f'/{m["subresource"]}' if m.get("subresource") else "") for m in o["metadata"].get("managedFields", [])]
    print(f"{k}\n  managers before={mgr(A[k])} after={mgr(B[k])}")
    for line in d: print(f"  {line}")
