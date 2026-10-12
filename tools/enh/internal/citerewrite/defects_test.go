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
