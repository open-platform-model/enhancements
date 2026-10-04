package s_u17_optional_union



#config: {
	backup?: {kind: "s3", bucket!: string} | {kind: "nfs", server!: string}
}
