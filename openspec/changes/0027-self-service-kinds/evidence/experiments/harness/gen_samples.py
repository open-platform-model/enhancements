#!/usr/bin/env python3
"""x1a: generate CUE sample packages and value fixtures for experiments E1/E3/OQ21.

Each sample is a package under cue/samples/<id>/ with a #config, plus
fixtures.json: a list of {name, values} the harness checks against CUE (ground
truth) and against the API server (dry-run) under every encoding.
"""
import json, os, textwrap

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cue", "samples")

S = {}  # id -> (imports, body, fixtures)

def add(sid, body, fixtures, imp=""):
    S[sid] = (imp, textwrap.dedent(body), fixtures)

OLD = 'import core "x1a.example/s/coreold"'
W1 = 'import core "x1a.example/s/corev2"'
W2 = 'import core "x1a.example/s/corev2w2"'

# ---------------- E1: secrets ----------------
sec_fx_common = [
    ("literal", {"pw": {"value": "hunter2"}}),
    ("ref", {"pw": {"ref": "db-creds", "key": "password"}}),
    ("ref-dotted-name", {"pw": {"ref": "tls.example.com", "key": "tls.key"}}),
    ("bare-string", {"pw": "hunter2"}),
    ("literal-and-ref", {"pw": {"value": "hunter2", "ref": "db-creds", "key": "password"}}),
    ("ref-without-key", {"pw": {"ref": "db-creds"}}),
    ("key-without-ref", {"pw": {"key": "password"}}),
    ("empty-object", {"pw": {}}),
    ("unknown-field", {"pw": {"value": "hunter2", "extra": 1}}),
    ("literal-wrong-type", {"pw": {"value": 12345}}),
    ("ref-bad-name", {"pw": {"ref": "Not_A_Name", "key": "password"}}),
    ("ref-bad-key", {"pw": {"ref": "db-creds", "key": "a/b"}}),
    ("missing", {}),
    ("source", {"pw": {"source": "secrets.example.com/eso/external@v1", "spec": {"remoteKey": "prod/db"}}}),
    ("source-settings", {"pw": {"source": "secrets.example.com/eso/external@v1", "settings": {"store": "vault"}, "spec": {"remoteKey": "prod/db"}}}),
    ("source-bad-fqn", {"pw": {"source": "eso"}}),
    ("source-and-literal", {"pw": {"value": "x", "source": "secrets.example.com/eso/external@v1"}}),
    ("spec-without-source", {"pw": {"spec": {"remoteKey": "prod/db"}}}),
]

add("sec-old", """
    #config: {
    	pw: core.#Secret & {$secretName: "db", $dataKey: "password"}
    }
""", [("literal", {"pw": {"value": "hunter2"}}),
      ("k8sref", {"pw": {"secretName": "db-creds", "remoteKey": "password"}}),
      ("bare-string", {"pw": "hunter2"}),
      ("literal-and-ref", {"pw": {"value": "x", "secretName": "a", "remoteKey": "b"}}),
      ("missing", {}),
      ("ref-arm-new-names", {"pw": {"ref": "db-creds", "key": "password"}})], OLD)

add("sec-w1", """
    #config: {
    	// Database password.
    	pw: core.#Secret @opm(secret, group=db)
    }
""", sec_fx_common, W1)

add("sec-w2", """
    #config: {
    	// Database password.
    	pw: core.#Secret @opm(secret, group=db)
    }
""", sec_fx_common, W2)

add("sec-w2-optional", """
    #config: {
    	pw?: core.#Secret @opm(secret, group=api)
    }
""", [("absent", {}), ("ref", {"pw": {"ref": "a", "key": "b"}}),
      ("literal-and-ref", {"pw": {"value": "x", "ref": "a", "key": "b"}})], W2)

