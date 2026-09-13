package v1alpha1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// ValidatingWebhooks Resource
/////////////////////////////////////////////////////////////////

#ValidatingWebhooksResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1alpha1"
		name:           "validating-webhooks"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/validating-webhooks@v1alpha1"
		description:    "ValidatingWebhookConfigurations emitted with exact names"
		labels: {
			"resource.opmodel.dev/category": "admission"
		}
	}

	// Alias must not be `name` — the inner field would shadow it and the
	// default becomes self-referential (cf. catalog_opm configmap.cue).
	spec: validatingWebhooks: [KeyName=string]: #ValidatingWebhookConfigurationSchema & {name: string | *KeyName}
}

#ValidatingWebhooks: c.#Component & {
	#resources: (#ValidatingWebhooksResource.metadata.fqn): #ValidatingWebhooksResource
}

/////////////////////////////////////////////////////////////////
//// MutatingWebhooks Resource
/////////////////////////////////////////////////////////////////

#MutatingWebhooksResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1alpha1"
		name:           "mutating-webhooks"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/mutating-webhooks@v1alpha1"
		description:    "MutatingWebhookConfigurations emitted with exact names"
		labels: {
			"resource.opmodel.dev/category": "admission"
		}
	}

	spec: mutatingWebhooks: [KeyName=string]: #MutatingWebhookConfigurationSchema & {name: string | *KeyName}
}

#MutatingWebhooks: c.#Component & {
	#resources: (#MutatingWebhooksResource.metadata.fqn): #MutatingWebhooksResource
}

/////////////////////////////////////////////////////////////////
//// Webhook Schemas
/////////////////////////////////////////////////////////////////

// Shared config-level metadata. Names are exact — external controllers
// (istiod, cainjector) reference and patch these objects by name, so
// prefixing is never useful.
// `name` is auto-populated from the map key in the resource spec.
#WebhookConfigurationMetaSchema: {
	name: string
	// Merged over context labels (user wins on conflict) — upstream charts
	// carry their own app.kubernetes.io/* label sets.
	labels?: {[string]: string}
	// e.g. "cert-manager.io/inject-ca-from-secret": "<ns>/<secret>"
	annotations?: {[string]: string}
}

// The webhooks lists are declared per variant (not on the shared meta schema)
// so the mutating elements can carry reinvocationPolicy without fighting the
// closed base #WebhookSchema.
#ValidatingWebhookConfigurationSchema: {
	#WebhookConfigurationMetaSchema
	webhooks!: [_, ...] & [...#WebhookSchema]
}

#MutatingWebhookConfigurationSchema: {
	#WebhookConfigurationMetaSchema
	webhooks!: [_, ...] & [...#MutatingWebhookSchema]
}

#WebhookSchema: {
	name!: string
	clientConfig!: {
		service!: {
			name!:      string
			namespace!: string
			path?:      string
			port?:      uint & >=1 & <=65535
		}
		// NO caBundle field on purpose: cainjector/istiod populate it at
		// runtime; a placeholder would break both. Add only if a consumer
		// genuinely pre-provisions a CA.
	}
	rules?: [...{
		apiGroups!: [...string]
		apiVersions!: [...string]
		operations!: [...("CREATE" | "UPDATE" | "DELETE" | "CONNECT" | "*")]
		resources!: [...string]
		scope?: "Cluster" | "Namespaced" | "*"
	}]
	failurePolicy?: "Fail" | "Ignore"
	matchPolicy?:   "Exact" | "Equivalent"
	sideEffects!:   "None" | "NoneOnDryRun"
	admissionReviewVersions!: [...string]
	namespaceSelector?: {...}
	objectSelector?: {...}
	timeoutSeconds?: int & >=1 & <=30
}

// Mutating-only extension: the mutating admission API additionally supports
// reinvocationPolicy. Embedded (not unified) so the extra field is legal
// against the closed #WebhookSchema.
#MutatingWebhookSchema: {
	#WebhookSchema
	reinvocationPolicy?: "Never" | "IfNeeded"
}
