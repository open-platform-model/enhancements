// A module, as an author writes it. Nothing here states an address or a
// version — contrast modules/jellyfin/module.cue today, which declares
// modulePath "opmodel.dev/modules" and version "2.0.0" by hand.
package mod

import (
	c "enhancements.opmodel.dev/0003/exp05/core"
	res "enhancements.opmodel.dev/0003/exp05/cat/resources"
)

c.#Module

metadata: {
	// The ONLY thing an author writes about identity.
	name: "media_server"

	// modulePath is NOT here. Under D25 a generated file in THIS package
	// (gen_identity.cue, written by publish or by a local build) supplies it.
	// No subpackage, no import — modules are single-package, so there is no
	// cycle to break and nothing for the author to reference.
}

#components: web: {
	// The module demands a primitive by its MAJOR-keyed fqn. This string is
	// identical whether the module was built against catalog 1.0.0 or 1.2.0 —
	// which is what makes the cross-minor pattern work (D18).
	demands: [res.#ConfigMapsResource.metadata.fqn]
}

// What the module was BUILT AGAINST — the full catalog version, inherited from
// the primitive it uses. This is the compatibility signal the platform checks
// (D19); it is data, not identity.
builtAgainstCatalog: res.#ConfigMapsResource.metadata.version
