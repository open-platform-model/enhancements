// Minimal slice of enhancements/0001/schemas/target.cue — just enough to
// define `#ComponentTransformer` and a `#TransformerMap` keyed by `#FQNType`.
// Skill rule: copy, never reference.
package schema

import "strings"

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" &
	strings.MinRunes(1) & strings.MaxRunes(63)

#ModulePathType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$" &
	strings.MinRunes(1) & strings.MaxRunes(254)

#VersionType: string &
	=~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#FQNType: string &
	=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#PrimitiveMetadata: {
	name!:        #NameType
	modulePath!:  #ModulePathType
	version!:     #VersionType
	fqn:          #FQNType & "\(modulePath)/\(name)@\(version)"
	description!: string
}

#ComponentTransformer: {
	kind:     "ComponentTransformer"
	metadata: #PrimitiveMetadata
	requiredResources?: [#FQNType]: _
	producesKinds?: [...string]
}

#TransformerMap: [#FQNType]: #ComponentTransformer
