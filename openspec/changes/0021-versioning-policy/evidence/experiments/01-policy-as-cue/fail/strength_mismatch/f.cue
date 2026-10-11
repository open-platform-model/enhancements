// Negative case: the sentence says SHOULD, the field says must.
package f

import "strings"

#Rule: {
	statement!: string
	strength!:  "must" | "should" | "may"
	statement:  =~"\\b\(strings.ToUpper(strength))\\b"
}
r: #Rule & {statement: "A release SHOULD bump.", strength: "must"}
