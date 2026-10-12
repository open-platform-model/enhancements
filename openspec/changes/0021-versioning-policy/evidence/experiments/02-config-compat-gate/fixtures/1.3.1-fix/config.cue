package m

#config: {
	// comment only; accepted set unchanged
	database: url!: string
	replicas: int | *1
	logLevel: "info" | "debug"
}