add("sec-w2-collections", """
    #config: {
    	extra: [string]: core.#Secret @opm(secret, group=extra)
    	certs: [...core.#Secret] @opm(secret, group=certs)
    	db: {
    		user: string | *"app"
    		password: core.#Secret @opm(secret, group=db)
    	}
    }
""", [("ok", {"extra": {"a": {"value": "x"}, "b": {"ref": "s", "key": "k"}},
              "certs": [{"ref": "c", "key": "tls.crt"}], "db": {"password": {"value": "p"}}}),
      ("bad-map-entry", {"extra": {"a": {"value": "x", "ref": "s", "key": "k"}}, "certs": [], "db": {"password": {"value": "p"}}}),
      ("bad-list-entry", {"extra": {}, "certs": [{"ref": "c"}], "db": {"password": {"value": "p"}}}),
      ("nested-missing", {"extra": {}, "certs": [], "db": {}})], W2)

# ---------------- E3: unions ----------------
add("u01-disc-string", """
    #config: {
    	backup: {kind: "s3", bucket!: string, region: string | *"eu-north-1"} | {kind: "nfs", server!: string, path: string | *"/"}
    }
""", [("s3", {"backup": {"kind": "s3", "bucket": "b"}}),
      ("nfs", {"backup": {"kind": "nfs", "server": "srv", "path": "/x"}}),
      ("s3-no-kind", {"backup": {"bucket": "b"}}),
      ("mixed", {"backup": {"kind": "s3", "bucket": "b", "server": "srv"}}),
      ("s3-missing-bucket", {"backup": {"kind": "s3"}}),
      ("unknown-kind", {"backup": {"kind": "gcs", "bucket": "b"}}),
      ("wrong-arm-field", {"backup": {"kind": "nfs", "bucket": "b"}}),
      ("missing", {})])

add("u02-default-arm", """
    #config: {
    	backup: *{kind: "none"} | {kind: "s3", bucket!: string}
    }
""", [("absent", {}), ("none", {"backup": {"kind": "none"}}),
      ("s3", {"backup": {"kind": "s3", "bucket": "b"}}),
      ("none-with-bucket", {"backup": {"kind": "none", "bucket": "b"}})])

add("u03-disc-defs", """
    #S3: {kind: "s3", bucket!: string}
    #NFS: {kind: "nfs", server!: string}
    #config: {
    	backup: #S3 | #NFS
    }
""", [("s3", {"backup": {"kind": "s3", "bucket": "b"}}),
      ("mixed", {"backup": {"kind": "s3", "bucket": "b", "server": "s"}}),
      ("nfs-missing", {"backup": {"kind": "nfs"}})])

add("u04-shared-field", """
    #config: {
    	store: {kind: "s3", endpoint!: string, bucket!: string} | {kind: "minio", endpoint!: string}
    }
""", [("s3", {"store": {"kind": "s3", "endpoint": "e", "bucket": "b"}}),
      ("minio", {"store": {"kind": "minio", "endpoint": "e"}}),
      ("minio-with-bucket", {"store": {"kind": "minio", "endpoint": "e", "bucket": "b"}})])

add("u05-conflict-type", """
    #config: {
    	vol: {kind: "a", size: int} | {kind: "b", size: string}
    }
""", [("a", {"vol": {"kind": "a", "size": 3}}), ("b", {"vol": {"kind": "b", "size": "3Gi"}}),
      ("a-string", {"vol": {"kind": "a", "size": "3Gi"}})])

add("u06-disc-bool", """
    #config: {
    	tls: {enabled: true, secretName!: string} | {enabled: false}
    }
""", [("on", {"tls": {"enabled": True, "secretName": "s"}}), ("off", {"tls": {"enabled": False}}),
      ("off-with-name", {"tls": {"enabled": False, "secretName": "s"}}),
      ("on-missing", {"tls": {"enabled": True}})])

add("u07-disc-int", """
    #config: {
    	cfg: {version: 1, a!: string} | {version: 2, b!: string}
    }
""", [("v1", {"cfg": {"version": 1, "a": "x"}}), ("v2", {"cfg": {"version": 2, "b": "x"}}),
      ("v1-with-b", {"cfg": {"version": 1, "a": "x", "b": "y"}})])

add("u08-presence-only", """
    #config: {
    	src: {url!: string} | {configMapRef!: string}
    }
""", [("url", {"src": {"url": "u"}}), ("cm", {"src": {"configMapRef": "c"}}),
      ("both", {"src": {"url": "u", "configMapRef": "c"}}), ("none", {"src": {}})])

