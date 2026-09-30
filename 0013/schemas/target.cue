// Target schema for enhancement 0013 (Attribute-Declared Secret Fields).
//
// The contract splits cleanly in two, and the split is the design:
//
//	#Secret ................ the FULFILMENT slot. Data. A real CUE type, so CUE
//	                         type-checks it. Filled by the deployer, per
//	                         environment: the data, where it already lives, or
//	                         (wave 2) which secret source produces it.
//
//	@opm(secret, …) ........ the ROUTING. Metadata. Inert. Written by the module
//	                         author, identical in every environment, travelling
//	                         inside the published module.
//
// Secret METHODS are not core's business. A method is a secret source: a
// #Resource a catalog defines, annotated opmodel.dev/secret-source, fulfilled
// by the catalog's transformer, and fed through one core envelope,
// #SecretSourceInput (D18, D19). Core adds the arms and the envelope once and
// never grows with new methods.
//
// Delivery runs in two waves (06-operational.md). This file is the full target
// and marks the wave-2 surface as such; everything unmarked ships in wave 1.
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
//	CHANGED   #Secret, #SecretLiteral (each arm gains core's hidden tag, D33)
//	CHANGED   #ModuleInstance: gains the hidden values check (D34); shown here
//	          as #ModuleInstanceValuesCheck, the rest of it unchanged
//	NEW       #SecretRef (replaces #SecretK8sRef), #SecretSourceInput,
//	          #SecretKeyType, #SecretObjectType, #SecretTypeRequiredKeys
//	NEW (w2)  #SecretSource, added to #Secret's disjunction in wave 2
//	PARSED    #SecretMarker: the attribute grammar core documents and never evaluates
//	SPEC      the reserved opmodel.dev/ annotation prefix (D20); SPEC.md §1 and
//	          §3.5 secret text (see spec.md); no schema change
//	SPEC (w2) a catalog entry's #transformers may carry a source's settings
//	          fill (D32); no schema change
//	RESTATED  #NameType, #ObjectNameType, #ContractFQNType, #ContentHash:
//	          copied verbatim from core, unchanged
//	KERNEL    everything else: library behaviour contracts, not core schema
//	REMOVED   listed in spec.md ## Removed definitions
package schema

import (
	"encoding/json"
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

// #ContractFQNType: a contract FQN, restated verbatim from core: package path,
// name and apiVersion, what a module demands and what a deployer names a
// secret source by (D29). A catalog release does not move it.
#ContractFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+((alpha|beta)[0-9]+)?$"

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
// Named here so the marker's `type=` argument and every secret source, through
// #SecretSourceInput.target.type, read one set. A group's members must agree
// on it.
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
// The arms are not kinds of secret. They are statements about the same secret:
//
//	#SecretLiteral  says WHAT the data is: the deployer has it in hand
//	#SecretRef      says WHERE the data lives: the cluster already holds it
//	#SecretSource   says WHICH source produces it, and from what (wave 2)
//
// For every arm but the reference, the kernel's job is to turn a *what* into a
// *where*: decide which object will hold the data, name it, and have a source
// produce it. Once it has, the value also has a location, so it can be restated
// as a #SecretRef. That restatement is #ResolveInPlace, and it is why every arm
// converges to one shape before anything renders.
//
// Every arm is a struct, deliberately. A `string | #SecretRef` form would let
// the deployer write a bare scalar, but the value's KIND would then change
// across resolution, so a module would only type-check with the kernel in the
// loop. Keeping the kind stable means a module vets standalone, in any arm.
//
// Wave 1 ships the two arms below. Wave 2 widens the disjunction to
// `#SecretLiteral | #SecretRef | #SecretSource`; widening breaks no module and
// no transformer, since modules type the field as #Secret and transformers only
// ever see the rewritten #SecretRef.
#Secret: #SecretLiteral | #SecretRef

// _opmSecret: core's hidden tag, carried by every arm (D33). A field is a
// secret when the schema declares it and its resolved value carries this tag.
// Hidden, so it never appears in JSON, in a decoded value, or in anything the
// kernel exports; package-scoped, so only core can author it: a structure that
// merely looks like a secret, or a tag written in another package, is never
// one. The value names the core line, which tells this shape apart from the
// earlier release's #Secret published under the same name.

// #SecretLiteral: the deployer supplies the data. It is sugar for the platform's
// literal source (D30): the kernel resolves it to the one contract annotated
// `opmodel.dev/secret-source: literal`, which materialises a plain Secret. Note
// what is absent versus the shape this replaces: no $opm discriminator, no
// $secretName, no $dataKey. Routing is not the value's job.
#SecretLiteral: {
	_opmSecret: "v2"
	value!:     string
}

