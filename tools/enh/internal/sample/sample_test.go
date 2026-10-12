package sample

import (
	"math"
	"reflect"
	"testing"
)

func TestCount(t *testing.T) {
	for n, want := range map[int]int{0: 0, 1: 1, 2: 2, 3: 3, 4: 3, 8: 3, 30: 3, 31: 4, 32: 4, 40: 4, 41: 5, 100: 10, 101: 11} {
		if got := Count(n); got != want {
			t.Errorf("Count(%d) = %d, want %d", n, got, want)
		}
	}
}

func TestDraw(t *testing.T) {
	a := Draw(31, 4, 42)
	if len(a) != 4 {
		t.Fatalf("len = %d", len(a))
	}
	if !reflect.DeepEqual(a, Draw(31, 4, 42)) {
		t.Error("the same seed gave a different draw")
	}
	if reflect.DeepEqual(a, Draw(31, 4, 43)) && reflect.DeepEqual(a, Draw(31, 4, 44)) {
		t.Error("three seeds gave one draw")
	}
	seen := map[int]bool{}
	for i, v := range a {
		if v < 0 || v >= 31 || seen[v] || (i > 0 && a[i-1] >= v) {
			t.Errorf("draw %v is not ascending, distinct and in range", a)
		}
		seen[v] = true
	}
	if got := Draw(2, 3, 1); !reflect.DeepEqual(got, []int{0, 1}) {
		t.Errorf("k above n: %v", got)
	}
	if Draw(0, 3, 1) != nil || Draw(5, 0, 1) != nil {
		t.Error("an empty draw is not nil")
	}
	// every position is reachable
	hit := map[int]bool{}
	for s := uint64(0); s < 200; s++ {
		for _, v := range Draw(10, 3, s) {
			hit[v] = true
		}
	}
	if len(hit) != 10 {
		t.Errorf("only %d of 10 positions drawn in 200 seeds", len(hit))
	}
}

func TestNewSeedDiffers(t *testing.T) {
	a, err1 := NewSeed()
	b, err2 := NewSeed()
	if err1 != nil || err2 != nil || a == b {
		t.Errorf("seeds %d %d (%v %v)", a, b, err1, err2)
	}
}

func TestWordsAndJaccard(t *testing.T) {
	w := Words("The render SHALL refuse a Module, and the render is refused 2 times!")
	for _, want := range []string{"render", "refuse", "module", "refused", "times"} {
		if _, ok := w[want]; !ok {
			t.Errorf("missing %q in %v", want, w)
		}
	}
	for _, stop := range []string{"the", "shall", "and", "is", "a", "2"} {
		if _, ok := w[stop]; ok {
			t.Errorf("%q should be dropped", stop)
		}
	}
	a, b := Words("alpha beta gamma"), Words("beta gamma delta epsilon")
	score, shared := Jaccard(a, b)
	if shared != 2 || math.Abs(score-2.0/5.0) > 1e-9 {
		t.Errorf("score %v shared %d", score, shared)
	}
	if s, n := Jaccard(a, Words("")); s != 0 || n != 0 {
		t.Errorf("empty = %v %d", s, n)
	}
	if s, _ := Jaccard(a, a); s != 1 {
		t.Errorf("identical = %v", s)
	}
}

func TestNearest(t *testing.T) {
	target := Req{"new", "Render records versions", "A render records the versions of every catalog path it held."}
	universe := []Req{
		{"a", "Render records versions", "Same words: a render records the versions of every catalog path it held."},
		{"a", "Unrelated", "The operator reports readiness."},
		{"b", "Catalog path versions", "Every catalog path has versions the render held."},
		{"c", "Third", "A render records something."},
		{"d", "Fourth", "Catalog path."},
		{"new", "Render records versions", "the target itself"},
	}
	got := Nearest(target, universe, nil, 3)
	if len(got) != 3 || got[0].ID() != "a/Render records versions" || got[0].Score <= got[1].Score {
		t.Fatalf("nearest = %+v", got)
	}
	for _, g := range got {
		if g.ID() == target.ID() {
			t.Error("the requirement is its own neighbour")
		}
	}
	skipped := Nearest(target, universe, func(r Req) bool { return r.Capability == "a" }, 3)
	for _, g := range skipped {
		if g.Capability == "a" {
			t.Errorf("a skipped requirement is listed: %+v", g)
		}
	}
	// a tie goes to the lower id, and fewer than n is fine
	tie := Nearest(Req{"x", "T", "alpha beta"}, []Req{{"z", "B", "alpha beta"}, {"y", "A", "alpha beta"}}, nil, 3)
	if len(tie) != 2 || tie[0].ID() != "y/A" {
		t.Errorf("tie = %+v", tie)
	}
	if Nearest(target, nil, nil, 3) != nil {
		t.Error("empty universe")
	}
}
