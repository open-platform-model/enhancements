package s_u16b_two_disc_hint



#config: {
	x: ({kind: "s3", class: "object", bucket!: string} | {kind: "nfs", class: "file", server!: string}) @opm(ui, discriminator=kind)
}
