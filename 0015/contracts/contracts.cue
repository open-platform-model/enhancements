// Contracts for enhancement 0015 — the transformer-registration AUTHORING
// surface (D9-D12).
//
// This file is deliberately NOT part of the core-schema delta in ../schemas/:
// nothing here adds or changes an opmodel.dev/core definition. It specifies
// the catalog-side contract member, the derivation and stamping rules, and
// the acceptance-side verification that together answer HOW a provider module
// ships the TransformerRegistration CR whose cluster-side shape ../schemas/
// target.cue defines. Sources of truth once implementation lands:
//   - the contract member and its transformer  → catalog_opm/src/
//   - the acceptance verification              → opm-operator (Go)
// Concrete example values at the bottom are the test — `cue vet ./...` from
// this directory checks behaviour, not just syntax (assertion pins observed
// green 2026-08-21).
package contracts

import "list"

// ---------------------------------------------------------------------------
// Shared vocabulary — mirrors of core types, narrowed as in ../schemas/.
// ---------------------------------------------------------------------------

#ModulePath:  =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$"
#ContractFQN: =~"^[a-z0-9._/-]+@v[0-9]+((alpha|beta)[0-9]+)?$"
#Name:        =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
#Version:     =~"^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

#Fulfilment: *"catalog" | "provider"

// ---------------------------------------------------------------------------
// D9 — the contract member catalog_opm publishes.
// ---------------------------------------------------------------------------

// The transformer-registration #Resource, as it lands in catalog_opm (an
// ordinary member of D1's #resources map; modulePath and catalogVersion
// arrive from the catalog's stamp and are omitted here). Its spec is the
// AUTHORING surface: everything the shipped CR needs that is not stamped at
// render. Note what is absent — providerRef is not a spec field at all,
// because it is stamped from instance identity (D11) and must not be
// authorable.
#TransformerRegistrationContract: {
	metadata: {
		name:       "transformer-registration"
		apiVersion: "v1alpha1"
		fqn:        "opmodel.dev/catalogs/opm/resources/transformer-registration@v1alpha1"
	}

	// The declaring catalog implements it: catalog_opm ships the transformer
	// that renders the CR, so registration is self-hosting on the platform's
	// own contract machinery.
	fulfilment: "catalog" & #Fulfilment

	// NO matchLabels, deliberately: the rendering transformer selects on this
	// contract's FQN alone (requiredResources), so the bucket needs no label
	// vocabulary and D5's guard is untouched.

	spec: transformerRegistration: {
		// The provider catalog's OCI coordinates. A CATALOG artifact only —
		// D10's structural refusal (#ClaimedArtifactGate below) is what
		// enforces it.
		catalog!: #ModulePath
		version!: #Version

		// Derived at authoring (D11's fold below), verified for exact
		// equality at acceptance (#ProvidesVerification below).
		provides!: [...#ContractFQN]
	}
}

// ---------------------------------------------------------------------------
// D11 — derivation: the pre-bound value a provider catalog exports.
// ---------------------------------------------------------------------------

// The demand surface of one transformer, narrowed to what the fold reads:
// each demanded contract value carries its own fulfilment (a #Trait /
// #Resource field, present on the values in requiredTraits/requiredResources
// already — no second fetch needed).
#TransformerDemands: {
	requiredTraits?: [#ContractFQN]: {fulfilment: #Fulfilment, ...}
	requiredResources?: [#ContractFQN]: {fulfilment: #Fulfilment, ...}
}

// The pre-bound registration value: given the provider catalog's identity
// package and its own transformer map, every spec field derives. The module
// author attaches this value and writes nothing; the only authored fact left
// in the whole flow is the catalog dependency version in the module's
// cue.mod (D11).
#PreBoundRegistration: {
	#identity: {
		modulePath: #ModulePath // e.g. id.ModulePath
		version:    #Version    // e.g. id.Version
	}
	#transformers: [string]: #TransformerDemands

	// Every provider-fulfilled contract this catalog's own transformers
	// require, deduplicated via struct keys.
	_providerSet: {
		for _, t in #transformers {
			if t.requiredTraits != _|_ {
				for fqn, c in t.requiredTraits if c.fulfilment == "provider" {
					(fqn): true
				}
			}
			if t.requiredResources != _|_ {
				for fqn, c in t.requiredResources if c.fulfilment == "provider" {
					(fqn): true
				}
			}
		}
	}

	spec: transformerRegistration: {
		catalog: #identity.modulePath
		version: #identity.version
		provides: [for fqn, _ in _providerSet {fqn}]
	}
}

// ---------------------------------------------------------------------------
// D11/D12 — stamping: what the rendering transformer adds.
// ---------------------------------------------------------------------------

