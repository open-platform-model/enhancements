package s_u04_shared_field



#config: {
	store: {kind: "s3", endpoint!: string, bucket!: string} | {kind: "minio", endpoint!: string}
}