// #SecretRef: the data lives in an object that already exists. OPM materialises
// nothing and wires a reference.
//
// This is also the shape the kernel WRITES for every resolved value, which is
// the whole trick: see #ResolveInPlace.
#SecretRef: {
	_opmSecret: "v2"

	// Exact object name. When the deployer writes it, the module does not own
	// the object and the name is never instance-prefixed. When the kernel writes
	// it, this is the group plan's object name. Typed as an object name, not a DNS
	// label: a pre-existing Secret may be named `tls.example.com`, and the
	// kernel's own composed name can pass 63 runes.
	ref!: #ObjectNameType

	// The key to read inside that object. Need not equal the declared key: the
	// module names its own slot, the cluster names its own.
	key!: #SecretKeyType
}

// #SecretSource (WAVE 2): the deployer names a secret source and gives it what
// it needs. Not part of #Secret until wave 2.
#SecretSource: {
	_opmSecret: "v2"

	// The source's exact contract FQN, apiVersion included, the way a component
	// names a resource (D29). Nothing resolves a short name or picks a version.
	// A values file written in CUE can take it from the catalog's definition by
	// import.
	source!: #ContractFQNType

	// How the group's one object is produced: a store, a role, a mount. Typed by
	// the source's resource schema, which admits only the settings a deployer
	// may set; the platform's settings fill the rest (D31, D32). Every
	// non-reference member of a group must carry the same source and settings.
	settings?: {...}

	// This key's own data: a remote key, a ciphertext. Typed by the source's
	// resource schema as one entry of #SecretSourceInput.entries.
	spec?: {...}
}

// #SecretSourceInput: what the kernel hands every secret source, once per
// group (D18, D31). Ships in wave 1 in this final shape, so the literal source
// is written against the envelope wave 2 uses and nothing here grows later. A
// source's resource schema is `#SecretSourceInput & {settings: <its settings>,
// entries: [_]: <its entry schema>}`; a schema that does not accept this
// envelope fails to vet in its own catalog.
#SecretSourceInput: {
	// The one Kubernetes Secret the source must end up producing, directly (a
	// plain Secret) or through its own controller (an ExternalSecret, a
	// SealedSecret). Every consumer's #SecretRef points at target.name.
	target!: {
		name!:     #ObjectNameType
		type:      #SecretObjectType | *"Opaque"
		immutable: bool | *false
	}

	// The group's settings, as the deployer wrote them. Empty for the literal
	// source. Complete by construction: the source's schema holds only
	// deployer-settable settings, each optional or defaulted (D31).
	settings: {...}

	// Data key -> that member's source data. For the literal source an entry is
	// `{value: "…"}`; for a named source it is the member's spec.
	entries!: [#SecretKeyType]: _

	// A typed Secret must carry the keys the API server requires for its type,
	// whichever source produces it.
	for k in #SecretTypeRequiredKeys[target.type] {
		entries: (k)!: _
	}
}

// #SecretSourceAnnotation: the primitive annotation that marks a #Resource as
// a secret source (D20, D29). The key sits under the `opmodel.dev/` prefix
// core's specification reserves for keys the kernel interprets. Its value is a
// role, not a name: `source` for a named source, `literal` for the one source
// a platform may carry to serve #SecretLiteral (D30). The `source` role is used
// from wave 2; wave 1 reads only `literal`.
#SecretSourceAnnotation: {
	key:   "opmodel.dev/secret-source"
	value: "source" | "literal"
}

