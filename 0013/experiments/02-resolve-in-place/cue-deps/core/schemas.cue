package core

import (
	"crypto/sha256"
	"encoding/hex"
	"list"
	"strings"
)

// ─────────────────────────────────────────────────────────────────────────────
// MODIFIED COPY. Upstream core/src/schemas.cue at 7500c5d is 455 lines: the
// #Secret contract type with its $opm/$secretName/$dataKey meta-fields, plus
// #SecretSchema, #SecretContentHash, #SecretImmutableName, and the ~240-line
// hand-unrolled #DiscoverSecrets / #GroupSecrets / #AutoSecrets pipeline.
//
// This copy carries the shape enhancement 0013 PROPOSES, so the experiment can
// exercise it before core changes. That is the whole point of the experiment;
// per the experiments protocol the copy is modified, never the original.
//
// The delta versus upstream:
//   - #Secret narrowed to #SecretLiteral | #SecretRef (D10, D12)
//   - $opm / $secretName / $dataKey removed — routing moves to @opm(secret, …)
//   - #SecretK8sRef replaced by #SecretRef ({ref, key})
//   - #SecretSchema, #SecretContentHash, #SecretImmutableName deleted (D9)
//   - the entire discovery pipeline deleted — it is Go now (D3)
//   - #ContentHash, #ConfigMapSchema, #ImmutableName retained unchanged
// ─────────────────────────────────────────────────────────────────────────────

// #Secret: what a module author puts on a sensitive field, and what the
// deployer fills.
//
// The two arms are two statements about one secret:
//   #SecretLiteral  says WHAT the data is     — the deployer has it in hand
//   #SecretRef      says WHERE the data lives — the cluster already holds it
//
// For a literal the kernel turns a *what* into a *where*, and then restates it
// as a #SecretRef. After that both arms are indistinguishable to the render.
#Secret: #SecretLiteral | #SecretRef

// #SecretLiteral: the deployer supplies the data; OPM materialises an object.
#SecretLiteral: {
	value!: string
}

// #SecretRef: the data lives in an object that already exists. Also the shape
// the kernel WRITES for a resolved literal.
#SecretRef: {
	ref!: #NameType
	key!: string & =~"^[-._a-zA-Z0-9]+$"
}

// #ConfigMapSchema: ConfigMap specification. Unchanged from upstream.
#ConfigMapSchema: {
	name!:     string
	immutable: bool | *false
	data: [string]: string
}

// #ContentHash: deterministic 10-character hex hash of a string data map.
// Unchanged from upstream; still used by the ConfigMap path.
#ContentHash: {
	data: [string]: string

	let _keys = [for k, _ in data {k}]
	let _sorted = list.SortStrings(_keys)
	let _pairs = [for _, k in _sorted {"\(k)=\(data[k])"}]

	out: hex.Encode(sha256.Sum256(strings.Join(_pairs, "\n"))[:5])
}

// #ImmutableName: K8s resource name for a ConfigMap. Unchanged from upstream.
#ImmutableName: {
	baseName: string
	data: [string]: string
	immutable: bool | *false

	let _d = data
	_hash: (#ContentHash & {data: _d}).out

	if immutable {
		out: "\(baseName)-\(_hash)"
	}
	if !immutable {
		out: baseName
	}
}
