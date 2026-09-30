// Target schema for enhancement 0013 (Attribute-Declared Secret Fields).
//
// The contract splits cleanly in two, and the split is the design:
//
//	#Secret ................ the FULFILMENT slot. Data. A real CUE type, so CUE
//	                         type-checks it. Filled by the deployer, per
//	                         environment. Two arms: the data, or where it lives.
//
//	@opm(secret, …) ........ the ROUTING. Metadata. Inert. Written by the module
//	                         author, identical in every environment, travelling
//	                         inside the published module.
//
// Each carries what it is good at. The routing moved out of the value — which is
// what kills the double-statement and the discovery pyramid — while the
// disjunction stayed, because it was doing legitimate work that nothing else
// can do: it is the only part of a secret CUE itself can check.
//
// One shape here is NOT a value in any artifact: #SecretMarker. A CUE field
// attribute is metadata attached to a field, not a field of its own, so it
// cannot be typed by unification. #SecretMarker models the *parsed* form, what
// the kernel produces from every `opm` attribute the field carries
// (cue.Value.Attributes, not Attribute: the latter returns only the first), so
// the argument grammar has one written-down contract that the Go parser and
// the docs both answer to. Authors never write #SecretMarker; they write the
// attribute, and examples.cue shows that form on real fields.
//
// Delta manifest against opmodel.dev/core@v2:
//
//	CHANGED   #Secret, #SecretLiteral
//	NEW       #SecretRef (replaces #SecretK8sRef), #SecretKeyType,
//	          #SecretObjectType (named; today an inline set inside #SecretSchema)
//	PARSED    #SecretMarker: the attribute grammar core documents and never evaluates
//	RESTATED  #NameType, #ObjectNameType: copied verbatim from core, unchanged
//	STAND-IN  #FQNType: a simplified local form of core's
//	          #ContractFQNType | #ImplFQNType, only so this file compiles
//	KERNEL    everything else: library behaviour contracts, not core schema
//	REMOVED   listed in spec.md ## Removed definitions
package schema

import (
	"list"
	"regexp"
	"strings"
	"crypto/sha256"
	"encoding/hex"
)

// ─── Types ──────────────────────────────────────────────────────────────────

// #NameType: RFC 1123 DNS label, restated verbatim from core. The 63-rune cap
// is load-bearing here: it is why a composed object name cannot use this type.
#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

// #ObjectNameType: RFC 1123 DNS subdomain, restated verbatim from core
// (0019:D20). What the API server admits for a Secret's metadata.name. Every
// Secret object name in this contract carries it: a deployer-written ref may
// name a dotted object, and a kernel-composed "{instance}-{group}" name runs
// to 63 + 1 + 63 runes before an 11-rune hash suffix, so #NameType overflows
// once instance and group together pass 62 runes.
#ObjectNameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" & strings.MinRunes(1) & strings.MaxRunes(253)

// #FQNType: a primitive's exact match key, as enhancement 0010 D13 fixes it —
// package path plus name plus the full SemVer of the build it came from.
#FQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9-]+@.+$"

// A path segment is spelled the way CUE's own path printer spells it: a bare
// identifier (Unicode letters included, never a leading "_", which CUE prints
// quoted), or a double-quoted label for any key that is not one. A
// deployer-added map key such as `api-token` therefore appears as
// `extraSecrets."api-token"`, which is what cue.Path.String() emits. The string
// is the printed join key; the kernel addresses values by selector, because a
// few degenerate labels (`true`, an empty key) print in forms cue.ParsePath
// refuses.
let _ident = #"[\p{L}$][\p{L}\p{Nd}_$]*"#
let _quoted = #""(?:[^"\\]|\\.)*""#
let _label = "(?:\(_ident)|\(_quoted))"

// #ConfigPathType: a concrete path into a module's #config. The join key of
// the whole design: fulfilment is read at it on the values side, and the kernel
// rewrites the value at it. List indices appear as "[N]" segments. Every path in
// resolution output (resolved, unfulfilled, a plan's members) is concrete.
#ConfigPathType: string & =~"^\(_label)(?:\\[[0-9]+\\])*(?:\\.\(_label)(?:\\[[0-9]+\\])*)*$"

