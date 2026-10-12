package citerewrite

import "testing"

// T5.9a fix-check, blocking 1: a Markdown quote paragraph, a lazy
// continuation line and a quote inside a list item are read as one paragraph,
// or the site is a worklist row. No text is dropped and no id is doubled.
func TestLazyQuote(t *testing.T) {
	d4 := Quoted(titleOf("0010", 4))
	runCases(t, []rewriteCase{
		// the inputs of the reviewer
		{name: "lazy line, retired id at its start", file: "a.md",
			in:    "> a long-lived holder (the change stream of\n0030:D2:R5, a log stream) could read it.\n",
			sites: []string{"2:retired-inline"}},
		{name: "lazy line, list item cut by the wrap", file: "a.md",
			in:    "> Sources 0030:D9 (events feed), 0030:D10\n(logs).\n",
			sites: []string{"1:retired-inline", "1:retired-inline"}},
		{name: "lazy line, rule keyword above", file: "a.md",
			in:   "> The system SHALL\nreject a write (0010:D4).\n",
			want: "> The system SHALL\nreject a write (enhancement 0010).\n"},
		{name: "lazy line, id repeated above", file: "a.md",
			in: "> Introduced by enhancement 0010\n(0010:D4) and fixed.\n", sites: []string{"2:repeat-id"}},
		{name: "quote in a list item", file: "a.md",
			in:    "- > a long-lived holder (the change stream of\n  > 0030:D2:R5, a log stream) could read it.\n",
			sites: []string{"2:retired-inline"}},
		// near variants
		{name: "lazy line, two lazy lines", file: "a.md",
			in:    "> a long-lived holder (the change stream of\nthe holder, and\n0030:D2:R5, a log stream) could read it.\n",
			sites: []string{"3:retired-inline"}},
		{name: "lazy line, retired id at the line end", file: "a.md",
			in: "> The cache is read, per 0030:D4\nand then it is filled.\n", sites: []string{"1:retired-inline"}},
		{name: "lazy line, rule keyword two lines up", file: "a.md",
			in:   "> The system SHALL\nstill\nreject a write (0010:D4).\n",
			want: "> The system SHALL\nstill\nreject a write (enhancement 0010).\n"},
		{name: "lazy line, id repeated, quote marks on the id line", file: "a.md",
			in: "> Introduced by enhancement 0010 and\nlater (0010:D4) fixed.\n", sites: []string{"2:repeat-id"}},
		{name: "quote in a list item, id repeated", file: "a.md",
			in: "- > Introduced by enhancement 0010\n  > (0010:D4) and fixed.\n", sites: []string{"2:repeat-id"}},
		{name: "quote in a list item, lazy line", file: "a.md",
			in:    "- > a long-lived holder (the change stream of\n  0030:D2:R5, a log stream) could read it.\n",
			sites: []string{"2:retired-inline"}},
		{name: "quote in a numbered item", file: "a.md",
			in:    "1. > a long-lived holder (the change stream of\n   > 0030:D2:R5, a log stream) could read it.\n",
			sites: []string{"2:retired-inline"}},
		// the paragraph ends where Markdown ends it
		{name: "a second list item is a new paragraph", file: "a.md",
			in:    "- > It uses enhancement 0010.\n- > Later (0010:D4) adds keys.\n",
			want:  "- > It uses enhancement 0010.\n- > Later (enhancement 0010, " + d4 + ") adds keys.\n",
			sites: nil},
		{name: "a blank line ends the lazy quote", file: "a.md",
			in: "> A note.\n\nIt names enhancement 0010\n(0010:D4) and more.\n", sites: []string{"4:repeat-id"}},
		{name: "a quote after plain text starts a new paragraph", file: "a.md",
			in:   "It names enhancement 0010.\n> Later (0010:D4) adds keys.\n",
			want: "It names enhancement 0010.\n> Later (enhancement 0010, " + d4 + ") adds keys.\n"},
	})
}

