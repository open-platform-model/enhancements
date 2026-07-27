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
// cannot be typed by unification. #SecretMarker models the *parsed* form — what
// the kernel produces after calling cue.Value.Attribute("opm") — so the
// argument grammar has one written-down contract that the Go parser and the docs
// both answer to. Authors never write #SecretMarker; they write the attribute,
// and examples.cue shows that form on real fields.
package schema

import (
	"list"
	"strings"
	"crypto/sha256"
	"encoding/hex"
)

// ─── Types ──────────────────────────────────────────────────────────────────

// #NameType: kebab-case DNS-safe name, as core declares it today.
#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

// #FQNType: a primitive's exact match key, as enhancement 0010 D13 fixes it —
// package path plus name plus the full SemVer of the build it came from.
#FQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9-]+@.+$"

// #ConfigPathType: a dotted path into a module's #config. The join key of the
// whole design: discovery produces it from the schema side, fulfilment is read
// at it on the values side, and the kernel rewrites the value at it. List
// indices appear as "[N]" segments.
#ConfigPathType: string & =~#"^[a-zA-Z_$][a-zA-Z0-9_$]*(\[[0-9]+\])*(\.[a-zA-Z_$][a-zA-Z0-9_$]*(\[[0-9]+\])*)*$"#

// #SecretKeyType: a key inside a Kubernetes Secret's data map. K8s permits
// alphanumerics, '-', '_' and '.'.
#SecretKeyType: string & =~"^[-._a-zA-Z0-9]+$"

// #SecretObjectType: the Kubernetes Secret `type` field. Same closed set core
// carries today; a group's members must agree on it.
#SecretObjectType: "Opaque" |
	"kubernetes.io/service-account-token" |
	"kubernetes.io/dockercfg" |
	"kubernetes.io/dockerconfigjson" |
	"kubernetes.io/basic-auth" |
	"kubernetes.io/ssh-auth" |
	"kubernetes.io/tls" |
	"bootstrap.kubernetes.io/token"

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
	// it, this is the group plan's objectName.
	ref!: #NameType

	// The key to read inside that object. Need not equal the declared key: the
	// module names its own slot, the cluster names its own.
	key!: #SecretKeyType
}

// ─── The routing marker ─────────────────────────────────────────────────────

// #SecretMarker: the parsed form of `@opm(secret, …)`.
//
// Grammar, as written on a #config field:
//
//	@opm(secret [, group=<name>] [, key=<key>] [, type=<k8s-type>] [, description=<text>])
//
// Position 0 is the marker kind, matching the `@opm(identity, owner=publish)`
// form enhancement 0011 D5 already uses for tool-owned identity fields. One
// `@opm` namespace, dispatched on position 0, keeps OPM to a single attribute
// name across every marker it will ever want.
//
// Every argument past position 0 is optional and derivable. `@opm(secret)` is
// the intended common case; the arguments exist for the minority of secrets that
// must share one Kubernetes object (basic-auth pairs, TLS pairs,
// dockerconfigjson) or must land under a key the consuming workload dictates.
#SecretMarker: {
	// Position 0. Always "secret" for this enhancement; other values in this
	// slot belong to other markers (e.g. "identity") and are not this
	// enhancement's concern.
	kind: "secret"

	// Which Kubernetes Secret object this field's data lands in. Fields sharing a
	// group land in one object; the default puts every secret of an instance that
	// did not ask otherwise into one object per instance.
	group: #NameType | *"secrets"

	// The key inside that object's data map. Defaults to the config path with
	// separators folded to underscores (#DeriveKey), so db.password and
	// redis.password cannot collide.
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
	path!: #ConfigPathType

	// The parsed marker, with defaults applied.
	marker!: #SecretMarker

	// `let` captures the field from the enclosing scope. Passing `{path: path}`
	// directly would make the inner `path` a self-reference to the field being
	// declared in that struct literal — the same shadowing trap core documents
	// around its own `let _d = data` helpers.
	let _p = path

	// Resolved key: marker.key when given, derived from the path otherwise.
	key: #SecretKeyType
	if marker.key != _|_ {
		key: marker.key
	}
	if marker.key == _|_ {
		key: (#DeriveKey & {path: _p}).out
	}
}

#SecretDeclList: [...#SecretDecl]

// #DeriveKey: default data key for a marked field — the config path with
// separators folded to underscores. Collision-free because the path it comes
// from is unique. List-index brackets are folded so the result stays inside
// #SecretKeyType.
#DeriveKey: {
	path!: string
	out: #SecretKeyType & strings.Replace(
		strings.Replace(strings.Replace(path, ".", "_", -1), "[", "_", -1),
		"]", "", -1)
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
	objectName!: #NameType

	// Agreed across every member; the kernel rejects a group that disagrees.
	type:      #SecretObjectType | *"Opaque"
	immutable: bool | *false

	// key -> plaintext. Travels out of band to the materialising component and
	// is never present in the component graph.
	data!: [#SecretKeyType]: string

	// Which config paths fed this group — diagnostics and provenance only.
	members!: [...#ConfigPathType]
}

// #ObjectName: the ONE place an OPM-owned Secret object gets its name.
// Instance-scoped rather than component-scoped: a Kubernetes Secret is a
// namespaced object, so two components of one instance sharing a group must
// reach the same object.
#ObjectName: {
	instance!: #NameType
	group!:    #NameType
	out:       #NameType & "\(instance)-\(group)"
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
	base!: #NameType
	data: [string]: string

	let _d = data
	out: #NameType & "\(base)-\((#ContentHash & {data: _d}).out)"
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
	declarations!: #SecretDeclList

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
	name!:     #NameType
	type:      #SecretObjectType | *"Opaque"
	immutable: bool | *false
	data!: [#SecretKeyType]: string
}