// #ConfigPathPatternType: a declaration path, which discovery reads from the
// schema with no values present. It is a #ConfigPathType that may also carry
// "[_]" segments: any key of a pattern-constrained map, or any element of a
// list. "[_]" is how CUE prints the cue.AnyString and cue.AnyIndex selectors;
// CUE's path printer puts a dot before it (`extra.[_]`), and the contract
// writes it as a suffix like an index (`extra[_]`). A declaration holding "[_]"
// expands to one concrete path per key or element once values exist.
#ConfigPathPatternType: string & =~"^\(_label)(?:\\[(?:[0-9]+|_)\\])*(?:\\.\(_label)(?:\\[(?:[0-9]+|_)\\])*)*$"

// #SecretKeyType: a key inside a Kubernetes Secret's data map. Kubernetes
// admits alphanumerics, '-', '_' and '.', at most 253 runes, never "." and
// never a key starting with "..". Core surface: it types #SecretRef.key.
#SecretKeyType: string & =~"^[-._a-zA-Z0-9]+$" & !~"^\\.$" & !~"^\\.\\." & strings.MaxRunes(253)

// #SecretObjectType: the Kubernetes Secret `type` values OPM materialises.
// Named here so the marker's `type=` argument and a backend catalog's
// materialising transformer read one set. A group's members must agree on it.
//
// Narrower than the inline set in core's deleted #SecretSchema, by two types
// OPM cannot create. kubernetes.io/service-account-token needs annotations the
// API server's token controller binds to a live ServiceAccount, which a
// materialised object does not carry; bootstrap.kubernetes.io/token is only
// read from kube-system. Either can still be consumed through a
// deployer-written #SecretRef, which carries no type at all.
#SecretObjectType: "Opaque" |
	"kubernetes.io/dockercfg" |
	"kubernetes.io/dockerconfigjson" |
	"kubernetes.io/basic-auth" |
	"kubernetes.io/ssh-auth" |
	"kubernetes.io/tls"

// #SecretTypeRequiredKeys: the data keys the API server requires for each
// typed Secret. The default #DeriveKey fold never produces them (a tls member
// at `tls.cert` derives `tls_cert`, not `tls.crt`), so a typed group's members
// set `key=`. basic-auth requires `username` or `password`, which a
// required-key list cannot say; the kernel checks that one directly.
#SecretTypeRequiredKeys: {
	"Opaque": []
	"kubernetes.io/dockercfg": [".dockercfg"]
	"kubernetes.io/dockerconfigjson": [".dockerconfigjson"]
	"kubernetes.io/basic-auth": []
	"kubernetes.io/ssh-auth": ["ssh-privatekey"]
	"kubernetes.io/tls": ["tls.crt", "tls.key"]
}

// ─── The fulfilment contract ────────────────────────────────────────────────

// #Secret: what a module author puts on a sensitive field, and what the
// deployer fills.
//
// The two arms are not two kinds of secret. They are two statements about the
// same secret:
//
//	#SecretLiteral  says WHAT the data is     — the deployer has it in hand
//	#SecretRef      says WHERE the data lives — the cluster already holds it
//
// For a literal, the kernel's whole job is to turn a *what* into a *where*:
// decide which object will hold the data, name that object, and put the data
// there. Once it has, the literal also has a location — so it can be restated
// as a #SecretRef. That restatement is #ResolveInPlace, and it is why both arms
// converge to one shape before anything renders.
//
// Both arms are structs, deliberately. A `string | #SecretRef` form would let
// the deployer write a bare scalar, but the value's KIND would then change
// across resolution for the referenced arm, so a module would only type-check
// with the kernel in the loop. Keeping the kind stable means a module vets
// standalone, in either arm, with or without the kernel — and it means existing
// instance files do not change at all.
#Secret: #SecretLiteral | #SecretRef

// #SecretLiteral: the deployer supplies the data. OPM materialises an object to
// hold it. Note what is absent versus the shape this replaces: no $opm
// discriminator, no $secretName, no $dataKey. Routing is not the value's job.
#SecretLiteral: {
	value!: string
}

// #SecretRef: the data lives in an object that already exists. OPM materialises
// nothing and wires a reference.
//
// This is also the shape the kernel WRITES for a resolved literal, which is the
// whole trick — see #ResolveInPlace.
#SecretRef: {
	// Exact object name. When the deployer writes it, the module does not own
	// the object and the name is never instance-prefixed. When the kernel writes
	// it, this is the group plan's objectName. Typed as an object name, not a DNS
	// label: a pre-existing Secret may be named `tls.example.com`, and the
	// kernel's own composed name can pass 63 runes.
	ref!: #ObjectNameType

	// The key to read inside that object. Need not equal the declared key: the
	// module names its own slot, the cluster names its own.
	key!: #SecretKeyType
}

