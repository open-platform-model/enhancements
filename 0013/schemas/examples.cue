// Worked examples for enhancement 0013.
//
// Every value here compiles and unifies against target.cue, so a wrong example
// is a build failure rather than a documentation bug. Derived values (keys,
// object names, content hashes) are computed by the same definitions the kernel
// implements, and the `_assert*` fields pin the results — change a derivation
// and these stop unifying.
//
// Read order follows one secret's life:
//   1. #ExampleConfig       what the AUTHOR writes (routing, static)
//   2. exDeclarations       what discovery produces, with no values at all
//   3. exValuesDev/Prod     what the DEPLOYER writes (fulfilment, per env),
//                           and the instance's values check
//   4. exPlans              the objects the kernel plans, one input per group
//   5. exResolved           the rewrite: every arm becomes #SecretRef
//   6. exRenderedEnv/Vol    what a transformer emits, one branch for every arm
//   7. exSynthBasicAuth     the component the kernel synthesises
//   8. exGotifyBefore/After migrating a fleet module
//   9. wave 2               named sources, and why widening is additive
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
		host:     string  // unmarked sibling, untouched by any of this
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
		cert: #Secret @opm(secret, group=tls, key="tls.crt", type="kubernetes.io/tls", immutable=true)
		key:  #Secret @opm(secret, group=tls, key="tls.key", type="kubernetes.io/tls", immutable=true, description="PEM private key for the ingress certificate")
	}

	// Depth is not a constraint: discovery is a Go recursion with no unrolled
	// level limit. Twelve levels here purely to make that concrete.
	deeply: nested: a: b: c: d: e: f: g: h: i: {
		token: #Secret @opm(secret, group=deep)
	}

	// A pattern constraint propagates the mark to every key the deployer adds,
	// so a module can offer an open-ended map of secrets without knowing names.
	extraSecrets: {
		[string]: #Secret @opm(secret, group=extra)
	}
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

	// The pattern constraint, declared once with a "[_]" segment for "any
	// key". It has no key yet: each deployer-added key derives its own at
	// resolution.
	{path: "extraSecrets[_]", marker: {kind: "secret", group: "extra"}},
]

// Key derivation, pinned. `db.password` asked for nothing, so its key comes out
// of the full path, which is why db.password and a hypothetical redis.password
// land on different keys.
_assertDerivedKey: exDeclarations[0].key & "db_password"
_assertDeepKey:    exDeclarations[5].key & "deeply_nested_a_b_c_d_e_f_g_h_i_token"
_assertGivenKey:   exDeclarations[3].key & "tls.crt"
_assertPatternKey: exDeclarations[6].key == _|_ & true

// The fold covers every path CUE can print: a quoted map key keeps its hyphen,
// a list index becomes a segment, and `$` (legal in a CUE identifier, not in a
// Secret key) folds to "_".
_assertQuotedKey: (#DeriveKey & {path: "extraSecrets.\"api-token\""}).out & "extraSecrets_api-token"
_assertIndexKey: (#DeriveKey & {path: "users[0].password"}).out & "users_0_password"
_assertDollarKey: (#DeriveKey & {path: "$legacy.token"}).out & "_legacy_token"

// The fold is lossy: a sibling field literally named `db_password` derives the
// same key as `db.password`. Pinned so nobody reintroduces a "collision-free"
// claim; #GroupKeysUnique is what turns such a pair into an error.
_assertFoldIsLossy: (#DeriveKey & {path: "db.password"}).out & (#DeriveKey & {path: "db_password"}).out

// Every fixed declaration of #ExampleConfig owns its group key. Adding
// `db_password: #Secret @opm(secret)` beside `db` would make this conflict.
_assertKeysUnique: (#GroupKeysUnique & {#members: [
	for d in exDeclarations if d.key != _|_ {group: d.marker.group, key: d.key, path: d.path},
]}).out

// ─── 3. Fulfilment — the deployer's half ────────────────────────────────────

// The SAME published module, two environments, differing only in which arm each
// secret is filled with. This is what OQ1 was about, and why the choice had to
// live in the type rather than in the attribute: neither of these requires
// republishing the module.

// exValuesDev: everything supplied inline. Dev has no managed certificate.
exValuesDev: [string]: #Secret
exValuesDev: {
	"db.password": {value: "hunter2"}
	"auth.username": {value: "admin"}
	"auth.password": {value: "s3cr3t"}
	"tls.cert": {value: "-----BEGIN CERTIFICATE-----\nDEV\n-----END CERTIFICATE-----"}
	"tls.key": {value: "-----BEGIN PRIVATE KEY-----\nDEV\n-----END PRIVATE KEY-----"}
	"deeply.nested.a.b.c.d.e.f.g.h.i.token": {value: "tok-123"}
}

// exValuesProd: the TLS pair points at a wildcard certificate the platform team
// manages. OPM will not create or own that object.
exValuesProd: [string]: #Secret
exValuesProd: {
	"db.password": {value: "hunter2"}
	"auth.username": {value: "admin"}
	"auth.password": {value: "s3cr3t"}
	"tls.cert": {ref: "wildcard-example-com", key: "tls.crt"}
	"tls.key": {ref: "wildcard-example-com", key: "tls.key"}
	"deeply.nested.a.b.c.d.e.f.g.h.i.token": {value: "tok-123"}

	// A key the deployer added under the pattern map. Not an identifier, so
	// its path carries the quoted label CUE prints for it.
	"extraSecrets.\"api-token\"": {value: "tok-456"}
}

// The instance's values check (D34). The check sits beside `values`, so the
// exported values are exactly what the deployer wrote: the #config default for
// `replicas` is checked against, never added.
exInstanceCheck: #ModuleInstanceValuesCheck & {
	#module: #config: {
		db: password: #Secret
		replicas: int | *1
	}
	values: db: password: value: "hunter2"
}

