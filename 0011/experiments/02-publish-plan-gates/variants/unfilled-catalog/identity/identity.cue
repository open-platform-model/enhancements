package identity

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// As ok-catalog, but Version is left OPEN — declared and unfilled. D6 makes
// that an absent value rather than a placeholder one, and D4's gate is what
// stops it reaching a registry.
ModulePath: "example.com/catalogs/demo@v1"
Version:    #VersionType