// The relation between a component's registration spec, the rendering
// instance, and the emitted CR. providerRef and metadata.name are STAMPED
// from #TransformerContext instance metadata: the provider IS the instance
// that rendered the claim, and cannot name anyone else's package.
//
// The CR name is dot-joined namespace.name (D12): cluster-scoped, unique per
// instance because a namespace cannot contain a dot, so two instances of one
// provider module produce two claims and the SECOND is refused at acceptance
// naming the claimant — arbitration at D3's designed site, never an SSA
// field-manager fight over one catalog-named object.
#RenderedRegistration: {
	#instance: {
		name:      #Name
		namespace: #Name
	}
	#spec: {
		catalog: #ModulePath
		version: #Version
		provides: [...#ContractFQN]
	}

	output: {
		apiVersion: "opm.opmodel.dev/v1alpha1"
		kind:       "TransformerRegistration"
		metadata: name: "\(#instance.namespace).\(#instance.name)" // D12
		spec: {
			catalog:  #spec.catalog
			version:  #spec.version
			provides: #spec.provides
			providerRef: {// stamped, never authored (D11)
				name:      #instance.name
				namespace: #instance.namespace
			}
		}
	}
}

// ---------------------------------------------------------------------------
// D10 — acceptance: the structural artifact-kind refusal.
// ---------------------------------------------------------------------------

// Acceptance imports the claimed artifact's root package and requires a
// #Catalog value. A module artifact fails by shape (kind mismatch), so
// "transformers never ship inside module artifacts" costs no gate: it is a
// type error, not a rule anyone maintains.
#ClaimedArtifactGate: {
	artifact: {kind: string, ...}
	ok: artifact.kind == "Catalog"
}

// ---------------------------------------------------------------------------
// D11 — acceptance: provides verified for exact equality.
// ---------------------------------------------------------------------------

// The reconciler re-derives the provider set from the fetched catalog (same
// fold as #PreBoundRegistration) and compares. Subset in either direction is
// drift and refuses the claim naming both lists — a claim is never partially
// honoured.
#ProvidesVerification: {
	claimed: [...#ContractFQN]
	derived: [...#ContractFQN]

	missingFromClaim: [for p in derived if !list.Contains(claimed, p) {p}]
	extraInClaim: [for p in claimed if !list.Contains(derived, p) {p}]

	ok: bool & (len(missingFromClaim) == 0 && len(extraInClaim) == 0)
}

// ---------------------------------------------------------------------------
// Examples — the k8up cast from 01-problem.md, pinned.
// ---------------------------------------------------------------------------

_backupFQN: "opmodel.dev/catalogs/opm/traits/backup@v1beta1"

// The pre-bound value catalog_k8up exports: identity in, spec out. The
// volume demand is catalog-fulfilled and correctly does NOT reach provides.
exK8upPreBound: #PreBoundRegistration & {
	#identity: {
		modulePath: "opmodel.dev/catalogs/k8up@v1"
		version:    "1.2.0"
	}
	#transformers: "opmodel.dev/catalogs/k8up/transformers/backup@1.2.0": {
		requiredTraits: (_backupFQN): {fulfilment: "provider"}
		requiredResources: "opmodel.dev/catalogs/opm/resources/volume@v1": {fulfilment: "catalog"}
	}
}

_assertDerivedCatalog: exK8upPreBound.spec.transformerRegistration.catalog & "opmodel.dev/catalogs/k8up@v1"
_assertDerivedVersion: exK8upPreBound.spec.transformerRegistration.version & "1.2.0"
_assertDerivedProvides: exK8upPreBound.spec.transformerRegistration.provides & [_backupFQN]

// The rendered CR: name and providerRef stamped from the instance.
exRendered: #RenderedRegistration & {
	#instance: {
		name:      "k8up"
		namespace: "backup-system"
	}
	#spec: exK8upPreBound.spec.transformerRegistration
}

_assertCRName:       exRendered.output.metadata.name & "backup-system.k8up"
_assertStampedRef:   exRendered.output.spec.providerRef.name & "k8up"
_assertStampedRefNs: exRendered.output.spec.providerRef.namespace & "backup-system"

// D10's structural refusal: a catalog artifact passes, a module artifact
// fails by kind, no dedicated gate involved.
exGateCatalog: #ClaimedArtifactGate & {artifact: kind: "Catalog"}
exGateModule: #ClaimedArtifactGate & {artifact: kind: "Module"}

_assertGateCatalogOk:     exGateCatalog.ok & true
_assertGateModuleRefused: exGateModule.ok & false

// Acceptance verification: the claim from the rendered CR against the
// reconciler's own derivation — equal, so ok.
exVerifyOk: #ProvidesVerification & {
	claimed: exRendered.output.spec.provides
	derived: [_backupFQN]
}
_assertVerifyOk: exVerifyOk.ok & true

// Drift in either direction refuses: here the fetched catalog's transformers
// require a second provider-fulfilled contract the claim does not name.
exVerifyDrift: #ProvidesVerification & {
	claimed: [_backupFQN]
	derived: [_backupFQN, "opmodel.dev/catalogs/opm/traits/snapshot@v1"]
}
_assertVerifyDriftRefused: exVerifyDrift.ok & false
