// Worked examples for enhancement 0013.
//
// Every value here compiles and unifies against target.cue, so a wrong example
// is a build failure rather than a documentation bug. Derived values (keys,
// object names, content hashes) are computed by the same definitions the kernel
// implements, and the `_assert*` fields pin the results — change a derivation
// and these stop unifying.
//
// Read order follows one secret's life:
//   1. #ExampleConfig    — what the AUTHOR writes (routing, static)
//   2. exDeclarations    — what discovery produces, with no values at all
//   3. exValuesDev/Prod  — what the DEPLOYER writes (fulfilment, per-env)
//   4. exPlans           — the objects the kernel decides to create
//   5. exResolved        — the rewrite: both arms become #SecretRef
//   6. exRenderedEnv/Vol — what a transformer emits, one branch for both arms
//   7. exMetallbBefore/After — the one affected fleet module
package schema

// ─── 1. The author surface ──────────────────────────────────────────────────

// #ExampleConfig: a module's #config with the whole marker grammar exercised.
//
// The field's TYPE is the fulfilment slot; the ATTRIBUTE is the routing. Note
// what is absent from the type: no $opm, no $secretName, no $dataKey. The
// author states which object a key belongs in, and never states where the data
// comes from — they cannot know that.
#ExampleConfig: {
	// The common case. Everything derived: group "secrets", key "db_password".
	db: {
		password: #Secret @opm(secret)
		host:     string // unmarked sibling, untouched by any of this
	}

	// A group — both fields land in ONE object, which is what
	// kubernetes.io/basic-auth requires.
	auth: {
		username: #Secret @opm(secret, group=basic-auth, key=username, type="kubernetes.io/basic-auth")
		password: #Secret @opm(secret, group=basic-auth, key=password, type="kubernetes.io/basic-auth")
	}

	// A key the consuming workload dictates, plus immutability so a cert
	// rotation rolls the workloads that mount it.
	tls: {
		cert: #Secret @opm(secret, group=tls, key="tls.crt", type="kubernetes.io/tls", immutable)
		key:  #Secret @opm(secret, group=tls, key="tls.key", type="kubernetes.io/tls", immutable, description="PEM private key for the ingress certificate")
	}

	// Depth is not a constraint: discovery is a Go recursion with no unrolled
	// level limit. Twelve levels here purely to make that concrete.
	deeply: nested: a: b: c: d: e: f: g: h: i: token: #Secret @opm(secret, group=deep)

	// A pattern constraint propagates the mark to every key the deployer adds,
	// so a module can offer an open-ended map of secrets without knowing names.
	extraSecrets: [string]: #Secret @opm(secret, group=extra)
}

// ─── 2. Discovery output (values not required) ──────────────────────────────

// exDeclarations: what Discover returns for #ExampleConfig. Produced from the
// schema alone — this list exists before any instance does, which is what
// `opm module inspect` prints.
exDeclarations: #SecretDeclList & [
	{path: "db.password", marker: {kind: "secret"}},
	{path: "auth.username", marker: {kind: "secret", group: "basic-auth", key: "username", type: "kubernetes.io/basic-auth"}},
	{path: "auth.password", marker: {kind: "secret", group: "basic-auth", key: "password", type: "kubernetes.io/basic-auth"}},
	{path: "tls.cert", marker: {kind: "secret", group: "tls", key: "tls.crt", type: "kubernetes.io/tls", immutable: true}},
	{path: "tls.key", marker: {kind: "secret", group: "tls", key: "tls.key", type: "kubernetes.io/tls", immutable: true}},
	{path: "deeply.nested.a.b.c.d.e.f.g.h.i.token", marker: {kind: "secret", group: "deep"}},
]

// Key derivation, pinned. `db.password` asked for nothing, so its key comes out
// of the full path — which is why db.password and a hypothetical redis.password
// cannot collide.
_assertDerivedKey: exDeclarations[0].key & "db_password"
_assertDeepKey:    exDeclarations[5].key & "deeply_nested_a_b_c_d_e_f_g_h_i_token"
_assertGivenKey:   exDeclarations[3].key & "tls.crt"

// ─── 3. Fulfilment — the deployer's half ────────────────────────────────────

// The SAME published module, two environments, differing only in which arm each
// secret is filled with. This is what OQ1 was about, and why the choice had to
// live in the type rather than in the attribute: neither of these requires
// republishing the module.