// ─── The instance's values check ────────────────────────────────────────────

// #ModuleInstanceValuesCheck: the one field core's #ModuleInstance gains (D34),
// shown on a minimal stand-in; the rest of #ModuleInstance is unchanged.
//
// The check unifies the values with the module's #config BESIDE `values`, never
// into it, so the instance's exported values stay exactly what the deployer
// wrote: no #config default is added. Plain `cue vet -c` then rejects a value
// carrying two arms, a bare string at a secret path, an unknown field or a
// wrong type, whether or not a component reads it. Two things it cannot do,
// both left to the kernel: CUE never checks completeness under a hidden field,
// so an unfulfilled secret no component reads passes plain vet; and a
// hand-written instance that does not embed #ModuleInstance carries no check
// at all. The kernel checks every declared secret path for completeness on
// every entry path, independent of this field, and reports a failure here at
// the matching `values` path, redacted.
#ModuleInstanceValuesCheck: {
	#module: #config: _
	values:       _
	_valuesCheck: #module.#config & values
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
	// slot belong to other markers and are not this enhancement's concern.
	kind: "secret"

	// Which Kubernetes Secret object this field's data lands in. Fields sharing a
	// group land in one object; the default puts every secret of an instance that
	// did not ask otherwise into one object per instance. At most 51 runes, so
	// the synthesised component's name `opm-secrets-<group>` stays a #NameType;
	// discovery refuses a longer group from the module alone, in every
	// environment, rather than at render in only some of them.
	group: #NameType & strings.MaxRunes(51) | *"secrets"

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

	// Human-readable purpose, surfaced by inspection tooling. Inert.
	description?: string
}

// ─── Discover ───────────────────────────────────────────────────────────────

// #SecretDecl: one declared secret, as the kernel's discovery pass produces it.
//
// The schema declares (D3, D33). Discovery walks the module's #config schema,
// following disjunctions, embeddings, aliases, patterns and lists to core's
// tagged arms; a field reached that way is a declaration, whether or not it
// carries a marker (D13). Values declare nothing: a secret-shaped value at a
// field the schema does not declare is ignored.
//
// It walks twice. With no values present it lists every declaration it can
// reach, for templates and inspection; a declaration under a condition on a
// deployer value only appears once values select it. At render it walks the
// schema with the values unified, so conditions resolve and "[_]" declarations
// expand, and every declared path's resolved value must carry core's tag: a
// plain default left unset, or the earlier core release's shape, is refused.
#SecretDecl: {
	// Where the field sits in #config. Unique across a module by construction.
	// A field under a pattern constraint or inside a list element is declared
	// once with a "[_]" segment and expands per key or element at render.
	path!: #ConfigPathPatternType

	// The parsed marker, with defaults applied. All defaults when the field is
	// secret-typed but unmarked (D13).
	marker!: #SecretMarker

	// `let` captures the field from the enclosing scope. Passing `{path: path}`
	// directly would make the inner `path` a self-reference to the field being
	// declared in that struct literal, the same shadowing trap core documents
	// around its own `let _d = data` helpers.
	let _p = path

	// Resolved key: marker.key when given, derived from the path otherwise. A
	// "[_]" declaration has no concrete path yet, so without `key=` its key is
	// derived per expanded path at render, not here.
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
// render for an expanded one, and `key=` is the remedy.
#DeriveKey: {
	path!: #ConfigPathType
	let _bare = strings.Replace(strings.Replace(path, "\"", "", -1), "]", "", -1)
	out: #SecretKeyType & regexp.ReplaceAll("[^-a-zA-Z0-9_]", _bare, "_")
}

