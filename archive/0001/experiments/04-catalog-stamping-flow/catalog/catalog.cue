// Catalog root package — declares the per-package `Catalog` constant. Source
// tree carries the `0.0.0-dev` default; the stamp.sh driver overwrites
// `Version` in a temp build dir before `cue export`. OQ9 / OQ10 / OQ11 / OQ12.
package catalog

import "strings"

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" &
	strings.MinRunes(1) & strings.MaxRunes(63)

#ModulePathType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"

#VersionType: string &
	=~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#FQNType: string &
	=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#PrimitiveMetadata: {
	name!:        #NameType
	modulePath!:  #ModulePathType
	version!:     #VersionType
	fqn:          #FQNType & "\(modulePath)/\(name)@\(version)"
}

#Resource: {
	kind:     "Resource"
	metadata: #PrimitiveMetadata
	spec!:    _
}

// Exported (capital C) so subpackages can import it. OQ10 — the alternative
// `_catalog` would be package-private and break cross-package access.
Catalog: {
	Version:    #VersionType | *"0.0.0-dev"
	ModulePath: #ModulePathType | *"opmodel.dev/experiments/0001/04/catalog"
}
