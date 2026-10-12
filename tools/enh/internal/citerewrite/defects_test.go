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
