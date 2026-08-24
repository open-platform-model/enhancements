// Contracts for enhancement 0022 — Machine-Readable Artifact Metadata in
// cue.mod/module.cue.
//
// Two non-core contracts: the OCI manifest annotation key set publish writes
// (D6) and the reader's fallback ladder (D7). The core-schema delta (the
// block and its gate) lives in ../schemas/target.cue. Source of truth once
// implemented is the CLI; these shapes are the design contract it must
// satisfy.
//
// Fields gated on an Open Question carry an `// OQN:` marker pointing at
// ../07-questions.md.
package contracts

// #Annotations: the OCI manifest annotations publish writes (D6). CUE's own
// three keys are written when a VCS is present (CUE's client refuses an
// empty commit time), OPM's keys always. CUE ignores unknown keys; nothing
// gates on any of them.
// OQ3: final key names and the non-VCS case.
#Annotations: {
	// CUE-defined, written through the client's module-metadata call.
	"org.cuelang.vcs-type"?:        string // "git"
	"org.cuelang.vcs-commit"?:      string
	"org.cuelang.vcs-commit-time"?: string // RFC 3339

	// OPM-defined.
	"dev.opmodel.publisher": =~"^opm/" // "opm/1.0.0-alpha.13"
	"dev.opmodel.cue":       =~"^v"    // toolchain, e.g. "v0.17.1"; not the language floor
	"dev.opmodel.block":     string    // the custom key the artifact carries, "opmodel.dev@v0"; absent on blockless artifacts
}

// #ReaderLadder: how 0016 D5's walk learns kind and core major for one
// candidate version, in order (D7). Each rung needs only the manifest and
// the module-file blob; none needs the zip.
#ReaderLadder: [
	{rung: 1, source: "custom[\"opmodel.dev@v0\"]", kind: "declared", coreMajor: "declared core.major", when: "block present"},
	{rung: 2, source: "deps", kind: "path prefix (OPM domains only)", coreMajor: "major of the opmodel.dev/core@vN key", when: "block absent"},
	{rung: 3, source: "none", kind: "unknown", coreMajor: "none: incompatible", when: "no opmodel.dev/core dependency"},
]

// #ReaderVerdict: what a rung yields for a candidate.
#ReaderVerdict: {
	kind:      "module" | "catalog" | "template" | "unknown"
	coreMajor: =~"^v[0-9]+$" | null
	rung:      1 | 2 | 3
}

_exampleAnnotations: #Annotations & {
	"org.cuelang.vcs-type":        "git"
	"org.cuelang.vcs-commit":      "2370bd6"
	"org.cuelang.vcs-commit-time": "2026-08-24T17:59:40Z"
	"dev.opmodel.publisher":       "opm/1.0.0-alpha.13"
	"dev.opmodel.cue":             "v0.17.1"
	"dev.opmodel.block":           "opmodel.dev@v0"
}

_exampleVerdict: #ReaderVerdict & {kind: "module", coreMajor: "v2", rung: 1}
