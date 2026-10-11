# Source note: seed-transformer-registration

This is a seed. It records behaviour the operator ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `transformer-registration`. Full seed (11 requirements). Written 2026-10-11 from the operator at commit `cb97ffb0`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, field path, condition reason or file path. Three operator specs are merged here; `opm-operator` is shortened to "operator" in the table. Specs are under `openspec/specs/`, code under the repo root.

| Requirement here | Source requirement in the operator's spec | Code read |
| --- | --- | --- |
| Cluster-scoped TransformerRegistration resource | `transformer-registration-crd` at `cb97ffb0`, "Cluster-scoped TransformerRegistration resource" (the scheme registration sentence is a mechanism and is left out) | `api/v1alpha1/transformerregistration_types.go` (the `scope=Cluster` and status markers); `config/crd/bases/opmodel.dev_transformerregistrations.yaml` (group, scope, versions) |
| Every claim field is required at admission | `transformer-registration-crd`, "Every claim field is required at admission" | same CRD file: `required` lists catalog, providerRef, provides, version; `minLength: 1` on catalog, version and both providerRef fields; no `minItems` on provides (`opmodel.dev_transformerregistrations.yaml` at `cb97ffb0`: `provides` at `:102` and in `required` at `:124`, no `minItems`); acceptance passes an empty list: `transformerregistration_controller.go:181` calls `providesDrift` (`:332-349`), which compares the claimed list with the catalog's derived provider contracts by `slices.Equal`, so two empty lists match, and no later check on `:186-264` refuses an empty list |
| The claim's name is instance-derived | `transformer-registration-crd`, "The claim's name is instance-derived" | `transformerregistration_types.go`, the `XValidation` marker `self.metadata.name.contains('.')` |
| Claim status separates acceptance from activation | `transformer-registration-crd`, "Claim status separates acceptance from activation" (first paragraph; the verdict sentence and its scenario are dropped, see Left out) | `transformerregistration_types.go` (status fields); `internal/controller/transformerregistration_controller.go` (`Reconcile`, `accept`, `gateActivation`) |
| Creating a claim requires platform-admin RBAC | `transformer-registration-crd`, "Creating a claim requires platform-admin RBAC" | `config/rbac/transformerregistration_admin_role.yaml`; `config/rbac/kustomization.yaml` (role listed, no binding); `internal/reconcile/moduleinstance.go:900` (a forbidden apply under an impersonated identity is marked as an impersonation failure) |
| An accepted claim activates on provider readiness | `registration-activation`, "An accepted claim activates when its provider is ready" | `transformerregistration_controller.go`: `gateActivation` (`:473-488`) and `accept` (`:264`, `:440-445`); `refuse` (`:498-520`) clears the waiting condition only while the claim is inactive (`:516-518`) and sets accepted false (`:508`) |
| Activation latches against provider health | `registration-activation`, "Activation latches against provider health" | `transformerregistration_controller.go`: `gateActivation` returns at once when the claim is active (`:474-476`); `refuse` never clears the active flag (`:508-518`), which the scenario "A refusal does not end activation" states; `docs/design/transformer-registration-activation.md` |
| A claim with dependents cannot be deleted | `registration-removal-guard`, "A claim with dependents cannot be deleted" | `internal/controller/transformerregistration_dependents.go`: `reconcileDeletion`, `holdClaim`, `releaseClaim` |
| The dependent count is derived, never authored | `registration-removal-guard`, "The dependent count is derived, never authored" | `transformerregistration_dependents.go`: `dependents` (`:56-82`, reads the demand each instance records in its own status); `reconcileDeletion` returns the listing error at `:111` before `releaseClaim` at `:136`, so an unreadable count keeps the block and the controller retries |
| A shrinking upgrade is refused while dependents exist | `registration-removal-guard`, "Shrinking provides while dependents exist is refused before it takes effect" (renamed to fit eight words) | `internal/shrink/shrink.go`: `Decide` (`:95-128`; a non-claim resource or a claim whose provides did not shrink returns the zero decision, `:99-101`, `:118-120`); `internal/reconcile/withhold.go`: `withholdRefused`, `refusalMessage` |
| A refused upgrade is reported on its provider | `registration-removal-guard`, "A refused upgrade is reported on the provider it came from" | `internal/reconcile/moduleinstance.go:546` and `:723-734` (event, not-ready mark, transient retry; no mark when `refused` is empty); `internal/reconcile/withhold.go` |

