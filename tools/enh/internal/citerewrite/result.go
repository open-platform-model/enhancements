package citerewrite

import (
	"sort"
	"strings"
)

// Form numbers the rewrite forms of the plan (plans/T5.2.md).
type Form int

// The rewrite forms.
const (
	FormCodeComment Form = 1 // (0010:D11) -> (enhancement 0010)
	FormText        Form = 2 // 0010:D11 -> enhancement 0010 ("title")
	FormRetired     Form = 3 // 0030:D4 -> the token goes
	FormPath        Form = 4 // enhancements/0010 -> enhancement 0010; site slugs
	FormDelete      Form = 5 // enhancement.yaml is deleted
)

// Worklist kinds. A site with one of these kinds is never rewritten.
const (
	KindLoneID         = "lone-id"    // kind 1: a lone id, or a WHY label
	KindInline         = "inline"     // kind 3: the id is part of the sentence
	KindPossessive     = "possessive" // 0010:D4's rule
	KindOQ             = "oq"         // NNNN:OQn
	KindString         = "string"     // a string literal, a test name, a message
	KindGenerated      = "generated"  // regenerate the file instead
	KindFenced         = "fenced"     // inside a Markdown code fence
	KindHeading        = "heading"    // a Markdown heading that holds a citation
	KindCodeSpan       = "code-span"  // inside a longer inline code span
	KindWrapped        = "wrapped"    // the edit would cross a line
	KindUnknownID      = "unknown-id" // an id that is not one of the 27 entries
	KindRetracted      = "retracted"  // a decision whose heading is a retraction date
	KindUnknownDec     = "unknown-decision"
	KindCUEDef         = "cue-definition" // the title names a CUE definition (#Name)
	KindEntryFile      = "entry-file"      // a path to a file inside an entry
	KindPath           = "path"            // a path to a file of the old entry layout
	KindPathRef        = "path-ref"        // enhancements/NNNN in a code comment
	KindPathDecisions  = "path-decisions"  // enhancements/0010 D1, D6
	KindLink           = "link"            // a link to an entry that needs words
	KindRetiredInline  = "retired-inline"  // 0030:Dn inside a sentence
	KindRetiredLone    = "retired-lone"    // nothing else is left once 0030:Dn goes
	KindRetiredID      = "retired-id"      // a bare 0030 or 0031
	KindUnsafeYAML     = "unsafe-yaml"     // a title would break the YAML scalar
	KindOtherFile      = "other-file"      // a file type the tool does not edit
	KindDecisionAnchor = "decision-anchor" // a link text D4 with a decisions anchor
)

// Edit replaces src[Start:End] with New.
type Edit struct {
	Start, End int
	New        string
	Form       Form
}

// Site is one place that an agent must rewrite.
type Site struct {
	Path  string
	Line  int
	Kind  string
	Text  string
	Title string
}

// FileResult is the outcome for one file.
type FileResult struct {
	Edits []Edit
	Sites []Site
}

// lineIndex maps byte offsets to lines of one source.
type lineIndex struct {
	src    string
	starts []int
}

func newLineIndex(src string) *lineIndex {
	li := &lineIndex{src: src, starts: []int{0}}
	for i := 0; i < len(src); i++ {
		if src[i] == '\n' {
			li.starts = append(li.starts, i+1)
		}
	}
	return li
}

// line returns the 1-based line of an offset.
func (li *lineIndex) line(off int) int {
	return sort.Search(len(li.starts), func(i int) bool { return li.starts[i] > off })
}

// text returns the text of a 1-based line, without its line ending.
func (li *lineIndex) text(line int) string {
	if line < 1 || line > len(li.starts) {
		return ""
	}
	s := li.starts[line-1]
	e := len(li.src)
	if line < len(li.starts) {
		e = li.starts[line] - 1
	}
	return strings.TrimRight(li.src[s:e], "\r")
}

// apply returns src with the edits applied. The edits must not overlap.
func apply(src string, edits []Edit) string {
	if len(edits) == 0 {
		return src
	}
	sorted := append([]Edit(nil), edits...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].Start < sorted[j].Start })
	var b strings.Builder
	last := 0
	for _, e := range sorted {
		if e.Start < last {
			continue // an overlapping edit: the first one wins
		}
		b.WriteString(src[last:e.Start])
		b.WriteString(e.New)
		last = e.End
	}
	b.WriteString(src[last:])
	return b.String()
}
