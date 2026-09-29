#!/usr/bin/env python3
"""Per-case assertions over `opm module build -o json` output.

Usage: check.py <case> <out.json>  -> prints "ok" or the first failed check.
"""
import json
import sys

FQN = "testing.opmodel.dev/experiments/0015/contracts/traits/backup@v1alpha1"


def load(path):
    with open(path) as f:
        raw = f.read().strip()
    if not raw:
        return []
    docs = json.loads(raw)
    return docs if isinstance(docs, list) else [docs]


def kinds(docs):
    return sorted({d["kind"] for d in docs})


def one(docs, kind):
    hits = [d for d in docs if d["kind"] == kind]
    if len(hits) != 1:
        raise AssertionError(f"expected exactly one {kind}, got {len(hits)}")
    return hits[0]


def subset(small, big):
    return all(big.get(k) == v for k, v in small.items())


def case_base(docs):
    dep = one(docs, "Deployment")
    pvc = one(docs, "PersistentVolumeClaim")
    return dep, pvc


def check_a(docs):
    assert kinds(docs) == ["Deployment", "PersistentVolumeClaim", "Schedule"], f"kinds {kinds(docs)}"
    dep, pvc = case_base(docs)
    s = one(docs, "Schedule")
    assert s["apiVersion"] == "k8up.io/v1", s["apiVersion"]
    assert "backend" not in s["spec"], "spec.backend present"
    assert s["metadata"]["namespace"] == "demo", s["metadata"]["namespace"]
    assert s["metadata"]["name"] == dep["metadata"]["name"], (s["metadata"]["name"], dep["metadata"]["name"])
    assert s["spec"]["backup"]["schedule"] == "0 2 * * *"
    assert s["spec"]["prune"]["retention"] == {"keepDaily": 7, "keepWeekly": 4}, s["spec"]["prune"]["retention"]
    sel = s["spec"]["backup"]["labelSelectors"][0]["matchLabels"]
    assert sel == dep["spec"]["selector"]["matchLabels"], (sel, dep["spec"]["selector"]["matchLabels"])
    assert subset(sel, dep["spec"]["template"]["metadata"]["labels"]), "selector not on pod labels"
    assert subset(sel, pvc["metadata"]["labels"]), f"selector not on PVC labels: {pvc['metadata']['labels']}"


def check_refused(docs):
    assert docs == [], f"expected no output, got kinds {kinds(docs)}"


def check_d(docs):
    assert kinds(docs) == ["Deployment", "PersistentVolumeClaim"], f"kinds {kinds(docs)}"


def check_e(docs):
    assert kinds(docs) == ["Deployment", "PersistentVolumeClaim", "Schedule"], f"kinds {kinds(docs)}"
    dep, _ = case_base(docs)
    s = one(docs, "Schedule")
    assert s["apiVersion"] == "velero.io/v1", s["apiVersion"]
    assert s["metadata"]["namespace"] == "velero"
    assert s["spec"]["schedule"] == "0 2 * * *"
    t = s["spec"]["template"]
    assert t["includedNamespaces"] == ["demo"], t["includedNamespaces"]
    assert t["ttl"] == "672h", t["ttl"]
    assert t["labelSelector"]["matchLabels"] == dep["spec"]["selector"]["matchLabels"]


CASES = {"A": check_a, "B": check_refused, "C": check_refused, "D": check_d, "E": check_e}

if __name__ == "__main__":
    case, path = sys.argv[1], sys.argv[2]
    try:
        CASES[case](load(path))
        print("ok")
    except AssertionError as e:
        print(f"FAIL: {e}")
    except Exception as e:  # noqa: BLE001
        print(f"ERROR: {type(e).__name__}: {e}")
