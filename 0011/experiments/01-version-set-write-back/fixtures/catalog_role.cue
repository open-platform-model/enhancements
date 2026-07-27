// PROPOSED marker form: the attribute says WHICH identity field this is, so a
// writer never has to fall back to the field's name. Compare catalog_open.cue.
package identity

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

ModulePath: "example.com/catalogs/demo@v1" @opm(identity, role=modulePath, owner=publish)

// Deliberately NOT named "Version" — the writer must find it by role alone.
CatalogVersion: #VersionType @opm(identity, role=version, owner=publish)