// exValuesDev: everything supplied inline. Dev has no managed certificate.
exValuesDev: [string]: #Secret
exValuesDev: {
	"db.password":   {value: "hunter2"}
	"auth.username": {value: "admin"}
	"auth.password": {value: "s3cr3t"}
	"tls.cert":      {value: "-----BEGIN CERTIFICATE-----\nDEV\n-----END CERTIFICATE-----"}
	"tls.key":       {value: "-----BEGIN PRIVATE KEY-----\nDEV\n-----END PRIVATE KEY-----"}
	"deeply.nested.a.b.c.d.e.f.g.h.i.token": {value: "tok-123"}
}

// exValuesProd: the TLS pair points at a wildcard certificate the platform team
// manages. OPM will not create or own that object.
exValuesProd: [string]: #Secret
exValuesProd: {
	"db.password":   {value: "hunter2"}
	"auth.username": {value: "admin"}
	"auth.password": {value: "s3cr3t"}
	"tls.cert":      {ref: "wildcard-example-com", key: "tls.crt"}
	"tls.key":       {ref: "wildcard-example-com", key: "tls.key"}
	"deeply.nested.a.b.c.d.e.f.g.h.i.token": {value: "tok-123"}
}

// ─── 4. Resolution — the objects the kernel decides to create ───────────────

