// values.cue — statement A: the deployer's raw values. db.password is the
// supplied arm (plaintext the kernel must resolve away); tls.cert is the
// referenced arm (already a "where", must pass through).
package instance

values: {
	db: password: {value: "hunter2"}
	tls: cert: {ref: "wildcard-cert", key: "tls.crt"}
}
