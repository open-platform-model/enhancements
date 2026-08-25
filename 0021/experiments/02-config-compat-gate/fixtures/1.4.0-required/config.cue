package m

#config: {
	database: url!: string
	replicas: int | *1
	logLevel: "info" | "debug"
	region!: string
}