add("u09-disc-missing-in-arm", """
    #config: {
    	backup: {kind: "s3", bucket!: string} | {server!: string}
    }
""", [("s3", {"backup": {"kind": "s3", "bucket": "b"}}), ("srv", {"backup": {"server": "s"}}),
      ("mixed", {"backup": {"kind": "s3", "bucket": "b", "server": "s"}})])

add("u10-scalar-or-struct", """
    #config: {
    	image: string | {repository!: string, tag: string | *"latest"}
    }
""", [("str", {"image": "nginx:1"}), ("obj", {"image": {"repository": "nginx"}}),
      ("int", {"image": 3})])

add("u11-list-items", """
    #config: {
    	volumes: [...({type: "pvc", claim!: string} | {type: "emptyDir", medium?: string})]
    }
""", [("ok", {"volumes": [{"type": "pvc", "claim": "c"}, {"type": "emptyDir"}]}),
      ("mixed", {"volumes": [{"type": "emptyDir", "claim": "c"}]})])

add("u12-map-values", """
    #config: {
    	stores: [string]: {kind: "s3", bucket!: string} | {kind: "nfs", server!: string}
    }
""", [("ok", {"stores": {"a": {"kind": "s3", "bucket": "b"}, "n": {"kind": "nfs", "server": "s"}}}),
      ("mixed", {"stores": {"a": {"kind": "s3", "bucket": "b", "server": "s"}}})])

add("u13-open-arms", """
    #config: {
    	ext: {kind: "s3", ...} | {kind: "nfs", ...}
    }
""", [("s3", {"ext": {"kind": "s3", "anything": 1}}), ("bad", {"ext": {"kind": "gcs"}})])

add("u14-nested-union", """
    #config: {
    	backup: {kind: "s3", auth: {mode: "key", id!: string} | {mode: "iam"}} | {kind: "nfs", server!: string}
    }
""", [("s3-key", {"backup": {"kind": "s3", "auth": {"mode": "key", "id": "x"}}}),
      ("s3-iam", {"backup": {"kind": "s3", "auth": {"mode": "iam"}}}),
      ("s3-iam-with-id", {"backup": {"kind": "s3", "auth": {"mode": "iam", "id": "x"}}}),
      ("nfs", {"backup": {"kind": "nfs", "server": "s"}})])

add("u15-dup-disc", """
    #config: {
    	x: {kind: "s3", a!: string} | {kind: "s3", b!: int}
    }
""", [("a", {"x": {"kind": "s3", "a": "x"}}), ("b", {"x": {"kind": "s3", "b": 1}}),
      ("ab", {"x": {"kind": "s3", "a": "x", "b": 1}})])

add("u16-two-disc", """
    #config: {
    	x: {kind: "s3", class: "object", bucket!: string} | {kind: "nfs", class: "file", server!: string}
    }
""", [("s3", {"x": {"kind": "s3", "class": "object", "bucket": "b"}}),
      ("s3-kind-only", {"x": {"kind": "s3", "bucket": "b"}}),
      ("clash", {"x": {"kind": "s3", "class": "file", "bucket": "b"}})])

add("u17-optional-union", """
    #config: {
    	backup?: {kind: "s3", bucket!: string} | {kind: "nfs", server!: string}
    }
""", [("absent", {}), ("s3", {"backup": {"kind": "s3", "bucket": "b"}}),
      ("mixed", {"backup": {"kind": "nfs", "server": "s", "bucket": "b"}})])

add("u18-embedded-base", """
    #Base: {name!: string}
    #config: {
    	x: {#Base, kind: "a"} | {#Base, kind: "b", n!: int}
    }
""", [("a", {"x": {"kind": "a", "name": "n"}}), ("b", {"x": {"kind": "b", "name": "n", "n": 1}}),
      ("a-with-n", {"x": {"kind": "a", "name": "n", "n": 1}}), ("a-no-name", {"x": {"kind": "a"}})])

