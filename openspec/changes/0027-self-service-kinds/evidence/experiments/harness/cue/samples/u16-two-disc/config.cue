package s_u16_two_disc



#config: {
	x: {kind: "s3", class: "object", bucket!: string} | {kind: "nfs", class: "file", server!: string}
}