`core` `openspec/specs/catalog-contracts` at `f3b7ecdb` was read as a reference only. No requirement here comes from it: it states how a catalog publishes and derives its contracts, which acceptance and `contract-fulfilment` use.

## Where the repo spec and the code disagree

The code wins. Each point is stated once here and the requirement follows the code.

- **Name check.** The spec says the name "SHALL be constrained to the dot-joined namespace and name of the claiming instance". The code requires only that the name contains a dot (`transformerregistration_types.go`, the `XValidation` marker). Nothing compares the name with the instance. Acceptance finds the claim in the named instance's inventory by name. The requirement says "has no dot" is rejected and describes the rendered name without enforcing it.
- **Activation is not inert.** Two spec statements say a claim changes nothing in the cluster: "A stored claim is inert" in `transformer-registration-crd` and "Activation is reported and inert" in `registration-activation`. The controller comment says the same. The platform controller reads the accepted and active claims to generate the platform package (`internal/controller/platform_controller.go:172`, `activeClaims`), and `registration-driven-regeneration` states that an active claim's catalog reaches the generated package. The seed drops both statements and keeps the reporting half.
- **Who may be blocked.** The spec says deletion of "a `TransformerRegistration`" is prevented while instances depend on it. The code adds the guard finalizer only when a claim is accepted (`holdClaim`, called from `accept`), and `reconcileDeletion` returns at once for a claim without it. The requirement says "an accepted claim".
- **Admin role verbs.** The spec lists create, update and delete. The shipped role also grants patch. The requirement keeps the spec's three verbs and does not say the list is complete.
- **Empty provided list.** The operator spec `transformer-registration-crd` says acceptance refuses a claim from a catalog that implements no provider-fulfilled contract. The code does not: `providesDrift` passes two empty lists (`transformerregistration_controller.go:332-349`), and no later check refuses one. The scenario "A claim with an empty provided list is admitted" states admission only. The operator's own spec stays wrong until the operator changes it (outside this swarm).
- **Required fields beyond the spec.** The CRD also sets `minLength: 1` on catalog and version. The spec states only that the fields are required. The requirement and one scenario follow the CRD.

## Left out

- The registration of the types in the runtime scheme (last sentence of "Cluster-scoped TransformerRegistration resource"): a mechanism.
- The sentence "record a verdict on every claim" and the scenario "A stored claim receives a verdict" in "Claim status separates acceptance from activation": the seed `registration-acceptance` holds them in "Every claim receives a verdict". Only the status fields, the three states, the generation scenario and the activation flag stay here.
- The scenario "A stored claim is inert" and the requirement "Activation is reported and inert": contradicted by the code, see above. What an active claim does to the platform package belongs to `platform-module-generation`.
- The manager role's own verbs on claims (last sentence of "Creating a claim requires platform-admin RBAC"): the operator's internal grant, not a behaviour a platform team observes.
- The authored `floor` and `ceiling` window, and the effective window the status reports: enhancement 0026 (D5, D6) owns them. They will MODIFY "Every claim field is required at admission" and possibly "Claim status separates acceptance from activation".
- Any registration per contract level: enhancement 0021 (D6) owns it.
- Acceptance (catalog kind, provider-set comparison, identity, one provider per contract, build compatibility, transient registry failure): delivered in the seed `registration-acceptance`.
- A blocked claim staying in the active set that generates the platform package: `registration-driven-regeneration`, a later seed (`platform-module-generation`).
- The mechanism that counts dependents: the source spec states the guarantee and not the machinery, and this seed does the same.
- The viewer role (read-only) and the printer columns of the resource: not stated by any source requirement.

sampled: 2026-10-11 18705155
