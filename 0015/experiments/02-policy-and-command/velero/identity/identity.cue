// Copied shape: catalog_opm/opm/identity/identity.cue (2026-09-11). Real
// values committed (0010 D5); never published, always served by a
// local-module.cue directory replacement.
package identity

ModulePath: "testing.opmodel.dev/experiments/0015/exp02/velero@v0"

Version: "0.1.0"

RegistryPath: "testing.opmodel.dev/experiments/0015/exp02/velero"

kindPrefix: {
	resources:    RegistryPath + "/resources"
	traits:       RegistryPath + "/traits"
	blueprints:   RegistryPath + "/blueprints"
	transformers: RegistryPath + "/transformers"
}