// ─── The routing marker ─────────────────────────────────────────────────────

// #SecretMarker: the parsed form of `@opm(secret, …)`.
//
// Grammar, as written on a #config field:
//
//	@opm(secret [, group=<name>] [, key=<key>] [, type=<k8s-type>] [, immutable=<bool>] [, description=<text>])
//
// Position 0 is the marker kind. The position-0 form comes from enhancement
// 0010's original identity design, `@opm(identity, owner=publish)`, which was
// later dropped; `secret` is the first live `@opm` marker. One `@opm`
// namespace, dispatched on position 0, keeps OPM to a single attribute name
// across every marker it will ever want.
//
// Every argument past position 0 is optional and derivable. `@opm(secret)` is
// the intended common case; the arguments exist for the minority of secrets that
// must share one Kubernetes object (basic-auth pairs, TLS pairs,
// dockerconfigjson) or must land under a key the consuming workload dictates.
//
// Parse rules. CUE's attribute syntax is lenient, so these are what make a typo
// loud instead of silently routing a secret somewhere else:
//
//   - Every `opm` attribute on the field is read; an attribute whose position 0
//     is another kind is skipped. A field carrying two `secret` markers that
//     disagree (a definition and a use site can each contribute one) is a
//     discovery error; identical markers collapse to one.
//   - An argument name other than group, key, type, immutable or description
//     is an error, and so is a repeated one. `grup=db` fails rather than
//     falling back to the default group.
//   - Every argument is `name=value` with a non-empty value, so a bare
//     `immutable` or an empty `immutable=` is an error. `immutable` takes
//     exactly `true` or `false`.
//   - A value containing `,`, `)` or `"` must be written quoted, as
//     `description="PEM key, rotated yearly"`. Unquoted, the comma would split
//     it into a stray argument, which the unknown-argument rule then rejects.
//
// A list element has no FIELD-attribute slot: `[...#Secret @opm(secret)]` does
// not parse. A `[...#Secret]` list is discovered by its element type with
// default routing (D13). Routing for elements is written as a declaration
// attribute inside an element struct that embeds #Secret,
// `[...{#Secret, @opm(secret, group=tokens)}]`, which keeps the element's
// shape #Secret. The kernel therefore reads `opm` attributes of both kinds
// (cue.FieldAttr and cue.DeclAttr); a declaration attribute is honoured only on
// a struct that embeds #Secret, and is a discovery error anywhere else.
#SecretMarker: {
	// Position 0. Always "secret" for this enhancement; other values in this
	// slot belong to other markers (e.g. "identity") and are not this
	// enhancement's concern.
	kind: "secret"

	// Which Kubernetes Secret object this field's data lands in. Fields sharing a
	// group land in one object; the default puts every secret of an instance that
	// did not ask otherwise into one object per instance.
	group: #NameType | *"secrets"

	// The key inside that object's data map. Defaults to the config path folded
	// into the key charset (#DeriveKey). The fold is readable but lossy, so the
	// kernel rejects two members of one group that land on the same key
	// (#GroupKeysUnique); `key=` is how an author resolves that.
	key?: #SecretKeyType

	// The Kubernetes Secret type. Every member of a group must agree; the kernel
	// rejects a group whose members disagree.
	type: #SecretObjectType | *"Opaque"

	// Whether the object carries a content-hash suffix so a data change rolls
	// dependent workloads. A property of the OBJECT, so every member of a group
	// must agree; the kernel rejects a group whose members disagree.
	immutable: bool | *false

	// Human-readable purpose, surfaced by `opm module inspect`. Inert.
	description?: string
}

// ─── Phase 1: Discover ──────────────────────────────────────────────────────

// #SecretDecl: one marked field, as the kernel's discovery pass produces it.
//
// Discovery walks the module's `#config` schema — NOT the instance's values. A
// CUE attribute belongs to the field that declares it and does not travel
// through a reference or into the vertex supplying the value. Measured, not
// assumed; see ../experiments/01-attribute-propagation.
//
// Because discovery reads the schema, it works with no values present at all,
// which is what lets tooling list a module's required secrets before anyone has
// fulfilled them.
#SecretDecl: {
	// Where the field sits in #config. Unique across a module by construction.
	// A field under a pattern constraint or inside a list element is declared
	// once with a "[_]" segment and expands per key or element at resolution.
	path!: #ConfigPathPatternType

	// The parsed marker, with defaults applied.
	marker!: #SecretMarker

	// `let` captures the field from the enclosing scope. Passing `{path: path}`
	// directly would make the inner `path` a self-reference to the field being
	// declared in that struct literal — the same shadowing trap core documents
	// around its own `let _d = data` helpers.
	let _p = path

	// Resolved key: marker.key when given, derived from the path otherwise. A
	// "[_]" declaration has no concrete path yet, so without `key=` its key is
	// derived per expanded path at resolution, not here.
	key?: #SecretKeyType
	if marker.key != _|_ {
		key: marker.key
	}
	if marker.key == _|_ && !strings.Contains(_p, "[_]") {
		key: (#DeriveKey & {path: _p}).out
	}
}