// T5.9a fix-check, blocking 2: a range or contrast cut by a line break before
// or after its connector is never given one title for both ends.
func TestSplitRange(t *testing.T) {
	d2, _ := DefaultTitles().Title("0013", 2)
	one := "enhancement 0013 (" + Quoted(d2) + ")"
	w := []string{"1:wrapped"}
	runCases(t, []rewriteCase{
		{name: "connector to, on the next line", file: "a.md", in: "Use 0013:D2:R3\nto R14 here.\n", sites: w},
		{name: "connector not, on the next line", file: "a.md", in: "Use 0013:D2:R3,\nnot R4 here.\n", sites: w},
		{name: "connector -, at the line end", file: "a.md", in: "Use 0013:D2:R3 -\nR14 here.\n", sites: w},
		{name: "connector up to, at the line end", file: "a.md", in: "Use 0013:D2:R3 up to\nR14 here.\n", sites: w},
		{name: "connector up to, on the next line", file: "a.md", in: "Use 0013:D2:R3\nup to R14 here.\n", sites: w},
		{name: "connector rather than, split", file: "a.md", in: "Use 0013:D2:R3 rather\nthan R4 here.\n", sites: w},
		{name: "connector rather than, on the next line", file: "a.md", in: "Use 0013:D2:R3\nrather than R4 here.\n", sites: w},
		{name: "connector through, on the next line", file: "a.md", in: "Use 0013:D2:R3\nthrough R5 here.\n", sites: w},
		{name: "connector to, at the line end", file: "a.md", in: "Use 0013:D2:R3 to\nR14 here.\n", sites: w},
		{name: "connector and, then R", file: "a.md", in: "Use 0013:D2:R3 and\nR4 here.\n", sites: w},
		{name: "connector and, on the next line", file: "a.md", in: "Use 0013:D2:R3\nand R4 here.\n", sites: w},
		{name: "second end is a full citation", file: "a.md", in: "Use 0013:D2:R3\nto 0013:D2:R4 here.\n", sites: []string{"1:wrapped", "2:repeat-id"}},
		{name: "in a quote", file: "a.md", in: "> Use 0013:D2:R3\n> to R14 here.\n", sites: w},
		{name: "in a list item", file: "a.md", in: "- Use 0013:D2:R3\n  to R14 here.\n", sites: w},
		{name: "in a yaml scalar", file: "a.yaml", in: "doc: Use 0013:D2:R3\n  to R14 here.\n", sites: w},
		{name: "a rule sentence too", file: "a.md", in: "It MUST use 0013:D2:R3\nto R14 here.\n", sites: w},
		// not a range: the sentence is rewritten as before
		{name: "and with no requirement after", file: "a.md",
			in: "Use 0013:D2:R3 and\nkeep the old key.\n", want: "Use " + one + " and\nkeep the old key.\n"},
		{name: "to with a word after", file: "a.md",
			in: "Use 0013:D2:R3 to\nkeep the old key.\n", sites: w},
		{name: "same line range still gives one title", file: "a.md",
			in: "Use 0013:D2:R3 to R14\nhere.\n", want: "Use " + one + "\nhere.\n"},
		{name: "a full stop ends the sentence", file: "a.md",
			in: "Use 0013:D2:R3.\nR14 holds too.\n", want: "Use " + one + ".\nR14 holds too.\n"},
	})
}

// T5.9a fix-check, should-fix 1: a sibling key of a YAML list of mappings is
// no continuation of the value above, and a rule keyword stays in its value.
func TestYAMLSiblingKeys(t *testing.T) {
	d4 := Quoted(titleOf("0010", 4))
	runCases(t, []rewriteCase{
		{name: "workflow steps", file: "a.yaml",
			in:   "steps:\n  - name: Build it\n    run: make all (0010:D4)\n",
			want: "steps:\n  - name: Build it\n    run: make all (enhancement 0010, " + d4 + ")\n"},
		{name: "rule keyword stays in its value", file: "a.yaml",
			in:   "steps:\n  - name: The service MUST start\n    doc: Reject a write (0010:D4)\n",
			want: "steps:\n  - name: The service MUST start\n    doc: Reject a write (enhancement 0010, " + d4 + ")\n"},
		{name: "anchor only", file: "a.yaml",
			in:   "base: &b\n  doc: Note (0010:D4)\n",
			want: "base: &b\n  doc: Note (enhancement 0010, " + d4 + ")\n"},
		{name: "anchor and tag only", file: "a.yaml",
			in:   "base: &b !!map\n  doc: Note (0010:D4)\n",
			want: "base: &b !!map\n  doc: Note (enhancement 0010, " + d4 + ")\n"},
		{name: "sibling key after a plain value", file: "a.yaml",
			in:   "- name: Build it\n  run: make all (0010:D4)\n",
			want: "- name: Build it\n  run: make all (enhancement 0010, " + d4 + ")\n"},
		{name: "a plain scalar still goes on", file: "a.yaml",
			in: "doc: Each names enhancement 0010 as the key, and it names the\n  own key (0010:D4).\n", sites: []string{"2:repeat-id"}},
		{name: "a list-item scalar still goes on", file: "a.yaml",
			in: "- Each names enhancement 0010 as the key, and it names the\n  own key (0010:D4).\n", sites: []string{"2:repeat-id"}},
		{name: "an open quoted scalar goes on, key-like line included", file: "a.yaml",
			in: "doc: \"Say it\n  run: (0010:D4) now\"\n", sites: []string{"2:unsafe-yaml"}},
	})
}
