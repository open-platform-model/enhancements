// Copied verbatim from enhancements/0001/schemas/target.cue at the time
// of writing (see Setup). Skill rule: copy, never reference. If target.cue's
// #CatalogFQNType evolves, this copy goes stale on purpose — re-copy when
// re-running.
//
// Catalog FQN: `<modulePath>@<version>` (no `name` segment).
// Distinct from #FQNType which is `<modulePath>/<name>@<version>` for
// primitives. Both accept SemVer 2.0. See D19.
package schema

#CatalogFQNType: string &
	=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
