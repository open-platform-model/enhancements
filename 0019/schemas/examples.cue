// Concrete instances for the target.cue delta — the test.
//
// Every NEW or CHANGED definition is exercised against a realistic value, and
// every derived field is pinned with a hidden assertion, so a change in the
// delta's behaviour breaks `cue vet ./...` here rather than being noticed at
// review. The must-fail cases are commented out with the exact error text
// observed on cue v0.17.1, so a reader can re-run them by hand.
package schema

// ---------------------------------------------------------------------------
// D5 — a registry entry derives version and transformers from the catalog
// ---------------------------------------------------------------------------

// A stand-in catalog, shaped like a real one at its two identity fields. In a
// platform module this arrives by import; here it is written out so the
// derivations have something concrete to read.
_opmCatalog: #Catalog & {
	kind: "Catalog"
	metadata: {
		modulePath: "opmodel.dev/catalogs/opm@v2"
		version:    "2.0.0-alpha.4"
	}
	#transformers: {
		"opmodel.dev/catalogs/opm/transformers/deployment@2.0.0-alpha.4": {
			requiredResources: "opmodel.dev/catalogs/opm/resources/container@v1beta1": _
			requiredTraits: "opmodel.dev/catalogs/opm/traits/replicas@v1beta1":        _
		}
		"opmodel.dev/catalogs/opm/transformers/service@2.0.0-alpha.4": {
			requiredResources: "opmodel.dev/catalogs/opm/resources/container@v1beta1": _
			optionalTraits: "opmodel.dev/catalogs/opm/traits/expose@v1beta1":          _
		}
	}
}

_providerCatalog: #Catalog & {
	kind: "Catalog"
	metadata: {
		modulePath: "example.com/catalogs/provider@v1"
		version:    "1.4.2"
	}
	#transformers: "example.com/catalogs/provider/transformers/backup@1.4.2": {
		requiredTraits: "example.com/catalogs/provider/traits/backup@v1beta1": _
	}
}

exampleEntry: #CatalogEntry & {#catalog: _opmCatalog}

// version is a READOUT, not a choice: it equals the catalog's stamped
// identity and nothing else can be written there.
_assertEntryVersion: exampleEntry.version & "2.0.0-alpha.4"

// The transformer map arrives whole.
_assertEntryTransformerCount: true & (len(exampleEntry.#transformers) == 2)

// The operator's optional generation-time stamp: it UNIFIES with the readout,
// so a correct stamp is a no-op and a wrong one is a conflict naming the entry
// (D13's tripwire).
exampleStampedEntry: #CatalogEntry & {
	#catalog: _opmCatalog
	version:  "2.0.0-alpha.4"
}

// MUST FAIL — a stamp that disagrees with the imported bytes:
//
//   exampleStampedEntry: #CatalogEntry & {
//   	#catalog: _opmCatalog
//   	version:  "2.0.0-alpha.3"
//   }
//
//   exampleStampedEntry.version: conflicting values "2.0.0-alpha.3" and
//   "2.0.0-alpha.4"

// ---------------------------------------------------------------------------
// D5 — the platform: key binding, and the composed maps as folds
// ---------------------------------------------------------------------------

examplePlatform: #Platform & {
	metadata: name: "prod"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v2": {#catalog: _opmCatalog}

		// Disabled: present in the file, absent from every fold below.
		"example.com/catalogs/provider@v1": {
			enable:   false
			#catalog: _providerCatalog
		}
	}
}

// The key binds into the embedded catalog rather than being an independent
// label, so this is a readout of the import.
_assertKeyBinding: examplePlatform.#registry["opmodel.dev/catalogs/opm@v2"].#catalog.metadata.modulePath &
	"opmodel.dev/catalogs/opm@v2"

