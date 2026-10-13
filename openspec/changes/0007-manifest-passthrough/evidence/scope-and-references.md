# Scope and cross-references: 0007

The Scope and Cross-References sections of the old `README.md`, moved word for word. The repo paths are as they stood when the entry was written.

## Scope

### In scope

- A side-channel field on the controller's `ModuleInstance` and `ModulePackage` specs, and an equivalent CLI input, declaring raw YAML or Kustomize sources.
- A shared passthrough renderer embedding the Kustomize Go API, with a hardened default option set for controller use.
- Folding passthrough output into the existing apply path, so side objects are labelled, inventoried, staged, drift-detected and pruned like rendered output.
- Identical semantics across the CLI build and apply commands and the controller.

### Out of scope

- Any change to core or the library kernel (D1, which keeps passthrough at the apply layer).
- Typing arbitrary Kubernetes objects inside the CUE pipeline: that is enhancement 0005's untyped-object redesign, and OQ2 tracks the relationship.
- A general external-renderer plugin system for Helm, jsonnet or cdk8s. Kustomize and raw YAML only in this pass.
- Interpolating an instance's values into side manifests; passthrough is verbatim, and OQ4 holds the possible follow-up.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `library/CONSTITUTION.md` | Kernel purity, the constraint that forces passthrough to the apply layer (D1) |
| `opm-controller/api/v1alpha1/moduleinstance_types.go` | Where the side-channel field is added |
| `opm-controller/api/v1alpha1/modulepackage_types.go` | The same field on the package type |
| `opm-controller/api/v1alpha1/common_types.go` | The inventory entry side objects record in |
| `opm-controller/internal/render/` | Where passthrough output joins the rendered list |
| `opm-controller/pkg/core/labels.go` | The ownership labels and the passthrough marker |
| `opm-controller/internal/apply/apply.go` | Staged apply, where passed-through CRDs and namespaces must stage correctly |
| `opm-controller/internal/apply/prune.go` | Inventory-based prune, where side objects must prune under the ownership guard |
| `opm-controller/internal/inventory/` | Where passthrough objects record and diff like rendered ones |
| `opm-controller/internal/source/fetch.go` | The extracted artifact tree rooting a package's source paths |
| `opm-controller/config/crd` | The regenerated custom resource definitions |
| `cli/internal/cmd/release/build.go` | Where the CLI accepts the extra manifests |
| `cli/internal/cmd/release/apply.go` | Where the CLI applies them in the same set |
| `cli/internal/cmdutil/manifest_output.go` | Where passthrough objects serialize with rendered output |
| `enhancements/0005/README.md` | The in-pipeline untyped-object redesign, related through OQ2 |