// #GroupKeysUnique: no two members of one group share a data key. A group's
// entries are a map, so a collision would silently keep one secret and drop the
// other; here it is a unification conflict instead, and the kernel reports it
// naming both paths. Applied to fixed declarations at discovery and again to
// expanded "[_]" paths at render, since a deployer-added map key can collide
// with a sibling.
#GroupKeysUnique: {
	#members: [...{group: #NameType, key: #SecretKeyType, path: #ConfigPathType}]

	// group -> key -> the one path allowed to own it.
	out: {for m in #members {(m.group): (m.key): m.path}}
}

// #GroupSourcesAgree (WAVE 2): every non-reference member of a group names the
// same source with the same settings, since one object has one producer (D19,
// D31). A literal member counts as naming the literal source with empty
// settings (D30), and a member written with no settings block counts as
// `settings: {}`. Members are compared as values, so field order and a
// setting written out at its default do not count as a difference. A
// disagreement is a unification conflict naming the group and both paths.
#GroupSourcesAgree: {
	#members: [...{group: #NameType, source: #ContractFQNType, settings: {...}, path: #ConfigPathType}]

	// group -> first path -> second path -> whether the pair agrees, which must
	// be true.
	out: {
		for i, m in #members for j, n in #members if j > i && m.group == n.group {
			(m.group): "\(m.path)": "\(n.path)": (m.source == n.source && m.settings == n.settings) & true
		}
	}
}

// ─── Resolve in place ───────────────────────────────────────────────────────

// #SecretGroupPlan: one group's object, as the kernel plans it. Only
// non-reference members produce a plan: a #SecretRef the deployer wrote names
// an object that is not ours to produce.
#SecretGroupPlan: {
	// The group name as declared (or defaulted) on the member fields.
	group!: #NameType & strings.MaxRunes(51)

	// The chosen source's exact contract FQN: the one annotated `literal` for
	// literal members (D30), the named one for #SecretSource members (wave 2).
	source!: #ContractFQNType

	// What the source receives. input.target.name is the object's final name,
	// computed exactly once, by the kernel, and then written into every member's
	// resolved #SecretRef.ref. There is only one string, and it is in the value,
	// so an env reference and a volume reference to the same group cannot
	// disagree. The divergent name derivations the catalog carried become
	// unrepresentable rather than merely fixed.
	input!: #SecretSourceInput

	// Which config paths fed this group: diagnostics and provenance only.
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
// sorted key=value pairs so it is stable under reordering. Restated verbatim
// from core, which keeps it. What moves to the kernel is content-hash naming
// of Secret objects (#InputHash, #ImmutableObjectName), because after
// resolution no transformer can see the data.
#ContentHash: {
	data: [string]: string

	let _keys = [for k, _ in data {k}]
	let _sorted = list.SortStrings(_keys)
	let _pairs = [for _, k in _sorted {"\(k)=\(data[k])"}]

	out: hex.Encode(sha256.Sum256(strings.Join(_pairs, "\n"))[:5])
}

// #InputHash: the content hash of what a source receives, over each entry and
// the settings in canonical JSON: object keys sorted at every level (RFC 8785),
// so reordering a spec's or the settings' fields never renames the object or
// makes two frontends disagree. The settings sit under the empty key, which no
// entry can use. For the literal source this hashes the supplied values; for a
// named source it hashes what the deployer wrote (a remote key, a ciphertext),
// not the remote data, whose rotation stays the source's job. The model sorts
// the top level of each entry and of the settings, which is all the examples
// need; the kernel sorts every level.
#InputHash: {
	entries: [string]: _
	settings: {...}

	let _e = entries
	let _s = settings
	out: (#ContentHash & {data: {
		for k, e in _e {(k): (#CanonicalJSON & {in: e}).out}
		"": (#CanonicalJSON & {in: _s}).out
	}}).out
}

// #CanonicalJSON: a struct as JSON with its top-level keys sorted. A model of
// the kernel's canonical encoding, which sorts every level.
#CanonicalJSON: {
	in: {...}
	let _i = in
	out: json.Marshal({for k in list.SortStrings([for k, _ in _i {k}]) {(k): _i[k]}})
}

