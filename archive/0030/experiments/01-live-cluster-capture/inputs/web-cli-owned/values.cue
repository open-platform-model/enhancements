// Starting values from the module's debugValues, the author's test values.
// Review them before deploying.
package instance

values: {
	image: {
		repository: "nginx"
		tag:        "1.27"
		digest:     ""
	}
	replicas:    1
	port:        80
	serviceType: "ClusterIP"
}
