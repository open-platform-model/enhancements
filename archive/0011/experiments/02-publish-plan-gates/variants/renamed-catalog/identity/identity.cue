package identity

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// A conformant-LOOKING catalog whose version field is named CatalogVersion.
// Every value is right; only the name disagrees with #IdentityPackage.
//
// This is the case the rejected `@opm(identity, role=version)` marker existed
// to accommodate — 0011 experiment 01 found such a field by role on a field no
// name lookup could reach. D8 refuses it instead: the schema names the field,
// so a renamed one is a malformed catalog rather than a lookup problem.
ModulePath:     "example.com/catalogs/demo@v1"
CatalogVersion: #VersionType & "1.2.0"
