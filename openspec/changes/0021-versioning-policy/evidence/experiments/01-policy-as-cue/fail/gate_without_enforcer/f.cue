// Negative case: a gate rule that names no enforcer.
package f

#Rule: {
	layer!: "convention" | "claim" | "gate" | "aid"
	if layer == "gate" {enforcedBy!: string}
}
r: #Rule & {layer: "gate"}