// exPlans: for instance "myapp" in the PROD values. The `tls` group produces no
// plan — those two secrets are references, so the object is not ours to write.
exPlans: [...#SecretGroupPlan] & [
	{
		group:      "secrets"
		objectName: (#ObjectName & {instance: "myapp", group: "secrets"}).out
		type:       "Opaque"
		data: db_password: "hunter2"
		members: ["db.password"]
	},
	{
		group:      "basic-auth"
		objectName: (#ObjectName & {instance: "myapp", group: "basic-auth"}).out
		type:       "kubernetes.io/basic-auth"
		data: {username: "admin", password: "s3cr3t"}
		members: ["auth.username", "auth.password"]
	},
	{
		group:      "deep"
		objectName: (#ObjectName & {instance: "myapp", group: "deep"}).out
		type:       "Opaque"
		data: deeply_nested_a_b_c_d_e_f_g_h_i_token: "tok-123"
		members: ["deeply.nested.a.b.c.d.e.f.g.h.i.token"]
	},
]

_assertObjectName: exPlans[1].objectName & "myapp-basic-auth"

// An immutable group in the DEV values, where the TLS pair IS supplied. The
// hash is computed before the rewrite, so members' `ref` already carries it and
// every consumer follows the object when the certificate rotates.
exImmutablePlan: #SecretGroupPlan & {
	group:      "tls"
	objectName: (#ImmutableObjectName & {base: "myapp-tls", data: exImmutablePlan.data}).out
	type:       "kubernetes.io/tls"
	immutable:  true
	data: {
		"tls.crt": "-----BEGIN CERTIFICATE-----\nDEV\n-----END CERTIFICATE-----"
		"tls.key": "-----BEGIN PRIVATE KEY-----\nDEV\n-----END PRIVATE KEY-----"
	}
	members: ["tls.cert", "tls.key"]
}

_assertImmutableName: exImmutablePlan.objectName & "myapp-tls-6bf0199259"

// ─── 5. Resolve in place — both arms converge ───────────────────────────────

// exResolvedProd: the render-time values. Every marked path now holds a
// #SecretRef, whichever arm the deployer wrote.
//
// This is the property the whole design turns on: `db.password` was a literal
// and `tls.cert` was a reference, and after resolution they are the same shape.
// Nothing downstream can tell them apart, and nothing needs to.
exResolvedProd: (#ResolveInPlace & {#in: exValuesProd}).out
exResolvedProd: {
	// was {value: "hunter2"} — the kernel invented a place for it
	"db.password": {ref: "myapp-secrets", key: "db_password"}

	"auth.username": {ref: "myapp-basic-auth", key: "username"}
	"auth.password": {ref: "myapp-basic-auth", key: "password"}

	// was already a reference — passes through as itself, never prefixed
	"tls.cert": {ref: "wildcard-example-com", key: "tls.crt"}
	"tls.key":  {ref: "wildcard-example-com", key: "tls.key"}

	"deeply.nested.a.b.c.d.e.f.g.h.i.token": {ref: "myapp-deep", key: "deeply_nested_a_b_c_d_e_f_g_h_i_token"}
}

// No plaintext survives resolution: every resolved value unifies with
// #SecretRef, and #SecretRef is a closed struct with no `value` field. Absence
// of plaintext is therefore structural rather than something the kernel has to
// remember to strip — a secret cannot reach a rendered manifest even by mistake.
_assertAllResolvedAreRefs: {
	for p, v in exResolvedProd {
		(p): #SecretRef & v
	}
}

// ─── 6. Consumption — what a transformer emits ──────────────────────────────

// The author's wiring is unchanged from today: `from: #config.db.password`. By
// render time that reference holds a #SecretRef, and the transformer reads two
// fields. There is no variant dispatch, no prefix test, and no side lookup —
// both examples below come out of the SAME transformer branch.

// A resolved literal — points at the object OPM will create.
exRenderedEnvLiteral: {
	name: "DB_PASSWORD"
	valueFrom: secretKeyRef: {
		name: exResolvedProd["db.password"].ref
		key:  exResolvedProd["db.password"].key
	}
}

// A deployer-written reference — points at the foreign object, unprefixed.
exRenderedEnvRef: {
	name: "TLS_KEY"
	valueFrom: secretKeyRef: {
		name: exResolvedProd["tls.key"].ref
		key:  exResolvedProd["tls.key"].key
	}
}

_assertLiteralRef: exRenderedEnvLiteral.valueFrom.secretKeyRef.name & "myapp-secrets"
_assertForeignRef: exRenderedEnvRef.valueFrom.secretKeyRef.name & "wildcard-example-com"

// A volume mounting a whole group reads `.ref` and ignores `.key`. Because
// there is only one string and it lives in the value, this cannot disagree with
// the env reference above — the class of bug where one site says `myapp-secrets`
// and another says `myapp-web-secrets` is unrepresentable.
exRenderedVolume: {
	name: "basic-auth"
	secret: {
		secretName:  exResolvedProd["auth.username"].ref
		defaultMode: 420
	}
}

_assertVolumeAgreesWithEnv: exRenderedVolume.secret.secretName & exResolvedProd["auth.password"].ref

// ─── 7. The one affected fleet module ───────────────────────────────────────

// modules/metallb is the only module in the workspace fleet carrying a secret
// today. Both halves of its current shape are shown so the migration is
// concrete rather than described.

// exMetallbBefore: today. The routing is stated TWICE — once as $-fields in
// module.cue's #config, once as a hand-written spec.secrets map in
// components.cue — and nothing checks that the two agree.
exMetallbBefore: {
	moduleCue: config: speaker: memberlistKey: {
		"$opm":        "secret"
		"$secretName": "memberlist"
		"$dataKey":    "secretkey"
	}
	componentsCue: speaker: spec: secrets: memberlist: data: secretkey: moduleCue.config.speaker.memberlistKey
	instanceValues: speaker: memberlistKey: value: "BASE64GOSSIPKEY"
}

// exMetallbAfter: the same module. The routing moves to the attribute, the
// hand-written spec.secrets map in components.cue is deleted outright — and the
// INSTANCE VALUES DO NOT CHANGE, because #SecretLiteral is the shape they
// already use.
exMetallbAfter: {
	moduleCue: {
		// Written in the module as:
		//   memberlistKey: #Secret @opm(secret, group=memberlist, key=secretkey)
		declaration: #SecretDecl & {
			path: "speaker.memberlistKey"
			marker: {kind: "secret", group: "memberlist", key: "secretkey"}
		}
	}

	// Byte-identical to exMetallbBefore.instanceValues.
	instanceValues: speaker: memberlistKey: value: "BASE64GOSSIPKEY"

	plan: #SecretGroupPlan & {
		group:      "memberlist"
		objectName: (#ObjectName & {instance: "metallb", group: "memberlist"}).out
		data: secretkey: "BASE64GOSSIPKEY"
		members: ["speaker.memberlistKey"]
	}

	resolved: "speaker.memberlistKey": #SecretRef & {
		ref: plan.objectName
		key: "secretkey"
	}
}

_assertMetallbValuesUnchanged: exMetallbAfter.instanceValues & exMetallbBefore.instanceValues

// The rendered object name DOES change (`metallb-speaker-memberlist` becomes
// `metallb-memberlist`), so the RBAC resourceNames scoping in components.cue
// must move with it — called out in ../06-operational.md as a migration step
// rather than left to be discovered.
_assertMetallbObject: exMetallbAfter.plan.objectName & "metallb-memberlist"