#SecretDeclList: [...#SecretDecl]

// #DeriveKey: default data key for a concrete config path. Quotes and closing
// brackets are dropped, and every rune outside [-a-zA-Z0-9_] becomes "_": so
// `db.password` gives `db_password`, `list[0]` gives `list_0`,
// `extraSecrets."api-token"` gives `extraSecrets_api-token`, and `$x` gives `_x`.
//
// The fold is readable, not injective: `db.password` and a sibling field named
// `db_password` both give `db_password`. Uniqueness is therefore checked where
// it matters, per group (#GroupKeysUnique), rather than claimed here.
//
// Nor is it total. A path whose fold passes 253 runes (reachable through a long
// deployer-added map key) or folds to nothing (an empty label) has no default
// key. That is an error naming the path, at discovery for a fixed field and at
// resolution for an expanded one, and `key=` is the remedy.
#DeriveKey: {
	path!: #ConfigPathType
	let _bare = strings.Replace(strings.Replace(path, "\"", "", -1), "]", "", -1)
	out: #SecretKeyType & regexp.ReplaceAll("[^-a-zA-Z0-9_]", _bare, "_")
}

// #GroupKeysUnique: no two members of one group share a data key. A
// #SecretGroupPlan's data is a map, so a collision would silently keep one
// secret and drop the other; here it is a unification conflict instead, and
// the kernel reports it naming both paths. Applied to fixed declarations at
// discovery and again to expanded "[_]" paths at resolution, since a
// deployer-added map key can collide with a sibling.
#GroupKeysUnique: {
	#members: [...{group: #NameType, key: #SecretKeyType, path: #ConfigPathType}]

	// group -> key -> the one path allowed to own it.
	out: {for m in #members {(m.group): (m.key): m.path}}
}

// ─── Phase 2: Resolve in place ──────────────────────────────────────────────

// #SecretGroupPlan: one Kubernetes Secret object the kernel will materialise.
//
// Only literals produce a plan. A #SecretRef the deployer wrote produces none —
// the object is not ours to write.
#SecretGroupPlan: {
	// The group name as declared (or defaulted) on the member fields.
	group!: #NameType

	// The object's final name. Computed exactly once, here, by the kernel, and
	// then written into every member's resolved #SecretRef.ref. There is only one
	// string, and it is in the value — so an env reference and a volume reference
	// to the same group cannot disagree. The three divergent name derivations in
	// catalog_opm today become unrepresentable rather than merely fixed.
	objectName!: #ObjectNameType

	// Agreed across every member; the kernel rejects a group that disagrees.
	type:      #SecretObjectType | *"Opaque"
	immutable: bool | *false

	// key -> plaintext. Travels out of band to the materialising component and
	// is never present in the component graph. A typed group must carry the
	// keys its type requires.
	data!: [#SecretKeyType]: string
	for k in #SecretTypeRequiredKeys[type] {
		data: (k)!: string
	}

	// Which config paths fed this group — diagnostics and provenance only.
	// Concrete paths, one per expanded member, and no two share a data key
	// (#GroupKeysUnique).
	members!: [...#ConfigPathType]
}

// #ObjectName: the ONE place an OPM-owned Secret object gets its name.
// Instance-scoped rather than component-scoped: a Kubernetes Secret is a
// namespaced object, so two components of one instance sharing a group must
// reach the same object. Composed from two DNS labels, so it is an object
// name (up to 127 runes, 138 with an immutable suffix), never a #NameType.
#ObjectName: {
	instance!: #NameType
	group!:    #NameType
	out:       #ObjectNameType & "\(instance)-\(group)"
}

