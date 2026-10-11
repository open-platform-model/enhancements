package s_u14_nested_union



#config: {
	backup: {kind: "s3", auth: {mode: "key", id!: string} | {mode: "iam"}} | {kind: "nfs", server!: string}
}
