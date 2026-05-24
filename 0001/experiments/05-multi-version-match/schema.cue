// Minimal slice of enhancements/0001/schemas/target.cue — just enough to
// model SemVer-keyed transformers, FQN lookup, and a MissingFQN diagnostic.
// Skill rule: copy, never reference.
package match

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
	description!: string
}

#ComponentTransformer: {
	kind:     "ComponentTransformer"
	metadata: #PrimitiveMetadata
}

#TransformerMap: [#FQNType]: #ComponentTransformer

// MissingFQN diagnostic shape — the kernel's planned structured-error
// payload when a consumer-declared FQN is absent from #composedTransformers.
// Final shape is OQ15 territory; this is the experiment's working sketch.
#MissingFQN: {
	release!:      #NameType
	component!:    #NameType
	fqn!:          #FQNType
	alternatives: [...#FQNType]
}
