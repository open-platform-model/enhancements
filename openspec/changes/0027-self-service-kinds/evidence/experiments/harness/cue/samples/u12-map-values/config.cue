package s_u12_map_values



#config: {
	stores: [string]: {kind: "s3", bucket!: string} | {kind: "nfs", server!: string}
}
