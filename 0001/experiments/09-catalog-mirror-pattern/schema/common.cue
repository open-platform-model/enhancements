// Minimal #PrimitiveMetadata + #ComponentTransformer + #FQNType slice copied
// from enhancements/0001/schemas/target.cue. Keeps each variant package's
// definition tight; the only thing that varies across mirror/ alias/ direct/
// is the #Catalog definition itself.
package schema

#FQNType: string &
	=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
#ModulePathType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$"
#VersionType: string &
	=~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#PrimitiveMetadata: {
	name!:       #NameType
	modulePath!: #ModulePathType
	version!:    #VersionType
	fqn:         #FQNType & "\(modulePath)/\(name)@\(version)"
}

#ComponentTransformer: {
	kind:     "ComponentTransformer"
	metadata: #PrimitiveMetadata
}
