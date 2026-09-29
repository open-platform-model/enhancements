#!/usr/bin/env python3
"""Per-case assertions over `opm module build -o json` output. Copied shape: experiment 01."""
import json
import sys

import yaml  # PyYAML, for the velero policy ConfigMap

TARGET = "backup.k8up.opmodel.dev/target"
VOL = "volume.opmodel.dev/name"


def load(path):
    with open(path) as f:
        raw = f.read().strip()
    if not raw:
        return []
    docs = json.loads(raw)
    return docs if isinstance(docs, list) else [docs]


def kinds(docs):
    return sorted(d["kind"] for d in docs)


def one(docs, kind, name=None):
    hits = [d for d in docs if d["kind"] == kind and (name is None or d["metadata"]["name"] == name)]
    if len(hits) != 1:
        raise AssertionError(f"expected exactly one {kind} {name or ''}, got {len(hits)}")
    return hits[0]


def subset(small, big):
    return all(big.get(k) == v for k, v in small.items())


def pvcs(docs):
    return [d for d in docs if d["kind"] == "PersistentVolumeClaim"]


def check_p1(docs):
    ps = pvcs(docs)
    assert len(ps) == 2, f"expected two PVCs, got {len(ps)}"
    assert {p["metadata"]["labels"].get(VOL) for p in ps} == {"data", "dumps"}
    for p in ps:
        assert p["metadata"]["name"].endswith("-" + p["metadata"]["labels"][VOL]), p["metadata"]["name"]


def check_a(docs):
    assert kinds(docs) == ["ConfigMap", "Deployment", "PersistentVolumeClaim", "Schedule"], kinds(docs)
    dep, pvc, s, cm = one(docs, "Deployment"), one(docs, "PersistentVolumeClaim"), one(docs, "Schedule"), one(docs, "ConfigMap")
    b = s["spec"]["backend"]
    assert b["s3"]["bucket"] == "mc-backup/web-demo" and b["s3"]["endpoint"] == "http://10.10.0.2:30304"
    assert b["repoPasswordSecretRef"] == {"name": "mc-backup-restic", "key": "RESTIC_PASSWORD"}
    assert b["envFrom"] == [{"configMapRef": {"name": cm["metadata"]["name"]}}]
    assert cm["data"] == {"RESTIC_EXCLUDE": "cache,*.tmp"}
    sel = s["spec"]["backup"]["labelSelectors"]
    assert len(sel) == 1 and sel[0]["matchLabels"] == dep["spec"]["selector"]["matchLabels"], sel
    assert subset(sel[0]["matchLabels"], pvc["metadata"]["labels"])
    assert s["spec"]["prune"]["retention"] == {"keepDaily": 7, "keepWeekly": 4}


def check_b(docs):
    assert kinds(docs) == ["PersistentVolumeClaim", "PersistentVolumeClaim", "PreBackupPod", "Schedule", "StatefulSet"], kinds(docs)
    s, p, sts = one(docs, "Schedule"), one(docs, "PreBackupPod"), one(docs, "StatefulSet")
    assert s["spec"]["backend"]["s3"]["bucket"] == "mc-backup/mariadb-demo"
    assert s["spec"]["prune"]["schedule"] == "0 3 * * 0" and s["spec"]["check"]["schedule"] == "0 4 * * 0"
    sel = s["spec"]["backup"]["labelSelectors"]
    assert sel == [{"matchLabels": {TARGET: "mariadb-demo-db"}}], sel
    assert subset(sel[0]["matchLabels"], p["metadata"]["labels"])
    for pvc in pvcs(docs):
        assert not subset(sel[0]["matchLabels"], pvc["metadata"]["labels"]), "a PVC matches the command selector"
    assert not subset(sel[0]["matchLabels"], sts["spec"]["template"]["metadata"]["labels"])
    assert p["spec"]["fileExtension"] == "-mariadb-demo-db.sql"
    assert p["spec"]["backupCommand"].startswith("sh -c 'mariadb-dump") and "-h mariadb-demo-db" in p["spec"]["backupCommand"]
    ps = p["spec"]["pod"]["spec"]
    assert "volumes" not in ps and "affinity" not in ps and "volumeMounts" not in ps["containers"][0], "no command volumes declared"


def check_c(docs):
    assert kinds(docs) == ["ConfigMap", "PersistentVolumeClaim", "PersistentVolumeClaim", "Schedule", "StatefulSet"], kinds(docs)
    s, cm = one(docs, "Schedule"), one(docs, "ConfigMap")
    t = s["spec"]["template"]
    assert s["metadata"]["namespace"] == "velero" and cm["metadata"]["namespace"] == "velero"
    assert t["storageLocation"] == "mc-backup" and t["ttl"] == "4464h", (t.get("storageLocation"), t.get("ttl"))
    assert t["resourcePolicy"] == {"kind": "configmap", "name": cm["metadata"]["name"]}
    pol = yaml.safe_load(cm["data"]["policy.yaml"])
    assert len(pol["volumePolicies"]) == 1 and pol["volumePolicies"][0]["conditions"]["pvcLabels"][VOL] == "data"
    rule = pol["volumePolicies"][0]["conditions"]["pvcLabels"]
    assert subset(rule, one(docs, "PersistentVolumeClaim", "mariadb-demo-db-data")["metadata"]["labels"])
    assert not subset(rule, one(docs, "PersistentVolumeClaim", "mariadb-demo-db-dumps")["metadata"]["labels"])
    h = t["hooks"]["resources"][0]
    assert len(h["pre"]) == 1 and "post" not in h
    cmd = h["pre"][0]["exec"]["command"]
    assert cmd[:2] == ["sh", "-c"] and cmd[2].startswith("mariadb-dump") and cmd[2].endswith(" > /dumps/app.sql"), cmd
    assert h["pre"][0]["exec"]["container"] == "mariadb"


