package specsrule

import "strings"

// withoutPurpose returns the text of a spec with its "## Purpose" section
// removed: the heading and every line up to the next "## " heading. Two
// versions of a spec that are equal under this function differ only in the
// Purpose text.
func withoutPurpose(text string) string {
	var kept []string
	in := false
	fence := "" // the fence marker that opened the code block we are in
	for _, l := range strings.Split(text, "\n") {
		trim := strings.TrimRight(l, " \t\r")
		// A heading line inside a fenced block is example text. OpenSpec's
		// parser skips fenced blocks, so the rule must too.
		m := fenceOf(trim)
		inFence := fence != ""
		if m != "" && (fence == "" || fence == m) {
			if fence == "" {
				fence = m
			} else {
				fence = ""
			}
		}
		if inFence || m != "" {
			if !in {
				kept = append(kept, l)
			}
			continue
		}
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

// fenceOf returns "```" or "~~~" when the line opens or closes a fenced code
// block, else "".
func fenceOf(line string) string {
	t := strings.TrimLeft(line, " ")
	if len(line)-len(t) > 3 {
		return "" // an indented code block, not a fence
	}
	for _, f := range []string{"```", "~~~"} {
		if strings.HasPrefix(t, f) {
			return f
		}
	}
	return ""
}
