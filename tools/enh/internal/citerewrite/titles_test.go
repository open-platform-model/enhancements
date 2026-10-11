package citerewrite

import "testing"

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
