# 0007: Manifest Passthrough

A team that adopts OPM often already has plain YAML or a Kustomize directory. This change lets an instance declare those extra manifests. OPM then treats them like the objects it rendered itself.

## Why

OPM has nowhere to put an existing manifest. A team applies it by hand, and then nothing marks it as owned, nothing records it, and nothing deletes it when the instance goes. It leaks and it drifts. The only other route is to rewrite everything as typed components first, which blocks a partial migration.

## What Changes

- An instance declares an optional list of extra manifest sources. Each source is a raw YAML path or a Kustomize directory.
- OPM joins the objects of those sources to the rendered ones before it labels, records, applies and prunes. One owner, one inventory, one prune.
- Each side object carries a marker that says it came from a declared source, and which kind.
- The CLI and the controller give the same result for the same declaration.
- The core schema and the kernel stay as they are.

## What this is not

- Not a typed path. Side manifests get none of the schema checks that components get.
- Not a plugin system. Kustomize and raw YAML only. Helm, jsonnet and cdk8s are out.
- Not templating. Values of the instance do not flow into the side manifests.
- Not a replacement for the untyped object redesign of enhancement 0005. The two may stay side by side.

## Example

```yaml
extraManifests:
  - raw: { path: ./extra/servicemonitor.yaml }
  - kustomize: { path: ./overlays/prod }
```

When the instance is deleted, the monitor and the overlay output go with the rendered workload.

## Capabilities

- **New:** `passthrough-declaration`, `passthrough-lifecycle`, `passthrough-drivers`

## Impact

- **Module authors and platform teams** can attach cluster glue to an instance and keep one inventory.
- **Teams with a Kustomize repo** onboard step by step.
- **Two repos** change: cli and opm-controller. The change is additive: an instance without the list renders as before.

## Open questions

- Blocking: Does the first cut ship full Kustomize builds, or raw YAML only? Raw only is about a third of the work and covers much of the need. Kustomize adds a dependency and a hardening surface.
- Blocking: How does this relate to the untyped object redesign of enhancement 0005? Are the two complementary, or does one cover the other? Settle it with the author of 0005.
- Blocking: Where do the source paths of a module instance resolve? A package has an extracted source tree. A module instance is fetched from a registry and has none. Options: packaged in the module artifact, a separate referenced source, or not supported in the first cut.
- Blocking: What is the default posture of Kustomize in the controller? The design turns exec plugins off. Decide whether Helm inflation is off too, and whether any of it has an opt-in trusted mode.
- Blocking: What happens when a side object has the same kind, namespace and name as a rendered object? The options are an error, the side object wins, or the rendered one wins. Silent last-writer-wins must not happen.
- Not blocking: Should OPM fill values of the instance into the side manifests? The current answer is no, verbatim only. Confirm it or open a follow-up.
- Not blocking: Where does the shared renderer live? The library is ruled out. Options: a small module both repos import, one repo that the other imports, or deliberate duplication.