_assertNoDefaultLeak: (exInstanceCheck.values.replicas == _|_) & true

// Every arm carries core's hidden tag, which is how the kernel knows a
// resolved value is a core secret (D33). Hidden, so it never reaches JSON.
_assertLiteralTagged: (#SecretLiteral & {value: "x"})._opmSecret & "v2"

// ─── 4. Resolution: the objects the kernel plans ────────────────────────────

// The literal source's contract FQN. Illustrative: the kernel takes whatever
// FQN the platform's one `literal`-annotated contract carries (D30), and never
// assumes a catalog path.
let _literalFQN = "opmodel.dev/catalogs/opm/resources/literal-secret@v1alpha1"

// A sketch of the literal source's resource schema, as catalog_opm would
// define it (D22): the core envelope, with no settings and one `value` per
// entry. Every literal plan below must fit it.
#ExampleLiteralSourceSpec: #SecretSourceInput & {
	settings: close({})
	entries: [_]: close({value!: string})
}

// exPlans: for instance "myapp" in the PROD values. The `tls` group produces no
// plan: those two secrets are references, so the object is not ours to write.
exPlans: [...#SecretGroupPlan] & [
	{
		group:  "secrets"
		source: _literalFQN
		input: {
			target: name: (#ObjectName & {instance: "myapp", group: "secrets"}).out
			settings: {}
			entries: db_password: value: "hunter2"
		}
		members: ["db.password"]
	},
	{
		group:  "basic-auth"
		source: _literalFQN
		input: {
			target: {
				name: (#ObjectName & {instance: "myapp", group: "basic-auth"}).out
				type: "kubernetes.io/basic-auth"
			}
			settings: {}
			entries: {
				username: value: "admin"
				password: value: "s3cr3t"
			}
		}
		members: ["auth.username", "auth.password"]
	},
	{
		group:  "deep"
		source: _literalFQN
		input: {
			target: name: (#ObjectName & {instance: "myapp", group: "deep"}).out
			settings: {}
			entries: deeply_nested_a_b_c_d_e_f_g_h_i_token: value: "tok-123"
		}
		members: ["deeply.nested.a.b.c.d.e.f.g.h.i.token"]
	},
	{
		group:  "extra"
		source: _literalFQN
		input: {
			target: name: (#ObjectName & {instance: "myapp", group: "extra"}).out
			settings: {}
			entries: "extraSecrets_api-token": value: "tok-456"
		}
		members: ["extraSecrets.\"api-token\""]
	},
]

_assertObjectName: exPlans[1].input.target.name & "myapp-basic-auth"

// Every literal plan fits the literal source's own schema.
_assertLiteralPlansFit: [for p in exPlans {#ExampleLiteralSourceSpec & p.input}]

// A composed name is an object name, not a DNS label. A 40-rune instance
// with a 25-rune group is 66 runes: legal for a Secret, and over #NameType's
// 63-rune cap, which is why the target name and #SecretRef.ref carry
// #ObjectNameType.
exLongObjectName: (#ObjectName & {
	instance: "payments-reconciliation-service-eu-west1"
	group:    "database-credentials-main"
}).out
_assertLongNameOverLabelCap: len(exLongObjectName) & >63

// An immutable group in the DEV values, where the TLS pair IS supplied. The
// hash is computed over the input before the rewrite, so members' `ref`
// already carries it and every consumer follows the object when the
// certificate rotates. A kubernetes.io/tls target must carry both tls.crt and
// tls.key, which the envelope enforces.
exImmutablePlan: #SecretGroupPlan & {
	group:  "tls"
	source: _literalFQN
	input: {
		target: {
			name: (#ImmutableObjectName & {base: "myapp-tls", entries: exImmutablePlan.input.entries, settings: exImmutablePlan.input.settings}).out
			type:      "kubernetes.io/tls"
			immutable: true
		}
		settings: {}
		entries: {
			"tls.crt": value: "-----BEGIN CERTIFICATE-----\nDEV\n-----END CERTIFICATE-----"
			"tls.key": value: "-----BEGIN PRIVATE KEY-----\nDEV\n-----END PRIVATE KEY-----"
		}
	}
	members: ["tls.cert", "tls.key"]
}

_assertImmutableName: exImmutablePlan.input.target.name & "myapp-tls-c9261478b2"

// ─── 5. Resolve in place: every arm converges ───────────────────────────────

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
	"tls.key": {ref: "wildcard-example-com", key: "tls.key"}

	"deeply.nested.a.b.c.d.e.f.g.h.i.token": {ref: "myapp-deep", key: "deeply_nested_a_b_c_d_e_f_g_h_i_token"}

	"extraSecrets.\"api-token\"": {ref: "myapp-extra", key: "extraSecrets_api-token"}
}

// The kernel writes tagged references, so a resolved value is still a core
// secret at render (D33).
_assertResolvedTagged: exResolvedProd["db.password"]._opmSecret & "v2"

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

// The author wires the field into an env var or a volume (`from:
// #config.db.password`, the env-from-secret path the catalog restores). By
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

// A deployer may point at any Secret the API server admits, dotted names
// included, which a DNS-label type would have refused.
exDottedRef: #SecretRef & {ref: "tls.wildcard.example.com", key: "tls.crt"}

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

// ─── 7. What the kernel synthesises ─────────────────────────────────────────

// exSynthBasicAuth: the component the kernel adds to the render for the
// basic-auth group. Its key cannot be written by an author; its spec is the
// plan's input under the literal source's spec key; its target name is the
// very string both consumers above read.
exSynthBasicAuth: #SynthesizedSecretComponent & {
	#plan:    exPlans[1]
	#specKey: "literalSecret"
}

_assertSynthKey:    exSynthBasicAuth.key & "opm.secrets.basic-auth"
_assertSynthName:   exSynthBasicAuth.component.metadata.name & "opm-secrets-basic-auth"
_assertSynthLabel:  exSynthBasicAuth.component.metadata.labels."component.opmodel.dev/name" & "opm-secrets-basic-auth"
_assertSynthTarget: exSynthBasicAuth.component.spec.literalSecret.target.name & exResolvedProd["auth.username"].ref

// ─── 8. Migrating a fleet module ────────────────────────────────────────────

// modules/gotify today: while core had no usable #Secret, the fleet stripped
// the legacy vocabulary and types its sensitive fields as plain strings, wired
// into the workload as a plain env value. The plaintext therefore lands in the
// rendered Deployment.
exGotifyBefore: {
	// A definition, since a schema is not a concrete value.
	#moduleCue: config: defaultUser: password:          string
	componentsCue: env: GOTIFY_DEFAULTUSER_PASS: value: instanceValues.defaultUser.password
	instanceValues: defaultUser: password: "debug-admin-password"
}

// exGotifyAfter: the field becomes a #Secret, the env var reads the reference,
// and the instance value moves into the literal arm. Instance files DO change
// for this fleet: a bare string becomes `{value: …}`.
exGotifyAfter: {
	moduleCue: {
		// Written in the module as:
		//   defaultUser: password: #Secret @opm(secret, group=admin, key=password)
		declaration: #SecretDecl & {
			path: "defaultUser.password"
			marker: {kind: "secret", group: "admin", key: "password"}
		}
	}

	instanceValues: defaultUser: password: #Secret & {value: "debug-admin-password"}

	plan: #SecretGroupPlan & {
		group:  "admin"
		source: _literalFQN
		input: {
			target: name: (#ObjectName & {instance: "gotify", group: "admin"}).out
			settings: {}
			entries: password: value: instanceValues.defaultUser.password.value
		}
		members: ["defaultUser.password"]
	}

	resolved: "defaultUser.password": #SecretRef & {
		ref: plan.input.target.name
		key: "password"
	}

	// The rendered Deployment now carries a reference, not the password.
	renderedEnv: GOTIFY_DEFAULTUSER_PASS: valueFrom: secretKeyRef: {
		name: resolved["defaultUser.password"].ref
		key:  resolved["defaultUser.password"].key
	}
}

_assertGotifyValueMoves:  exGotifyAfter.instanceValues.defaultUser.password.value & exGotifyBefore.instanceValues.defaultUser.password
_assertGotifyNoPlaintext: exGotifyAfter.renderedEnv.GOTIFY_DEFAULTUSER_PASS.valueFrom.secretKeyRef.name & "gotify-admin"

// ─── 9. Wave 2: named sources ───────────────────────────────────────────────

// #SecretWave2: #Secret as wave 2 widens it.
#SecretWave2: #SecretLiteral | #SecretRef | #SecretSource

// Widening is additive: every wave-1 value is still a valid wave-2 value.
_assertWave1StillValid: {for p, v in exValuesProd {(p): #SecretWave2 & v}}

// An external-store source, as a third-party catalog would define it: its own
// settings (which store) and its own entry schema (where in the store).
let _esoFQN = "example.com/catalogs/eso/resources/external-secret@v1alpha1"

#ExampleExternalSourceSpec: #SecretSourceInput & {
	// The deployer may name another store; the platform supplies the default
	// through its catalog entry (D32), so the spec is complete without it.
	settings: close({store?: string})
	entries: [_]: close({key!: string, property?: string})
}

// exValuesProdWave2: the same module on the same platform, prod now reading
// the basic-auth pair from an external store. dev keeps its literals.
exValuesProdWave2: [string]: #SecretWave2
exValuesProdWave2: {
	for p, v in exValuesProd if p != "auth.username" && p != "auth.password" {(p): v}
	"auth.username": {source: _esoFQN, settings: store: "vault-prod", spec: {key: "prod/auth", property: "username"}}
	"auth.password": {source: _esoFQN, settings: store: "vault-prod", spec: {key: "prod/auth", property: "password"}}
}

// Both members of the group name the same source with the same settings.
_assertGroupAgrees: (#GroupSourcesAgree & {#members: [
	for p in ["auth.username", "auth.password"] {
		group:  "basic-auth"
		source: exValuesProdWave2[p].source
		settings: [if exValuesProdWave2[p].settings != _|_ {exValuesProdWave2[p].settings}, {}][0]
		path: p
	},
]}).out

