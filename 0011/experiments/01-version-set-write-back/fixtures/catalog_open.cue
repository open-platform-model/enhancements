// As designed (D5/D6): the version field is OPEN, and both identity fields
// carry the same undifferentiated marker.
package identity

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// ModulePath is derivable from cue.mod/module.cue and is always concrete.
ModulePath: "example.com/catalogs/demo@v1" @opm(identity, owner=publish)

// Version is the decision only an explicit command knows.
Version: #VersionType @opm(identity, owner=publish)
