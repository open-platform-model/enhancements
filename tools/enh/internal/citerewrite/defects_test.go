package citerewrite

import (
	"os"
	"path/filepath"
	"testing"
)

// The defects that the repo agents of T5.3 and the review T5.8 found in the
// first version of the tool (agent-swarm refactoring-enhancements, TECH-DEBT.md,
// rows of 2026-10-12). Each table fails without its fix.

// Defect 6: a walk leaves .claude/ alone; a path that names it is processed.
func TestClaudeFolder(t *testing.T) {
	cases := []struct {
		name  string
		paths []string
		want  bool // the skill file is rewritten
	}{
		{"walk of the root", nil, false},
		{"named folder", []string{".claude"}, true},
		{"named inner folder", []string{".claude/skills"}, true},
		{"named file", []string{".claude/skills/s/SKILL.md"}, true},
		{"worktrees stay skipped", []string{".claude/worktrees/w/x.md"}, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			root := t.TempDir()
			for _, rel := range []string{".claude/skills/s/SKILL.md", ".claude/worktrees/w/x.md", "docs/a.md"} {
				p := filepath.Join(root, rel)
				if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(p, []byte("Keeps the key (0010:D4).\n"), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			rep, err := Run(Options{Root: root, Paths: tc.paths})
			if err != nil {
				t.Fatal(err)
			}
			got := false
			for _, c := range rep.Changed {
				got = got || c == ".claude/skills/s/SKILL.md"
				if c == ".claude/worktrees/w/x.md" {
					t.Errorf("worktree file changed")
				}
			}
			if got != tc.want {
				t.Errorf("changed = %v, skill rewritten = %v, want %v", rep.Changed, got, tc.want)
			}
		})
	}
}

// Defect 8: a path to a file of the old entry layout is a worklist row of kind
// path, in every file type, and never an edit.
func TestOldLayoutPaths(t *testing.T) {
	runCases(t, []rewriteCase{
		{name: "archive path in prose", file: "a.md",
			in: "See `enhancements/archive/0010/03-decisions.md` for it.\n", sites: []string{"1:path"}},
		{name: "live path in prose", file: "a.md",
			in: "See enhancements/0010/04-design.md for it.\n", sites: []string{"1:path"}},
		{name: "readme path", file: "a.md",
			in: "See enhancements/0010/README.md and archive/0011/README.md.\n", sites: []string{"1:path", "1:path"}},
		{name: "bare id readme", file: "a.md",
			in: "See (0010/README.md) now.\n", sites: []string{"1:path"}},
		{name: "relative path", file: "a.md",
			in: "See [x](../enhancements/archive/0010/02-problem.md).\n", sites: []string{"1:path"}},
		{name: "code comment", file: "a.go",
			in: "package a\n\n// The text is in enhancements/archive/0010/03-decisions.md here.\nvar x = 1\n", sites: []string{"3:path"}},
		{name: "string literal", file: "a.go",
			in: "package a\n\nvar x = \"enhancements/0010/03-decisions.md\"\n", sites: []string{"3:path"}},
		{name: "yaml value", file: "a.yaml",
			in: "ref: enhancements/archive/0010/03-decisions.md\n", sites: []string{"1:path"}},
		{name: "shell comment", file: "a.sh",
			in: "# see enhancements/0010/03-decisions.md\n", sites: []string{"1:path"}},
		{name: "fence", file: "a.md",
			in: "```\ncat enhancements/0010/03-decisions.md\n```\n", sites: []string{"2:path"}},
		{name: "other file", file: "Makefile",
			in: "# enhancements/0010/03-decisions.md\n", sites: []string{"1:path"}},
		{name: "not an entry: a year folder, a longer path", file: "a.md",
			in: "Open 2026/README.md and docs/0010/README.md and 0010/README.mdx.\n"},
		{name: "new layout page is no old path", file: "a.md",
			in: "See enhancements/0010/design.md now.\n", sites: []string{"1:entry-file"}},
	})
}

// Defect 5: a title that holds a CUE definition token is not written into the
// text. The site goes to the worklist with the title in its row.
func TestCUEDefinitionTitle(t *testing.T) {
	d1, _ := DefaultTitles().Title("0001", 3)
	if !cueDefRe.MatchString(d1) {
		t.Fatalf("the title table changed: 0001 D3 = %q holds no definition token", d1)
	}
	d4, _ := DefaultTitles().Title("0010", 4)
	runCases(t, []rewriteCase{
		{name: "markdown sentence", file: "a.md",
			in: "The slot is injected (0001:D3) by the module.\n", sites: []string{"1:cue-definition"}},
		{name: "spoken form", file: "a.md",
			in: "Per enhancement 0001 D3 the slot is injected.\n", sites: []string{"1:cue-definition"}},
		{name: "yaml value", file: "a.yaml",
			in: "rule: the slot is injected (0001:D3)\n", sites: []string{"1:cue-definition"}},
		{name: "one bad title holds back the phrase", file: "a.md",
			in: "x 0010:D4 and 0001:D3 y\n", sites: []string{"1:cue-definition"}},
		{name: "link text", file: "a.md",
			in: "x [0001:D3](/enhancements/0001/decisions/) y\n", sites: []string{"1:cue-definition"}},
		{name: "a title without a token is written", file: "a.md",
			in: "x 0010:D4 y\n", want: "x enhancement 0010 (" + Quoted(d4) + ") y\n"},
	})
	if got, bad := textForm(DefaultTitles(), nil, false); got != "" || bad != "" {
		t.Errorf("no citation: %q %q", got, bad)
	}
	for _, s := range []string{"C# is fine", "issue #12", "no token"} {
		if cueDefRe.MatchString(s) {
			t.Errorf("%q is no definition token", s)
		}
	}
	for _, s := range []string{"the #Module wires it", "#Component.#release slot", "(#Foo)"} {
		if !cueDefRe.MatchString(s) {
			t.Errorf("%q holds a definition token", s)
		}
	}
}

// Defect 7: a range or a contrast between requirements of one decision gives
// the title once, and the sentence stays valid.
func TestRequirementRange(t *testing.T) {
	d2, _ := DefaultTitles().Title("0013", 2)
	d3, _ := DefaultTitles().Title("0013", 1)
	one := "enhancement 0013 (" + Quoted(d2) + ")"
	runCases(t, []rewriteCase{
		{name: "R11 to R14", file: "a.md",
			in: "Use 0013:D2:R11 to R14 here.\n", want: "Use " + one + " here.\n"},
		{name: "R3 through R5", file: "a.md",
			in: "Use 0013:D2:R3 through R5 here.\n", want: "Use " + one + " here.\n"},
		{name: "R3 and R4", file: "a.md",
			in: "Use 0013:D2:R3 and R4 here.\n", want: "Use " + one + " here.\n"},
		{name: "R3, not R4", file: "a.md",
			in: "Use 0013:D2:R3, not R4, here.\n", want: "Use " + one + ", here.\n"},
		{name: "two full citations with to", file: "a.md",
			in: "Use 0013:D2:R3 to 0013:D2:R4 here.\n", want: "Use " + one + " here.\n"},
		{name: "two full citations with not", file: "a.md",
			in: "Use 0013:D2:R3, not 0013:D2:R4, here.\n", want: "Use " + one + ", here.\n"},
		{name: "two full citations with a dash", file: "a.md",
			in: "Use 0013:D2:R3 - 0013:D2:R4 here.\n", want: "Use " + one + " here.\n"},
		{name: "spoken pair", file: "a.md",
			in: "Use enhancement 0013 D2 or enhancement 0013 D2 here.\n", want: "Use " + one + " here.\n"},
		{name: "different decisions stay apart", file: "a.md",
			in:   "Use 0013:D2:R3 to 0013:D1:R1 here.\n",
			want: "Use " + one + " to enhancement 0013 (" + Quoted(d3) + ") here.\n"},
		{name: "code comment, parenthesis", file: "a.go",
			in:   "package a\n\n// Reads the limit (0013:D2:R3 to 0013:D2:R4).\nvar x = 1\n",
			want: "package a\n\n// Reads the limit (enhancement 0013).\nvar x = 1\n"},
		{name: "code comment, contrast at the end", file: "a.go",
			in:   "package a\n\n// Reads the limit, per 0013:D2:R3, not R4.\nvar x = 1\n",
			want: "package a\n\n// Reads the limit (enhancement 0013).\nvar x = 1\n"},
	})
}

// Defects 3 and 4: a wrapped Markdown paragraph is read line by line, but a
// line edge is a sentence edge only when the paragraph says so. Without that,
// "0030:D2:R5, a log stream)" at a line start lost its head, and a trailing
// ", 0030:D10" at a line end was cut off a list that went on below.
func TestWrappedLines(t *testing.T) {
	d4 := titleOf("0010", 4)
	runCases(t, []rewriteCase{
		{name: "line start after an open parenthesis stays", file: "a.md",
			in:    "a long-lived holder (the change stream of\n0030:D2:R5, a log stream) could read it.\n",
			sites: []string{"2:retired-inline"}},
		{name: "line start after an open clause stays", file: "a.md",
			in:    "The holder reads the stream of\n0030:D2:R5, a log stream, at once.\n",
			sites: []string{"2:retired-inline"}},
		{name: "list item at the line end stays", file: "a.md",
			in:    "Sources: 0030:D9 (events feed), 0030:D10\n(logs). Owner: the user.\n",
			sites: []string{"1:retired-inline", "1:retired-inline"}},
		{name: "phrase at a wrapped line end stays", file: "a.md",
			in: "The cache is read, per 0030:D4\nand then it is filled.\n", sites: []string{"1:retired-inline"}},
		{name: "parenthesis at a line start stays", file: "a.md",
			in: "The cache is read\n(0030:D4) and then it is filled.\n", sites: []string{"2:retired-inline"}},
		{name: "yaml block scalar, line end", file: "a.yaml",
			in: "doc: |\n  The cache is read, per 0030:D4\n  and then it is filled.\n", sites: []string{"2:retired-inline"}},
		{name: "full stop at the line end still removes", file: "a.md",
			in: "The cache is read, per 0030:D4.\nThen it is filled.\n", want: "The cache is read.\nThen it is filled.\n"},
		{name: "new sentence after a full stop still removes", file: "a.md",
			in: "The cache is read.\nPer 0030:D4, it is then filled.\n", want: "The cache is read.\nIt is then filled.\n"},
		{name: "list item line still removes", file: "a.md",
			in: "- The cache is read (0030:D4)\n- Then it is filled\n", want: "- The cache is read\n- Then it is filled\n"},
		{name: "blank line ends the paragraph", file: "a.md",
			in: "The cache is read, per 0030:D4\n\nThen it is filled.\n", want: "The cache is read\n\nThen it is filled.\n"},
		{name: "no capital on a continuation line", file: "a.md",
			in:   "The rule is stated in\n0010:D4 and holds.\n",
			want: "The rule is stated in\nenhancement 0010 (" + Quoted(d4) + ") and holds.\n"},
		{name: "capital after a full stop", file: "a.md",
			in:   "It holds.\n0010:D4 says so.\n",
			want: "It holds.\nEnhancement 0010 (" + Quoted(d4) + ") says so.\n"},
	})
}

// Defect 2, comments: a # comment of a shell or YAML file is a comment, as a
// // comment of Go is. It takes form 1 only (an id beside the words that are
// there), never a decision title.
func TestCommentForms(t *testing.T) {
	d4 := titleOf("0010", 4)
	runCases(t, []rewriteCase{
		{name: "shell comment, parenthesis", file: "run.sh",
			in:   "#!/bin/sh\n# Keep the filter (0002:D12).\necho hi\n",
			want: "#!/bin/sh\n# Keep the filter (enhancement 0002).\necho hi\n"},
		{name: "shell comment, per at the end", file: "run.sh",
			in:   "# Keep the filter, per 0002:D12.\n",
			want: "# Keep the filter (enhancement 0002).\n"},
		{name: "shell comment, wrapped paragraph", file: "run.sh",
			in:   "# Keep the filter, which\n# the check reads (0002:D12).\n",
			want: "# Keep the filter, which\n# the check reads (enhancement 0002).\n"},
		{name: "shell comment, two comments", file: "run.sh",
			in:   "# One (0002:D12).\n\n# Two (0010:D4).\n",
			want: "# One (enhancement 0002).\n\n# Two (enhancement 0010).\n"},
		{name: "shell comment, lone id", file: "run.sh",
			in: "# 0002:D12\n", sites: []string{"1:lone-id"}},
		{name: "shell comment, id inside the sentence", file: "run.sh",
			in: "# The 0002:D12 rule holds\n", sites: []string{"1:inline"}},
		{name: "shell code line is a string", file: "run.sh",
			in: "echo \"0010:D4\"\n", sites: []string{"1:string"}},
		{name: "shell comment, retired id", file: "run.sh",
			in:   "# Keep the filter (0030:D4).\n",
			want: "# Keep the filter.\n"},
		{name: "yaml full-line comment", file: "a.yaml",
			in:   "# Keep the filter (0002:D12).\nkey: value\n",
			want: "# Keep the filter (enhancement 0002).\nkey: value\n"},
		{name: "yaml trailing comment", file: "a.yaml",
			in:   "key: value # keep the filter (0002:D12)\n",
			want: "key: value # keep the filter (enhancement 0002)\n"},
		{name: "yaml value and comment on one line", file: "a.yaml",
			in:   "key: \"rule per 0010:D4\" # keep it (0002:D12)\n",
			want: "key: \"rule per enhancement 0010 (\\\"" + d4 + "\\\")\" # keep it (enhancement 0002)\n"},
		{name: "yaml hash inside a quoted value is no comment", file: "a.yaml",
			in:   "key: \"a # b (0010:D4)\"\n",
			want: "key: \"a # b (enhancement 0010, \\\"" + d4 + "\\\")\"\n"},
		{name: "yaml hash in a block scalar is text", file: "a.yaml",
			in:   "doc: |\n  # not a comment (0010:D4)\n",
			want: "doc: |\n  # not a comment (enhancement 0010, " + Quoted(d4) + ")\n"},
		{name: "go comment is unchanged", file: "a.go",
			in:   "package a\n\n// Keep it (0010:D4).\nvar x = 1\n",
			want: "package a\n\n// Keep it (enhancement 0010).\nvar x = 1\n"},
	})
}

// Defect 2, rule sentences: a paragraph with a rule keyword (SHALL, MUST,
// SHOULD, REQUIRED) in capitals already states the rule. A title does not go
// into it: the citation takes the shape of form 1, or the site is a worklist row.
func TestRuleSentence(t *testing.T) {
	d4 := titleOf("0010", 4)
	runCases(t, []rewriteCase{
		{name: "parenthesis", file: "a.md",
			in:   "The system SHALL reject a second write (0010:D4).\n",
			want: "The system SHALL reject a second write (enhancement 0010).\n"},
		{name: "per at the end", file: "a.md",
			in:   "The system MUST NOT write, per 0010:D4.\n",
			want: "The system MUST NOT write (enhancement 0010).\n"},
		{name: "keyword on the line above", file: "a.md",
			in:   "The system SHALL reject\na second write (0010:D4).\n",
			want: "The system SHALL reject\na second write (enhancement 0010).\n"},
		{name: "several ids", file: "a.md",
			in:   "The system SHOULD log it (0010:D4, 0011:D3).\n",
			want: "The system SHOULD log it (enhancements 0010 and 0011).\n"},
		{name: "shape does not fit: the id opens the sentence", file: "a.md",
			in: "Per 0010:D4 the system MUST reject it.\n", sites: []string{"1:rule-sentence"}},
		{name: "list item is its own paragraph", file: "a.md",
			in:   "- The system SHALL reject it (0010:D4)\n- Another note 0010:D4 holds.\n",
			want: "- The system SHALL reject it (enhancement 0010)\n- Another note enhancement 0010 (" + Quoted(d4) + ") holds.\n"},
		{name: "blank line ends the paragraph", file: "a.md",
			in:   "The system SHALL reject it.\n\nNote (0010:D4).\n",
			want: "The system SHALL reject it.\n\nNote (enhancement 0010, " + Quoted(d4) + ").\n"},
		{name: "lowercase must is no keyword", file: "a.md",
			in:   "A write must hold (0010:D4).\n",
			want: "A write must hold (enhancement 0010, " + Quoted(d4) + ").\n"},
		{name: "yaml value", file: "a.yaml",
			in:   "rule: The system SHALL reject it (0010:D4)\n",
			want: "rule: The system SHALL reject it (enhancement 0010)\n"},
		{name: "yaml flow sequence", file: "a.yaml",
			in: "rules: [The system SHALL reject it (0010:D4)]\n", sites: []string{"1:unsafe-yaml"}},
		{name: "yaml block scalar, keyword on another line", file: "a.yaml",
			in:   "rule: |\n  The system SHALL reject\n  a second write (0010:D4).\n",
			want: "rule: |\n  The system SHALL reject\n  a second write (enhancement 0010).\n"},
		{name: "yaml neighbour lines are separate", file: "a.yaml",
			in:   "a: The system SHALL reject it\nb: Note (0010:D4)\n",
			want: "a: The system SHALL reject it\nb: Note (enhancement 0010, " + Quoted(d4) + ")\n"},
		{name: "unknown decision in a rule", file: "a.md",
			in: "The system SHALL reject it (0010:D999).\n", sites: []string{"1:unknown-decision"}},
	})
}