# ---------------- OQ21: required vs defaulted ----------------
add("r01-required", """
    #config: {
    	reqMarked!: string
    	regularNoDefault: string
    	defaulted: int | *3
    	optional?: string
    	constant: "fixed"
    	computed: "\\(reqMarked)-svc"
    	nested: {inner: string | *"x"}
    	nestedReq: {inner!: string}
    	listDefault: [...string] | *["a"]
    	boolDefault: *false | bool
    	app: string | *"app"
    	fromDefault: "\\(app)-x"
    }
""", [("minimal", {"reqMarked": "a", "regularNoDefault": "b", "nestedReq": {"inner": "i"}}),
      ("fromdefault-changed-input", {"reqMarked": "a", "regularNoDefault": "b", "nestedReq": {"inner": "i"}, "app": "web"}),
      ("fromdefault-given-matching", {"reqMarked": "a", "regularNoDefault": "b", "nestedReq": {"inner": "i"}, "app": "web", "fromDefault": "web-x"}),
      ("no-regular", {"reqMarked": "a", "nestedReq": {"inner": "i"}}),
      ("no-marked", {"regularNoDefault": "b", "nestedReq": {"inner": "i"}}),
      ("constant-wrong", {"reqMarked": "a", "regularNoDefault": "b", "nestedReq": {"inner": "i"}, "constant": "other"}),
      ("computed-given", {"reqMarked": "a", "regularNoDefault": "b", "nestedReq": {"inner": "i"}, "computed": "a-svc"}),
      ("computed-wrong", {"reqMarked": "a", "regularNoDefault": "b", "nestedReq": {"inner": "i"}, "computed": "zzz"}),
      ("no-nestedReq", {"reqMarked": "a", "regularNoDefault": "b"}),
      ("all", {"reqMarked": "a", "regularNoDefault": "b", "defaulted": 4, "optional": "o", "constant": "fixed",
               "nested": {"inner": "y"}, "nestedReq": {"inner": "i"}, "listDefault": ["b"], "boolDefault": True})])


add("u16b-two-disc-hint", """
    #config: {
    	x: ({kind: "s3", class: "object", bucket!: string} | {kind: "nfs", class: "file", server!: string}) @opm(ui, discriminator=kind)
    }
""", [("s3", {"x": {"kind": "s3", "class": "object", "bucket": "b"}}),
      ("s3-kind-only", {"x": {"kind": "s3", "bucket": "b"}}),
      ("clash", {"x": {"kind": "s3", "class": "file", "bucket": "b"}})])

add("sec-w2-deep", """
    #config: {
    	tenants: [string]: {
    		users: [...{name!: string, password: core.#Secret @opm(secret, group=users)}]
    	}
    }
""", [("ok", {"tenants": {"a": {"users": [{"name": "u", "password": {"ref": "s", "key": "k"}}]}}}),
      ("bad", {"tenants": {"a": {"users": [{"name": "u", "password": {"value": "hunter2", "ref": "s", "key": "k"}}]}}})], W2)

_many = "\n".join(f"    \tlist{i}: [...core.#Secret]" for i in range(25))
add("sec-w2-many", "\n    #config: {\n" + _many + "\n    }\n",
    [("ok", {f"list{i}": [{"value": "x"}] for i in range(25)}),
     ("bad", {"list0": [{"value": "x", "source": "a.b/c@v1"}], **{f"list{i}": [] for i in range(1, 25)}})], W2)


add("sec-lookalike", """
    #config: {
    	// Same shape as core's #Secret, no core tag.
    	pw: {value!: string} | {ref!: string, key!: string}
    }
""", [("literal", {"pw": {"value": "hunter2"}}), ("both", {"pw": {"value": "hunter2", "ref": "a", "key": "b"}})])

def main():
    for sid, (imp, body, fx) in S.items():
        d = os.path.join(ROOT, sid)
        os.makedirs(d, exist_ok=True)
        pkg = "s_" + sid.replace("-", "_")
        with open(os.path.join(d, "config.cue"), "w") as f:
            f.write(f"package {pkg}\n\n{imp}\n{body}")
        with open(os.path.join(d, "fixtures.json"), "w") as f:
            json.dump([{"name": n, "values": v} for n, v in fx], f, indent=1)
    print(len(S), "samples")

main()
