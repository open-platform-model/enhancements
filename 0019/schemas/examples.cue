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

// MUST FAIL — the concatenation overflows #NameType's 63-rune budget
// (33-rune instance + 1 + 33-rune component = 67):
//
//   overlongComponent: #Component & {
//   	metadata: name: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
//   	#instance: {name: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", namespace: "apps"}
//   }
//
//   overlongComponent.metadata.resourceName: incomplete value
//   =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) &
//   strings.MaxRunes(63)
//
// That is the caveat D16 records and the core-resourcename-default slice
// closes: the refusal is real (nothing invalid renders), but it names
// #NameType's constraints instead of the offending string. Contrast the
// UNVALIDATED spelling `*"\(#instance.name)-\(name)" | #NameType`, which does
// not refuse at all: measured here, it exports
// "bbbb…-aaaa…" at 67 runes with cue export exiting 0.

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