def check_d(docs):
    assert kinds(docs) == ["ConfigMap", "PersistentVolumeClaim", "PersistentVolumeClaim", "PreBackupPod", "Schedule", "StatefulSet"], kinds(docs)
    s, p, sts = one(docs, "Schedule"), one(docs, "PreBackupPod"), one(docs, "StatefulSet")
    assert one(docs, "ConfigMap")["data"]["RESTIC_EXCLUDE"].startswith("*.jar,cache,logs")
    assert s["spec"]["backup"]["labelSelectors"] == [{"matchLabels": {TARGET: "mc-demo-server"}}]
    assert s["spec"]["prune"]["retention"] == {"keepHourly": 480}, s["spec"]["prune"]["retention"]
    ps = p["spec"]["pod"]["spec"]
    assert p["spec"]["fileExtension"] == "-mc-demo-server.tar"
    assert p["spec"]["backupCommand"].startswith("sh -c 'rcon-cli --host mc-demo-server save-off && ") and "save-on; exit $s'" in p["spec"]["backupCommand"]
    assert ps["volumes"] == [{"name": "data", "persistentVolumeClaim": {"claimName": "mc-demo-server-data", "readOnly": True}}], ps["volumes"]
    assert one(docs, "PersistentVolumeClaim", "mc-demo-server-data")
    c = ps["containers"][0]
    assert c["volumeMounts"] == [{"name": "data", "mountPath": "/data", "readOnly": True}], c["volumeMounts"]
    assert c["image"] == sts["spec"]["template"]["spec"]["containers"][0]["image"]
    aff = ps["affinity"]["podAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"][0]
    assert aff["topologyKey"] == "kubernetes.io/hostname"
    assert aff["labelSelector"]["matchLabels"] == sts["spec"]["selector"]["matchLabels"]


def check_e(docs):
    assert kinds(docs) == ["ConfigMap", "PersistentVolumeClaim", "PersistentVolumeClaim", "Schedule", "StatefulSet"], kinds(docs)
    s, cm = one(docs, "Schedule"), one(docs, "ConfigMap")
    t = s["spec"]["template"]
    assert t["ttl"] == "480h" and t["defaultVolumesToFsBackup"] is True
    pol = yaml.safe_load(cm["data"]["policy.yaml"])
    assert [r["conditions"]["pvcLabels"][VOL] for r in pol["volumePolicies"]] == ["data"], pol
    h = t["hooks"]["resources"][0]
    cmd = h["pre"][0]["exec"]["command"]
    assert cmd[2].startswith("rcon-cli --host mc-demo-server save-off") and cmd[2].endswith("; exit $s > /backups/world.tar"), cmd
    assert h["pre"][0]["exec"]["container"] == "minecraft"
    assert h["post"] == [{"exec": {"container": "minecraft", "command": ["rcon-cli", "save-on"], "onError": "Continue", "timeout": "30s"}}], h["post"]


def owned_common(docs):
    cm = one(docs, "ConfigMap", "mc-demo-server-backup-config")
    assert cm["metadata"]["namespace"] == "demo"
    assert cm["data"] == {
        "RESTIC_REPOSITORY": "s3:http://10.10.0.2:30304/mc-backup/mc-demo",
        "RESTIC_HOSTNAME": "demo",
        "CRON_SCHEDULE": "0 * * * *",
        "PRUNE_RESTIC_RETENTION": "--keep-within 20d",
        "EXCLUDES": "*.jar,cache,logs,*.tmp,bluemap/web/maps/**",
    }, cm["data"]
    sts = one(docs, "StatefulSet")
    side = [c for c in sts["spec"]["template"]["spec"]["containers"] if c["name"] == "backup"]
    assert len(side) == 1, "sidecar missing"
    assert {"configMapRef": {"name": cm["metadata"]["name"]}} in side[0]["envFrom"], side[0]["envFrom"]
    assert {"secretRef": {"name": "mc-backup-restic"}} in side[0]["envFrom"]


def check_f(docs):
    assert kinds(docs) == ["ConfigMap", "PersistentVolumeClaim", "Schedule", "StatefulSet"], kinds(docs)
    owned_common(docs)
    s = one(docs, "Schedule")
    assert "backup" not in s["spec"], "k8up must not take backups of an owned repository"
    assert s["spec"]["backend"]["s3"]["bucket"] == "mc-backup/mc-demo"
    assert s["spec"]["prune"]["retention"] == {"keepHourly": 480}
    assert s["spec"]["check"]["schedule"] == "@weekly-random"
    assert "envFrom" not in s["spec"]["backend"], "excludes belong to the sidecar, not to maintenance"


def check_g(docs):
    assert kinds(docs) == ["ConfigMap", "PersistentVolumeClaim", "StatefulSet"], kinds(docs)
    owned_common(docs)


CASES = {"P1": check_p1, "A": check_a, "B": check_b, "C": check_c, "D": check_d, "E": check_e, "F": check_f, "G": check_g}

if __name__ == "__main__":
    case, path = sys.argv[1], sys.argv[2]
    try:
        CASES[case](load(path))
        print("ok")
    except AssertionError as e:
        print(f"FAIL: {e}")
    except Exception as e:  # noqa: BLE001
        print(f"ERROR: {type(e).__name__}: {e}")
