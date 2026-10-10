package record

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const cfg = `# Facts only.
id: "0100"
slug: demo
summary: >-
  A folded
  summary.
status: draft
affects:
  - core
  - cli

# trailing comment
authors:
- a@example.com
`

func TestSetKeys(t *testing.T) {
	t.Run("replace keeps comments and order", func(t *testing.T) {
		got, err := SetKeys(cfg, Edit{"status", "status: accepted"})
		if err != nil {
			t.Fatal(err)
		}
		want := strings.Replace(cfg, "status: draft", "status: accepted", 1)
		if got != want {
			t.Errorf("got:\n%s\nwant:\n%s", got, want)
		}
	})
	t.Run("replace a block value and its continuation", func(t *testing.T) {
		got, err := SetKeys(cfg, Edit{"summary", "summary: short"})
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(got, "A folded") || !strings.Contains(got, "summary: short\nstatus: draft") {
			t.Errorf("got:\n%s", got)
		}
	})
	t.Run("replace a list at column zero keeps the gap and the comment", func(t *testing.T) {
		got, err := SetKeys(cfg, Edit{"authors", "authors:\n  - b@example.com"})
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(got, "a@example.com") || !strings.HasSuffix(got, "authors:\n  - b@example.com\n") {
			t.Errorf("got:\n%s", got)
		}
		if !strings.Contains(got, "\n\n# trailing comment\n") {
			t.Errorf("the comment moved:\n%s", got)
		}
	})
	t.Run("add goes to the end", func(t *testing.T) {
		got, err := SetKeys(cfg, Edit{"accepted", `accepted: "2026-10-11 abc1234"`})
		if err != nil {
			t.Fatal(err)
		}
		if !strings.HasSuffix(got, "- a@example.com\naccepted: \"2026-10-11 abc1234\"\n") {
			t.Errorf("got:\n%s", got)
		}
	})
	t.Run("add after a file with no final newline", func(t *testing.T) {
		got, err := SetKeys("id: \"1\"", Edit{"status", "status: draft"})
		if err != nil || got != "id: \"1\"\nstatus: draft\n" {
			t.Errorf("got %q, %v", got, err)
		}
	})
	t.Run("a key that is a prefix of another is not matched", func(t *testing.T) {
		got, err := SetKeys("accepted_by: x\n", Edit{"accepted", "accepted: y"})
		if err != nil || got != "accepted_by: x\naccepted: y\n" {
			t.Errorf("got %q, %v", got, err)
		}
	})
	t.Run("a result that is not YAML is refused", func(t *testing.T) {
		if _, err := SetKeys(cfg, Edit{"status", "status: [unclosed"}); err == nil {
			t.Error("accepted broken YAML")
		}
	})
	t.Run("a bad key is refused", func(t *testing.T) {
		if _, err := SetKeys(cfg, Edit{"a b", "x"}); err == nil {
			t.Error("accepted a bad key")
		}
	})
}

func TestQuote(t *testing.T) {
	for in, want := range map[string]string{
		`plain`:        `"plain"`,
		`a "quoted"`:   `"a \"quoted\""`,
		`x: y # z`:     `"x: y # z"`,
		"two\nlines":   `"two\nlines"`,
		`<tag> & more`: `"<tag> & more"`,
	} {
		if got := Quote(in); got != want {
			t.Errorf("Quote(%q) = %s, want %s", in, got, want)
		}
	}
}

const tasks = `## 1. Core
- [ ] 1.1 core: add the thing
- [x] 1.2 cli: ship it (ship-it)

` + "```" + `
- [ ] 9.9 example: inside a fence
` + "```" + `
`

func TestTick(t *testing.T) {
	got, err := Tick(tasks, "1.1", "add-thing")
	if err != nil || !strings.Contains(got, "- [x] 1.1 core: add the thing (add-thing)\n") {
		t.Fatalf("got %q, %v", got, err)
	}
	if _, err := Tick(tasks, "1.2", "x"); !errors.Is(err, ErrTicked) {
		t.Errorf("already ticked: %v", err)
	}
	if _, err := Tick(tasks, "4.4", "x"); !errors.Is(err, ErrNoLine) {
		t.Errorf("unknown: %v", err)
	}
	if _, err := Tick(tasks, "9.9", "x"); !errors.Is(err, ErrNoLine) {
		t.Errorf("a line inside a fence is not a task: %v", err)
	}
	if _, err := Tick(tasks, "one", "x"); !errors.Is(err, ErrBadLine) {
		t.Errorf("bad number: %v", err)
	}
	// trailing space is dropped before the reference
	got, err = Tick("- [ ] 2.1 cli: do it  \n", "2.1", "PR 7")
	if err != nil || got != "- [x] 2.1 cli: do it (PR 7)\n" {
		t.Errorf("got %q, %v", got, err)
	}
}

func TestSetSampled(t *testing.T) {
	src := "# Source\n\n<!-- never by hand:\n\nsampled: <date> <commit>\n-->\n"
	got := SetSampled(src, "2026-10-11 abc1234")
	if strings.Count(got, "sampled:") != 1 || !strings.HasSuffix(got, "\n\nsampled: 2026-10-11 abc1234\n") {
		t.Errorf("got %q", got)
	}
	again := SetSampled(got, "2026-10-12 def5678")
	if strings.Count(again, "sampled:") != 1 || !strings.HasSuffix(again, "sampled: 2026-10-12 def5678\n") {
		t.Errorf("rewrite: %q", again)
	}
}

func TestWriteFile(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(p, []byte("old"), 0o640); err != nil {
		t.Fatal(err)
	}
	if err := WriteFile(p, []byte("new")); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(p)
	fi, _ := os.Stat(p)
	if string(b) != "new" || fi.Mode().Perm() != 0o640 {
		t.Errorf("content %q mode %v", b, fi.Mode())
	}
	left, _ := filepath.Glob(filepath.Join(dir, ".enh-*"))
	if len(left) != 0 {
		t.Errorf("temporary files left: %v", left)
	}
	if err := WriteFile(filepath.Join(dir, "no", "such", "x"), []byte("x")); err == nil {
		t.Error("write into a missing folder succeeded")
	}
}
