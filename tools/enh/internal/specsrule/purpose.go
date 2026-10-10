package specsrule

import "strings"

// withoutPurpose returns the text of a spec with its "## Purpose" section
// removed: the heading and every line up to the next "## " heading. Two
// versions of a spec that are equal under this function differ only in the
// Purpose text.
func withoutPurpose(text string) string {
	var kept []string
	in := false
	for _, l := range strings.Split(text, "\n") {
		trim := strings.TrimRight(l, " \t\r")
		switch {
		case trim == "## Purpose":
			in = true
			continue
		case in && strings.HasPrefix(trim, "## "):
			in = false
		}
		if !in {
			kept = append(kept, l)
		}
	}
	return strings.Join(kept, "\n")
}
