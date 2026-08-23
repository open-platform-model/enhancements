// Schema slice copied 2026-07-25 from core/src/types.cue (#NameType,
// #ModulePathType, #VersionType, #FQNType) and core/src/catalog.cue
// (#CatalogFQNType, the #ComponentTransformer metadata shape).
//
// Skill rule: copy, never reference. These are the bytes as of the date
// above; core may evolve independently.
//
// NOTE what is deliberately ABSENT here: #Catalog itself. The catalog's
// `metadata.version` declaration is this experiment's independent variable,
// so each variant package defines its own #Catalog. Everything a variant
// does NOT vary lives in this shared package.
package schema

import "strings"

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

#ModulePathType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$" & strings.MinRunes(1) & strings.MaxRunes(254)

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// #FQNType: primitive-level FQN — modulePath/name@semver.
#FQNType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// #CatalogFQNType: catalog-level FQN — modulePath@semver (no name segment).
#CatalogFQNType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#PrimitiveMetadata: {
	name!:        #NameType
	modulePath!:  #ModulePathType
	version!:     #VersionType
	fqn:          #FQNType & "\(modulePath)/\(name)@\(version)"
	description?: string
}

#ComponentTransformer: {
	kind:     "ComponentTransformer"
	metadata: #PrimitiveMetadata
}