// The fold copies enabled entries only: two transformers, not three.
_assertComposedCount:    true & (len(examplePlatform.#composedTransformers) == 2)
_assertDisabledExcluded: true &
	(examplePlatform.#composedTransformers["example.com/catalogs/provider/transformers/backup@1.4.2"] == _|_)

// D17: the platform carries no reverse index. #composedTransformers is the
// only materialization-shaped field left, and the render build's glue derives
// its buckets from it (experiment 05's #Match takes the composed map and the
// components, and nothing else). Pinned as an ABSENCE so a reintroduced slot
// fails here rather than passing unnoticed.
_assertNoMatchersSlot: true & (examplePlatform.#matchers == _|_)

// MUST FAIL — an entry whose key and import disagree:
//
//   badPlatform: #Platform & {
//   	metadata: name: "prod"
//   	type: "kubernetes"
//   	#registry: "opmodel.dev/catalogs/opm@v2": {#catalog: _providerCatalog}
//   }
//
//   badPlatform.#registry."opmodel.dev/catalogs/opm@v2".#catalog.metadata.modulePath:
//   conflicting values "opmodel.dev/catalogs/opm@v2" and
//   "example.com/catalogs/provider@v1"

// ---------------------------------------------------------------------------
// D16 — the instance-qualified resourceName default, and its DNS ripple
// ---------------------------------------------------------------------------

_prodInstance: #InstanceIdentity & {
	name:      "shop"
	namespace: "apps"
}

exampleComponent: #Component & {
	metadata: name: "web"
	#instance: _prodInstance
}

_assertQualifiedDefault: exampleComponent.metadata.resourceName & "shop-web"
_assertNamesFollow:      exampleComponent.#names.resourceName & "shop-web"

// The ripple is by construction: nothing sets the DNS variants.
_assertDNSShort: exampleComponent.#names.dns.short & "shop-web"
_assertDNSLocal: exampleComponent.#names.dns.local & "shop-web.apps"
_assertDNSFqdn:  exampleComponent.#names.dns.fqdn & "shop-web.apps.svc.cluster.local"

// An explicit resourceName still wins, unchanged. This is the escape hatch
// that lets D15 delete #ResourceNameTrait rather than reconcile it, and it
// carries the DNS variants the trait never did.
exampleExactNameComponent: #Component & {
	metadata: {
		name:         "webhook"
		resourceName: "admission"
	}
	#instance: _prodInstance
}

_assertOverrideWins: exampleExactNameComponent.metadata.resourceName & "admission"
_assertOverrideDNS:  exampleExactNameComponent.#names.dns.fqdn & "admission.apps.svc.cluster.local"

// A non-default cluster domain reaches the fqdn, unchanged by this entry.
exampleCustomDomainComponent: #Component & {
	metadata: name: "web"
	#instance: {
		name:          "shop"
		namespace:     "apps"
		clusterDomain: "k8s.internal"
	}
}
_assertCustomDomain: exampleCustomDomainComponent.#names.dns.fqdn & "shop-web.apps.svc.k8s.internal"

// MUST FAIL — a 254-rune override overflows #ObjectNameType (D20's ceiling;
// D16's error() arm, unchanged, names the string):
//
//   overlongOverride: #Component & {
//   	metadata: {name: "x", resourceName: "aaaa…(254)"}
//   	#instance: _prodInstance
//   }
//
//   overlongOverride.metadata.resourceName: resourceName "aaaa…" is not a
//   DNS subdomain (lowercase alphanumerics, hyphens and dots, 1-253 runes)
//
// There is no overlong-DEFAULT refusal any more: two #NameType operands
// concatenate to at most 127 runes, under the ceiling, so D16's guard is
// retired. A default of 64 to 127 runes is admitted unless a primitive
// narrows it (below).

// ---------------------------------------------------------------------------
// D20 / D21 / D23 — three name types, primitive-declared constraints, and
// the hidden assertion (experiments 09 and 11)
// ---------------------------------------------------------------------------

// Stand-in primitives, naming surface only. The container resource computes
// its constraint from its own workload-type key (D23, list-index form).
_containerResource: #Resource & {
	metadata: name:                                 "container"
	matchLabels: "core.opmodel.dev/workload-type"!: "stateless" | "stateful"
	#nameConstraint: [
		if matchLabels["core.opmodel.dev/workload-type"] == "stateful" {#NameType},
		_,
	][0]
}
_stateless: matchLabels: "core.opmodel.dev/workload-type": "stateless"
_stateful: matchLabels: "core.opmodel.dev/workload-type":  "stateful"

_exposeTrait: #Trait & {
	metadata: name: "expose"
	#nameConstraint: #ServiceNameType
}

// A dotted override with no dot-hostile primitive attached: admitted, and
// the dots reach the DNS projection unchanged (no rewrite, D20).
exampleDottedOverride: #Component & {
	metadata: {
		name:         "exporter"
		resourceName: "metrics.internal.example"
	}
	#resources: container: _containerResource & _stateless
	#instance: _prodInstance
}
_assertDotsAdmitted: exampleDottedOverride.#names.resourceName & "metrics.internal.example"

// A 65-rune default on a stateless component: admitted under the 253 ceiling.
exampleLongDefault: #Component & {
	metadata: name:        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	#resources: container: _containerResource & _stateless
	#instance: _prodInstance
}
_assertLongDefaultAdmitted: true & (len(exampleLongDefault.#names.resourceName) == 65)

// Expose attached, default name: the qualified default is already a valid
// DNS-1035 label, so the constraint costs a well-named component nothing.
exampleExposed: #Component & {
	metadata: name:        "web"
	#resources: container: _containerResource & _stateless
	#traits: expose:       _exposeTrait
	#instance: _prodInstance
}
_assertExposedDefault: exampleExposed.#names.resourceName & "shop-web"

// Expose attached, exact override that satisfies DNS-1035: admitted. This is
// the D22 spelling for a workload, Service and projection that share a name.
exampleExposedExact: #Component & {
	metadata: {
		name:         "istiod"
		resourceName: "istiod"
	}
	#resources: container: _containerResource & _stateless
	#traits: expose:       _exposeTrait
	#instance: _prodInstance
}
_assertExposedExact: exampleExposedExact.#names.dns.fqdn & "istiod.apps.svc.cluster.local"

