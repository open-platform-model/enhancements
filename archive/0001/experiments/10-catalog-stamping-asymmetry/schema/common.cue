// Schema slice copied from enhancements/0001/schemas/target.cue (D19 shape).
// `#Catalog.#transformers` carries the pattern-constraint stamping for
// modulePath + version; `#Resource` / `#Trait` / `#Blueprint` carry no
// such stamping by design — D19 + D21's deliberate asymmetry.
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

#Resource: {
	kind:     "Resource"
	metadata: #PrimitiveMetadata
	spec!:    _
}

#Trait: {
	kind:     "Trait"
	metadata: #PrimitiveMetadata
	spec!:    _
}

#Blueprint: {
	kind:     "Blueprint"
	metadata: #PrimitiveMetadata
	spec!:    _
}

#ComponentTransformer: {
	kind:     "ComponentTransformer"
	metadata: #PrimitiveMetadata & {description!: string}
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
