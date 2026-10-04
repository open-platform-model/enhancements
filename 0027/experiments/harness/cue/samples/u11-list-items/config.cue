package s_u11_list_items



#config: {
	volumes: [...({type: "pvc", claim!: string} | {type: "emptyDir", medium?: string})]
}