// A raw stateful container, default name: the resource's own conditional
// constraint reads #NameType, which the default satisfies.
exampleStateful: #Component & {
	metadata: name:        "cache"
	#resources: container: _containerResource & _stateful
	#instance: _prodInstance
}
_assertStatefulDefault: exampleStateful.#names.resourceName & "shop-cache"

// MUST FAIL — each case observed on cue v0.17.1 in experiment 11 (v5). The
// diagnostic names the string, the violated bound and the constraint type's
// definition site; it cannot name the primitive or a remedy (see target.cue).
//
// Dotted override + Expose:
//   badExposedDots: #Component & {
//   	metadata: {name: "web", resourceName: "web.internal"}
//   	#resources: container: _containerResource & _stateless
//   	#traits: expose: _exposeTrait
//   	#instance: _prodInstance
//   }
//   badExposedDots._nameFits: invalid value "web.internal"
//     (out of bound =~"^[a-z]([a-z0-9-]*[a-z0-9])?$")
//
// Leading-digit instance + Expose (the latent hole in today's core: #NameType
// admits "1prod", Service refuses "1prod-web" at apply):
//   badLeadingDigit: #Component & {
//   	metadata: name: "web"
//   	#resources: container: _containerResource & _stateless
//   	#traits: expose: _exposeTrait
//   	#instance: {name: "1prod", namespace: "apps"}
//   }
//   badLeadingDigit._nameFits: invalid value "1prod-web"
//     (out of bound =~"^[a-z]([a-z0-9-]*[a-z0-9])?$")
//
// Raw stateful container, dotted override (D23):
//   badStatefulDots: #Component & {
//   	metadata: {name: "cache", resourceName: "cache.internal"}
//   	#resources: container: _containerResource & _stateful
//   	#instance: _prodInstance
//   }
//   badStatefulDots._nameFits: invalid value "cache.internal"
//     (out of bound =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")
//
// 65-rune default on a raw stateful container (the label rule on both axes):
//   badStatefulLong: #Component & {
//   	metadata: name: "aaaa…(60)"
//   	#resources: container: _containerResource & _stateful
//   	#instance: _prodInstance
//   }
//   badStatefulLong._nameFits: invalid value "shop-aaaa…"
//     (does not satisfy strings.MaxRunes(63))

// ---------------------------------------------------------------------------
// D12 — the context as a projection of the other two inputs
// ---------------------------------------------------------------------------

_webInstance: {
	kind: "ModuleInstance"
	metadata: {
		name:      "shop"
		namespace: "apps"
		fqn:       "opmodel.dev/modules/shop:shop:apps"
		uuid:      "0f8fad5b-d9cb-469f-a165-70867728950e"
		labels: "team.opmodel.dev/owner": "platform"
	}
	#moduleMetadata: version: "1.2.0"
}

exampleTransformer: #ComponentTransformer & {
	#transform: {
		#moduleInstance: _webInstance
		#component:      exampleComponent

		// The runtime's whole remaining obligation.
		#context: #runtimeName: "opm-cli"

		output: {
			apiVersion: "apps/v1"
			kind:       "Deployment"
			metadata: {
				name:      #component.#names.resourceName
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.controllerLabels
			}
		}
	}
}

_ctx: exampleTransformer.#transform.#context

// Projected from #moduleInstance, with no Go decode in between.
_assertCtxInstanceName:      _ctx.#moduleInstanceMetadata.name & "shop"
_assertCtxInstanceNamespace: _ctx.#moduleInstanceMetadata.namespace & "apps"
_assertCtxInstanceVersion:   _ctx.#moduleInstanceMetadata.version & "1.2.0"
_assertCtxInstanceLabels: _ctx.#moduleInstanceMetadata.labels & {"team.opmodel.dev/owner": "platform"}

// Projected from #component.
_assertCtxComponentName: _ctx.#componentMetadata.name & "web"

// The label folds were already projections of those two blocks, so they
// follow with no further wiring.
_assertControllerLabels: _ctx.controllerLabels & {
	"app.kubernetes.io/managed-by": "opm-cli"
	"app.kubernetes.io/name":       "web"
	"app.kubernetes.io/instance":   "web"
}

// D16 and D3 meeting in the render: the object name a transformer emits is
// READ from #component.#names (D15), and it is the qualified name because the
// default flipped.
_assertRenderedName: exampleTransformer.#transform.output.metadata.name & "shop-web"
