package z

import (
	core "x1a.example/s/corev2w2"

)

#config: {
	f0: [...({kind: "s3", bucket!: string} | {kind: "nfs", server!: string})]
	f1: [...({kind: "s3", bucket!: string} | {kind: "nfs", server!: string})]
	f2: [...({kind: "s3", bucket!: string} | {kind: "nfs", server!: string})]
	f3: [...({kind: "s3", bucket!: string} | {kind: "nfs", server!: string})]
}