// The plan: one input, one settings block, one entry per member's spec. The
// object name is the same as the literal plan's, so consumers do not change.
exExternalPlan: #SecretGroupPlan & {
	group:  "basic-auth"
	source: _esoFQN
	input: {
		target: {
			name: (#ObjectName & {instance: "myapp", group: "basic-auth"}).out
			type: "kubernetes.io/basic-auth"
		}
		settings: exValuesProdWave2["auth.username"].settings
		entries: {
			username: exValuesProdWave2["auth.username"].spec
			password: exValuesProdWave2["auth.password"].spec
		}
	}
	members: ["auth.username", "auth.password"]
}

_assertExternalFits:     #ExampleExternalSourceSpec & exExternalPlan.input
_assertExternalSameName: exExternalPlan.input.target.name & exPlans[1].input.target.name

// A plan that relies on the platform's store fits the source's schema.
_assertExternalPlatformDefault: #ExampleExternalSourceSpec & {
	target: name: "myapp-basic-auth"
	settings: {}
	entries: username: key: "prod/auth"
}

// Reordering a named source's fields changes neither the group verdict nor the
// immutable name.
_assertOrderFreeAgreement: (#GroupSourcesAgree & {#members: [
	{group: "g", source: _esoFQN, settings: {store: "s", role: "r"}, path: "a"},
	{group: "g", source: _esoFQN, settings: {role: "r", store: "s"}, path: "b"},
]}).out
_assertOrderFreeHash: (#ImmutableObjectName & {base: "x", settings: {}, entries: k: {key: "prod/auth", property: "username"}}).out &
	(#ImmutableObjectName & {base: "x", settings: {}, entries: k: {property: "username", key: "prod/auth"}}).out
