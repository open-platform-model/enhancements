package identity

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// Written by `opm catalog publish` / `opm catalog version set`, located by
// these names against 0010's #IdentityPackage. There is no marker attribute —
// the schema fixes the file and the field names, so the lookup IS the contract
// (0010 D22, 0011 D8).
ModulePath: "example.com/catalogs/demo@v1"
Version:    #VersionType & "1.2.0"