// #ContentHash: deterministic 10-character hex digest of a string map, over
// sorted key=value pairs so it is stable under reordering. Same construction
// core uses for ConfigMaps today; it moves to the kernel because after
// resolution no transformer can see the data.
#ContentHash: {
	data: [string]: string

	let _keys = [for k, _ in data {k}]
	let _sorted = list.SortStrings(_keys)
	let _pairs = [for _, k in _sorted {"\(k)=\(data[k])"}]

	out: hex.Encode(sha256.Sum256(strings.Join(_pairs, "\n"))[:5])
}

// #ImmutableObjectName: content-addressed object name. Computed BEFORE the
// rewrite, so a member's resolved #SecretRef.ref already carries the suffix and
// every consumer follows the object automatically when the data changes.
#ImmutableObjectName: {
	base!: #ObjectNameType
	data: [string]: string

	let _d = data
	out: #ObjectNameType & "\(base)-\((#ContentHash & {data: _d}).out)"
}

// #ResolveInPlace: the rewrite that is the heart of this design.
//
// Every marked path in the render-time values is replaced by a #SecretRef —
// whichever arm the deployer wrote. A literal is replaced by a reference to the
// object the kernel has just decided to create; a reference passes through as
// itself. Afterwards nothing downstream can tell the two apart, and nothing
// needs to: a transformer reads `.ref` and `.key` from one branch, with no
// variant dispatch, no prefix test, and no side lookup.
//
// The plaintext does not appear in the output. It leaves through
// #SecretGroupPlan.data, which reaches only the materialising component.
#ResolveInPlace: {
	// Every declared secret, keyed by config path.
	#in: [#ConfigPathType]: #Secret

	// The same paths, every one now in the #SecretRef arm.
	out: [#ConfigPathType]: #SecretRef
}

// ─── The kernel pass, end to end ────────────────────────────────────────────

// #SecretsResolution: the complete output of the kernel's secret handling for
// one instance. Named so the pass has one written-down result rather than
// several loosely-related returns.
#SecretsResolution: {
	// Phase 1 — Discover: read from the module's #config, values not required.
	// A "[_]" declaration expands against the values into the concrete paths
	// the fields below are keyed by.
	declarations!: #SecretDeclList

	// Fixed declarations already carry a key, so their collisions surface at
	// discovery, before any values exist. A "[_]" declaration is checked after
	// expansion; one that sets `key=` collides as soon as it has two entries.
	_fixedKeysUnique: (#GroupKeysUnique & {#members: [
		for d in declarations if d.key != _|_ && !strings.Contains(d.path, "[_]") {group: d.marker.group, key: d.key, path: d.path},
	]}).out

	// Phase 2 — Resolve: what each secret path becomes in the render-time values.
	resolved!: [#ConfigPathType]: #SecretRef

	// Phase 2 — Resolve: the objects OPM will write. Literals only.
	plans!: [...#SecretGroupPlan]

	// Declared but not fulfilled. Non-empty is an error for a render and a report
	// for `opm module inspect`. CUE also catches this on its own: both arms carry
	// required fields, so an unsupplied secret is non-concrete and `cue vet -c`
	// names it by path with no OPM tooling involved.
	unfulfilled!: [...#ConfigPathType]
}

// ─── What the kernel synthesises ────────────────────────────────────────────

// #SynthesizedSecretsComponent: the component the kernel builds to carry the
// plans into the ordinary transformer pipeline.
//
// The resource FQN is an INPUT, supplied from the platform's materialized
// catalogs. It is never a literal here and never a literal in core. That is the
// direct lesson of enhancement 0010 OQ9: a catalog stamps its own version into
// every FQN it publishes, core cannot know that version, and a hardcoded
// constant went stale the moment the catalogs moved to the @v1 line — turning a
// convenience into a hard render failure. Supplying the FQN from the platform is
// 0010 OQ9's candidate (b), and it is natural here because the kernel is already
// the party doing discovery and already holds the platform.
#SynthesizedSecretsComponent: {
	// Resolved from the platform's materialized catalogs at synthesis time.
	#secretsResourceFQN!: #FQNType

	metadata: name: #NameType | *"secrets"

	#resources: (#secretsResourceFQN): _

	spec: secrets: [#NameType]: #MaterializedSecret
}

// #MaterializedSecret: the spec entry a secrets transformer consumes. Plain
// data — discovery, grouping, and naming have all already happened.
#MaterializedSecret: {
	name!:     #ObjectNameType
	type:      #SecretObjectType | *"Opaque"
	immutable: bool | *false
	data!: [#SecretKeyType]: string
}
