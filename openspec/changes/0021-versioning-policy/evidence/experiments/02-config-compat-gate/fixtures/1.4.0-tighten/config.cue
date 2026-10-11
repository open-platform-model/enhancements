package m

#config: {
	database: url!: string
	replicas: int & >0 | *1
	logLevel: "info"
}
