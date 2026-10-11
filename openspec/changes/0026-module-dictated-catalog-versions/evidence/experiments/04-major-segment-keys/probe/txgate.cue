package core

import "regexp"

// PROBE: publish-time refusal of a cross-major bridge: a transformer may not
// require a contract of its OWN registry path at another major (or flat).
#TransformerOwnMajorGate: {
	identity!: #IdentityPackage
	required!: [...string]
	_ownPath: "^" + regexp.QuoteMeta(identity.RegistryPath) + "/((v[0-9]+)/)?(resources|traits|blueprints)/[^/]+@"
	_ownMaj:  "^" + regexp.QuoteMeta(identity.RegistryPath+"/"+identity.Major) + "/(resources|traits|blueprints)/[^/]+@"
	offending: [for k in required if (k =~ _ownPath) && !(k =~ _ownMaj) {k}]
	offending: []
}
txOK: #TransformerOwnMajorGate & {identity: _id6, required: ["opmodel.dev/catalogs/opm/v6/resources/container@v1beta1", "opmodel.dev/catalogs/k8up/v4/traits/x@v1", "opmodel.dev/catalogs/opm-extras/v1/traits/y@v1"]}
// provider catalog requiring another catalog's keys at any major is allowed
txProv: #TransformerOwnMajorGate & {identity: {ModulePath: "opmodel.dev/catalogs/k8up@v4", Version: "4.0.0"}, required: ["opmodel.dev/catalogs/opm/v5/traits/backup@v1alpha1", "opmodel.dev/catalogs/opm/v6/traits/backup@v1alpha1"]}
