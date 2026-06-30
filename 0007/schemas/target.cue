// Target schema for enhancement 0007 — Manifest Passthrough.
//
// This models the APPLY-LAYER surface only. There is intentionally NO
// definition under opmodel.dev/core here: passthrough is an operator-CRD +
// CLI feature (D1), so the canonical shape is the ModuleInstance/ModulePackage spec
// addition plus a provenance marker — not a core-schema primitive.
//
// As decisions land in ../03-decisions.md, tighten the fields marked with
// `// OQn:` to match.
package schema

// #ExtraManifestSource — one declared side-channel manifest source.
//
// Discriminated union: exactly one of `raw` | `kustomize`. OQ1 may narrow
// this to raw-only for the first cut; both are modeled until then.
#ExtraManifestSource: {
	// Plain YAML manifests, applied verbatim (no overlay semantics).
	// `path` is a file or glob, resolved within the release source tree.
	raw?: {
		path!: string
	}

	// A directory containing a kustomization.yaml, rendered via the embedded
	// krusty API (D2). `path` resolves within the release source tree.
	kustomize?: {
		path!: string
	}

	// OQ1: union may collapse to `raw` only if Kustomize is deferred.
	// Exactly-one-of is enforced in Go validation rather than CUE here, to
	// keep the CRD openAPI shape simple; documented as an invariant.
}

// #ExtraManifestsSpec — the new optional field on the operator's
// ModuleInstance and ModulePackage CRD specs (and the CLI instance-file equivalent).
//
//   spec.extraManifests: [...#ExtraManifestSource]
//
// OQ3: for ModuleInstance (CUE-native OCI acquisition) the path root is
// unresolved; for ModulePackage it is the extracted Flux artifact tree.
#ExtraManifestsSpec: {
	extraManifests?: [...#ExtraManifestSource]
}

// #PassthroughProvenance — NOT a new inventory/label schema. Side objects
// reuse the operator's existing label set (pkg/core/labels.go) and inventory
// entry (api/v1alpha1/common_types.go). This documents only the additional
// provenance marker distinguishing passed-through objects from rendered ones.
//
// The marker rides on the existing component-provenance label/annotation
// slot; exact key is an implementation detail of the operator slice.
#PassthroughProvenance: {
	// Sentinel recorded on every side-channel object so diffing and
	// observability can separate passthrough from rendered output.
	source: "passthrough"

	// Which declared source produced this object, for traceability.
	kind: "raw" | "kustomize"
}
