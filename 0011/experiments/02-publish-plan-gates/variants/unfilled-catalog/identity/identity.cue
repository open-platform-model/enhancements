package identity

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

ModulePath: "example.com/catalogs/demo@v1" @opm(identity, role=modulePath, owner=publish)
Version:    #VersionType                   @opm(identity, role=version, owner=publish)
