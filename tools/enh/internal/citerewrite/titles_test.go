package citerewrite

import (
	"regexp"
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/cites"
)

func TestDefaultTitles(t *testing.T) {
	tt := DefaultTitles()
	// Design T2.3 section 9.2 says 419 decisions; the table holds the same.
	if tt.Count() != 419 || tt.Entries() != 27 {
		t.Fatalf("count=%d entries=%d, want 419 and 27", tt.Count(), tt.Entries())
	}
	archived := 0
	for _, id := range tt.IDs() {
		if tt.Archived(id) {
			archived++
		}
	}
	if archived != 10 {
		t.Errorf("%d archived entries, want 10", archived)
	}
	for id, want := range map[string]bool{"0010": true, "0019": true, "0013": false, "0027": false} {
		if tt.Archived(id) != want {
			t.Errorf("Archived(%s) = %v", id, !want)
		}
	}
	if tt.Known("0000") || tt.Known("0030") {
		t.Errorf("0000 is the template and 0030 was withdrawn: neither is an entry")
	}
	got, ok := tt.Title("0013", 1)
	if !ok || got != "A sensitive field is marked with a CUE field attribute, not typed with a contract struct" {
		t.Errorf("0013 D1 = %q, %v", got, ok)
	}
	if _, ok := tt.Title("0013", 9999); ok {
		t.Errorf("a missing decision has no title")
	}
}

func TestParseTitlesErrors(t *testing.T) {
	if _, err := ParseTitles("0010\tx\tlive\ttitle\n"); err == nil {
		t.Error("a bad decision number is an error")
	}
	if _, err := ParseTitles("0010\t1\tlive\n"); err == nil {
		t.Error("a short row is an error")
	}
}

func TestQuoted(t *testing.T) {
	if got := Quoted(`say "hi"`); got != `"say 'hi'"` {
		t.Errorf("got %s", got)
	}
}

// Every title the tool can write passes the lint by itself (ruling 2026-10-11
// 23:45): no citation inside it, so a rewrite never adds a decision number.
func TestEveryEffectiveTitlePassesTheLint(t *testing.T) {
	tt := DefaultTitles()
	checked := 0
	for id, byN := range tt.title {
		for n, heading := range byN {
			rid, title, ok := tt.Effective(id, n)
			if !ok {
				t.Errorf("%s D%d has no effective title", id, n)
				continue
			}
			checked++
			if cs := cites.Scan(title); len(cs) > 0 {
				t.Errorf("%s D%d (%s): the title %q holds the citation %q", id, n, rid, title, cs[0].Text)
			}
			if strings.Contains(title, "\n") || strings.Contains(title, "\t") {
				t.Errorf("%s D%d: the title holds a tab or a newline", id, n)
			}
			// A heading that is no tombstone and is long or holds a citation needs a short form.
			if _, _, moved := tombstone(heading); moved {
				continue
			}
			_, hasShort := tt.short[id][n]
			if (len(heading) > 110 || len(cites.Scan(heading)) > 0) && !hasShort {
				t.Errorf("%s D%d: the heading (%d characters) needs a short form", id, n, len(heading))
			}
		}
	}
	if checked != 419 {
		t.Errorf("checked %d titles, want 419", checked)
	}
	// A short form is a hand-written file: it names real decisions, holds no id, and is shorter.
	for id, byN := range tt.short {
		for n, s := range byN {
			if len(s) >= len(tt.title[id][n]) {
				t.Errorf("%s D%d: the short form is not shorter than the heading", id, n)
			}
			if regexp.MustCompile(`\b0[0-9]{3}\b`).MatchString(s) {
				t.Errorf("%s D%d: the short form holds an id: %q", id, n, s)
			}
		}
	}
}

func tombstone(heading string) (string, int, bool) {
	if mergedRe.MatchString(heading) || movedRe.MatchString(heading) {
		return heading, 0, true
	}
	return "", 0, false
}

func TestResolveTombstones(t *testing.T) {
	tt := DefaultTitles()
	rid, title, ok := tt.Effective("0025", 3)
	want, _, _ := tt.Effective("0027", 3)
	_ = want
	if !ok || rid != "0027" {
		t.Fatalf("0025 D3 resolves to %s, %v", rid, ok)
	}
	if _, wantTitle, _ := tt.Effective("0027", 3); title != wantTitle {
		t.Errorf("0025 D3 title %q, want the title of 0027 D3 %q", title, wantTitle)
	}
	rid, _, ok = tt.Effective("0010", 12)
	if !ok || rid != "0010" {
		t.Errorf("0010 D12 (merged into D10) resolves to %s, %v", rid, ok)
	}
	if _, _, ok := tt.Effective("0010", 9999); ok {
		t.Error("a missing decision has no effective title")
	}
	if got, _, _ := tt.Effective("0012", 1); got != "0012" {
		t.Errorf("0012 D1 stays in 0012: %s", got)
	}
	if _, s, _ := tt.Effective("0012", 1); strings.Contains(s, "0006") {
		t.Errorf("0012 D1 short form holds an id: %q", s)
	}
}
