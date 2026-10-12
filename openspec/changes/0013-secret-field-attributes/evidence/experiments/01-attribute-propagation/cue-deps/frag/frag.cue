package frag

// A catalog-shipped composite: both fields arrive already marked, so a module
// that embeds #BasicAuth inherits the marks without restating them.
#BasicAuth: {
	username: string @opm(secret, group=basic-auth, key=username, type="kubernetes.io/basic-auth")
	password: string @opm(secret, group=basic-auth, key=password, type="kubernetes.io/basic-auth")
}
