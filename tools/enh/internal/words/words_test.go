package words

import "testing"

func TestCount(t *testing.T) {
	tests := []struct {
		name string
		md   string
		want int
	}{
		{"plain words", "one two three", 3},
		{"heading not counted", "# Title here\n\nbody text", 2},
		{"list markers not counted", "- one two\n- three\n1. four\n- [ ] five\n- [x] six", 6},
		{"table pipes not counted", "| a | b |\n|---|---|\n| c d | e |", 5},
		{"comment not counted", "keep <!-- gone away\nmore --> this", 2},
		{"fenced code not counted", "before\n```mermaid\nflowchart LR\n  a --> b\n```\nafter", 2},
		{"tilde fence", "x\n~~~\ncode code\n~~~\ny", 2},
		{"front matter not counted", "---\ntitle: a b c\n---\nreal words", 2},
		{"emphasis and code marks", "**bold** and `code` and *it*", 5},
		{"link counts its text", "see [the docs](https://example.com/a/b) now", 4},
		{"quote mark", "> quoted text", 2},
		{"loose punctuation", "a -- b - c", 3},
		{"empty", "", 0},
		{"windows line ends", "a b\r\nc d", 4},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := Count(tc.md); got != tc.want {
				t.Errorf("Count(%q) = %d, want %d", tc.md, got, tc.want)
			}
		})
	}
}

func TestCountExcluding(t *testing.T) {
	md := "# T\n\nintro words\n\n## Why\n\nfour words are here\n\n## Open questions\n\n- Blocking: a b c d e f\n"
	if got, want := CountExcluding(md, "Open questions"), 6; got != want {
		t.Errorf("CountExcluding = %d, want %d", got, want)
	}
	if got, want := CountExcluding(md), 13; got != want {
		t.Errorf("CountExcluding without skip = %d, want %d", got, want)
	}
}

func TestSectionsIgnoresFencedHeadings(t *testing.T) {
	md := "pre\n## A\nx\n```\n## not a heading\n```\n## B\ny"
	pre, secs := Sections(md)
	if pre != "pre" || len(secs) != 2 || secs[0].Name != "A" || secs[1].Name != "B" {
		t.Fatalf("got pre=%q secs=%+v", pre, secs)
	}
	if secs[0].Line != 2 {
		t.Errorf("line = %d, want 2", secs[0].Line)
	}
}

func TestFenceMaskLongerCloser(t *testing.T) {
	lines := []string{"````", "```", "inner", "```", "````", "out"}
	mask := FenceMask(lines)
	for i := 0; i < 5; i++ {
		if !mask[i] {
			t.Errorf("line %d should be inside the fence", i)
		}
	}
	if mask[5] {
		t.Error("line 5 should be outside")
	}
}
