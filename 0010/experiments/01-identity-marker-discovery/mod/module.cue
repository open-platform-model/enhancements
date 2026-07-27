// A module as an author writes it after this enhancement.
//
// What is ABSENT is the point: no `version:` (D2), no `modulePath:` (that is
// identity.cue's one line), and no `nameSnakeCase` (D8 — `name` is already the
// snake form, so there is no projection left to make).
//
// The package name equals metadata.name, which equals the module path's leaf.
// Under D8 those are one string, not three that have to be kept in agreement.
package media_server

import (
	c "example.com/exp0010/core"
	res "example.com/exp0010/cat/resources"
)

c.#Module
metadata: {
	name:        "media_server"
	description: "Demo module — one component demanding one catalog resource"
}

// Components are written by EMBEDDING the catalog primitive, the way
// modules/jellyfin/components.cue does it — not by unifying with `&`, which
// re-closes the definition and rejects the spec the primitive itself supplies.
#components: config: {
	res.#ConfigMaps

	spec: configMaps: settings: data: LOG_LEVEL: "info"
}
