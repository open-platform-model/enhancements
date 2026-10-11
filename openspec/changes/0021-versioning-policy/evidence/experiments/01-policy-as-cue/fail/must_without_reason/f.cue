// Negative case: a MUST at the convention layer with no unenforcedBecause.
package f

#Rule: {
	strength!: "must" | "should" | "may"
	layer!:    "convention" | "claim" | "gate" | "aid"
	if strength == "must" && layer == "convention" {unenforcedBecause!: string}
}
r: #Rule & {strength: "must", layer: "convention"}
