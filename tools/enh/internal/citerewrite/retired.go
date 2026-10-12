package citerewrite

import "regexp"

// The ids 0030 and 0031 were withdrawn and are free again (T5.9b): a new entry
// may take either. A citation of them may name that new entry, so the tool
// never removes one. Every phrase that holds such a citation is a worklist row
// of kind retired-inline, and the agent decides what the text names.

var (
	endRe     = regexp.MustCompile(`^[ \t]*\.?[ \t]*$`)
	endSentRe = regexp.MustCompile(`^[ \t]*\.[ \t]+\S`)
)
