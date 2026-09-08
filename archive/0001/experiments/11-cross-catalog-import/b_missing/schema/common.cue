// Minimal schema slice copied from enhancements/0001/schemas/target.cue
// (skill rule: copy, never reference). Shared shape across both_subscribed/
// and b_missing/; the two scenarios duplicate this file byte-identically.
package schema

#FQNType: string &
	=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
#ModulePathType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"
#VersionType: string &
	=~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#PrimitiveMetadata: {
	name!:        #NameType
	modulePath!:  #ModulePathType
	version!:     #VersionType
	fqn:          #FQNType & "\(modulePath)/\(name)@\(version)"
	description?: string
}

#Resource: {
	kind:     "Resource"
	metadata: #PrimitiveMetadata
	spec!:    _
}

#ComponentTransformer: {
	kind:     "ComponentTransformer"
	metadata: #PrimitiveMetadata
	requiredResources?: [#FQNType]: #Resource
}

#Catalog: {
	kind: "Catalog"
	metadata: {
		modulePath!: #ModulePathType
		version!:    #VersionType
	}
	_md: metadata
	#transformers: [#FQNType]: #ComponentTransformer & {
		metadata: {
			modulePath: "\(_md.modulePath)/transformers"
			version:    _md.version
		}
	}
}
