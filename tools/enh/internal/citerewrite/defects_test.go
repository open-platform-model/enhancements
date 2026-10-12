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
