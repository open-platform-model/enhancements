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

var bareDRe = regexp.MustCompile(`(^|[^0-9A-Za-z_])D[0-9]+([^0-9A-Za-z_]|$)`)

var anyIDRe = regexp.MustCompile(`(^|[^0-9A-Za-z_])0[0-9]{3}([^0-9A-Za-z_]|$)`)

// Every title the tool can write passes the lint by itself (ruling 2026-10-11
// 23:45) and holds no enhancement id in any form (ruling 23:59): a rewrite
// never adds a decision number or a stray id. A long title is written in full:
// a short form exists only for a heading that holds an id.
func TestEveryEffectiveTitlePassesTheLint(t *testing.T) {
	tt := DefaultTitles()
	checked, retracted := 0, 0
	for id, byN := range tt.title {
		for n, heading := range byN {
			if tt.Retracted(id, n) {
				retracted++
				continue
			}
			rid, title, ok := tt.Effective(id, n)
			if !ok {
				t.Errorf("%s D%d has no effective title", id, n)
				continue
			}
			checked++
			if cs := cites.Scan(title); len(cs) > 0 {
				t.Errorf("%s D%d (%s): the title %q holds the citation %q", id, n, rid, title, cs[0].Text)
			}
			if _, isShort := tt.short[id][n]; isShort && bareDRe.MatchString(title) {
				t.Errorf("%s D%d: the short form %q holds a bare decision number", id, n, title)
			}
			if anyIDRe.MatchString(title) {
				t.Errorf("%s D%d (%s): the title %q holds an enhancement id", id, n, rid, title)
			}
			if strings.ContainsAny(title, "\n\t") {
				t.Errorf("%s D%d: the title holds a tab or a newline", id, n)
			}
			_, hasShort := tt.short[id][n]
			if tombstone(heading) {
				if hasShort {
					t.Errorf("%s D%d: a tombstone needs no short form", id, n)
				}
				continue
			}
			// A heading that holds an id has a short form; no other heading has one.
			holdsID := anyIDRe.MatchString(heading) || len(cites.Scan(heading)) > 0
			if holdsID && !hasShort {
				t.Errorf("%s D%d: the heading holds an id and needs a short form: %q", id, n, heading)
			}
			if !holdsID && hasShort {
				t.Errorf("%s D%d: a short form for a heading with no id (length is no reason): %q", id, n, heading)
			}
		}
	}
	if checked+retracted != 419 || retracted != 1 {
		t.Errorf("checked %d titles and %d retracted, want 418 and 1", checked, retracted)
	}
}

func tombstone(heading string) bool {
	return mergedRe.MatchString(heading) || movedRe.MatchString(heading)
}

func TestRetractedDecisionIsAWorklistRow(t *testing.T) {
	tt := DefaultTitles()
	if !tt.Retracted("0018", 12) {
		t.Fatal("0018 D12 is retracted")
	}
	got, sites := rewrite(t, "a.md", "Retracted per 0018:D12.\n")
	if got != "Retracted per 0018:D12.\n" || len(sites) != 1 || sites[0] != "1:retracted" {
		t.Errorf("got %q %v", got, sites)
	}
	got, sites = rewrite(t, "a.go", "package a\n\n// Retracted (0018:D12).\nvar x = 1\n")
	if len(sites) != 1 || sites[0] != "3:retracted" {
		t.Errorf("code: got %q %v", got, sites)
	}
}

func TestWorklistTitleNamesTheTarget(t *testing.T) {
	tt := DefaultTitles()
	res := Process("a.md", []byte("The rule 0025:D3's scope holds.\n"), tt)
	if len(res.Sites) != 1 || !strings.Contains(res.Sites[0].Title, "0025 D3 is 0027 D3: ") {
		t.Errorf("sites %+v", res.Sites)
	}
}

func TestResolveTombstones(t *testing.T) {
	tt := DefaultTitles()
	rid, title, ok := tt.Effective("0025", 3)
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