// #ImmutableObjectName: content-addressed object name. Computed BEFORE the
// rewrite, so a member's resolved #SecretRef.ref already carries the suffix and
// every consumer follows the object automatically when the input changes.
#ImmutableObjectName: {
	base!: #ObjectNameType
	entries: [string]: _
	settings: {...}

	let _e = entries
	let _s = settings
	out: #ObjectNameType & "\(base)-\((#InputHash & {entries: _e, settings: _s}).out)"
}

// #ResolveInPlace: the rewrite that is the heart of this design.
//
// Every declared path in the render-time values is replaced by a #SecretRef,
// whichever arm the deployer wrote. A literal (or, in wave 2, a named source)
// is replaced by a reference to the object the kernel has just planned; a
// reference passes through as itself. Afterwards nothing downstream can tell
// them apart, and nothing needs to: a transformer reads `.ref` and `.key` from
// one branch, with no variant dispatch and no side lookup.
//
// The plaintext does not appear in the output. It leaves through the group
// plan's input, which reaches only the synthesised component.
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
	// Discover: read from the module's #config schema. A "[_]" declaration
	// expands against the values into the concrete paths the fields below are
	// keyed by.
	declarations!: #SecretDeclList

	// Fixed declarations already carry a key, so their collisions surface at
	// discovery, before any values exist. A "[_]" declaration is checked after
	// expansion; one that sets `key=` collides as soon as it has two entries.
	_fixedKeysUnique: (#GroupKeysUnique & {#members: [
		for d in declarations if d.key != _|_ && !strings.Contains(d.path, "[_]") {group: d.marker.group, key: d.key, path: d.path},
	]}).out

	// Resolve: what each secret path becomes in the render-time values.
	resolved!: [#ConfigPathType]: #SecretRef

	// Resolve: the objects the platform's sources will produce, one per group
	// with a non-reference member.
	plans!: [...#SecretGroupPlan]

	// Declared but not fulfilled. Non-empty fails every render and every kernel
	// validation, whether or not a component reads the path (D34). Plain `cue
	// vet -c` reports it only when a component reads the path; one no component
	// reads passes, because CUE does not check completeness under a hidden field.
	unfulfilled!: [...#ConfigPathType]
}

// ─── What the kernel synthesises ────────────────────────────────────────────

// #SynthesizedSecretComponent: the component the kernel builds for one group,
// carrying the chosen source's contract into the ordinary transformer pipeline.
// It enters the render build through the library's render glue, served from
// memory, never through the instance's components, and is held to what an
// authored component is (D35). Its contract is reported among the render's
// required contracts (D24). It exists only inside the render build: its spec,
// which carries the plaintext for the literal source, is never a regular
// readable field of that build, and every diagnostic at its path is redacted
// as at a declared path (D36). This model shows its shape, not something any
// frontend exports.
#SynthesizedSecretComponent: {
	#plan!: #SecretGroupPlan

	// The source resource's spec key, which core derives from the resource's own
	// name (a resource named "literal-secret" exposes spec.literalSecret). Read
	// from the contract the platform defines, never assumed.
	#specKey!: string

	// The components-map key: outside the keys an author can declare, so it can
	// never merge with an author component (D23). A dot is not valid in a
	// #NameType. Emitted as a quoted label, never a hidden identifier.
	key: "opm.secrets.\(#plan.group)" & !~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

	component: {
		// An ordinary identity name. The kernel refuses a render in which it
		// equals an authored component's name, since only the keys are disjoint.
		metadata: {
			name: #NameType & "opm-secrets-\(#plan.group)"

			// Stamped by the kernel: core stamps it only for components declared
			// through #Module, and inventories record the component from it.
			labels: "component.opmodel.dev/name": name
		}

		// The contract, taken from the platform's defined contracts by the plan's
		// exact FQN.
		#resources: (#plan.source): _

		// The source's input. Validated for completeness before matching, as an
		// authored component's spec is at acquisition, with a failure reported at
		// the member's values path (D35).
		spec: (#specKey): #plan.input
	}
}
