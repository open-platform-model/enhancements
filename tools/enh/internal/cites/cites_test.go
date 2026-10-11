package cites

import (
	"fmt"
	"reflect"
	"testing"
)

func TestScan(t *testing.T) {
	for _, tc := range []struct {
		name, text string
		// want is "text|id|decisions|oq|flags" per citation; flags are s (spoken), p (possessive), P (path)
		want []string
	}{
		{"colon", "see 0010:D11 here", []string{"0010:D11|0010|[11]|[]|"}},
		{"colon with requirement", "x (0010:D4:R1/R2).", []string{"0010:D4:R1/R2|0010|[4]|[]|"}},
		{"requirement range", "(0030:D7:R2-R4)", []string{"0030:D7:R2-R4|0030|[7]|[]|"}},
		{"requirement list", "0030:D8:R1/R2/R3, 0030:D2:R4.", []string{"0030:D8:R1/R2/R3|0030|[8]|[]|", "0030:D2:R4|0030|[2]|[]|"}},
		{"open question", "0014:OQ2 is open", []string{"0014:OQ2|0014|[]|[2]|"}},
		{"slash list", "0011 D3/D15 apply", []string{"0011 D3/D15|0011|[3 15]|[]|s"}},
		{"colon slash question", "0006:D21/OQ12", []string{"0006:D21/OQ12|0006|[21]|[12]|"}},
		{"and list", "enhancement 0010 D4 and D7 hold", []string{"0010 D4 and D7|0010|[4 7]|[]|s"}},
		{"comma list", "Enhancement 0010:D43, D45 deleted", []string{"0010:D43, D45|0010|[43 45]|[]|"}},
		{"two ids stay two", "(0010:D4, 0011:D12)", []string{"0010:D4|0010|[4]|[]|", "0011:D12|0011|[12]|[]|"}},
		{"spoken in parentheses", "Version filing (0010 D49)", []string{"0010 D49|0010|[49]|[]|s"}},
		{"spoken with comma", "enhancement 0015, D9", []string{"0015, D9|0015|[9]|[]|s"}},
		{"spoken slash", "0010/D4 rule", []string{"0010/D4|0010|[4]|[]|"}},
		{"possessive", "0010:D30's denylist", []string{"0010:D30|0010|[30]|[]|p"}},
		{"backticks around all", "a `0010:D4` b", []string{"`0010:D4`|0010|[4]|[]|"}},
		{"backticks around id", "a `0010` D4 b", []string{"`0010` D4|0010|[4]|[]|s"}},
		{"path with decisions", "in `enhancements/0010` D1, D6 and D8", []string{"0010` D1, D6 and D8|0010|[1 6 8]|[]|sP"}},
		{"path dash", "`enhancements/0010` — D14, D28", []string{"0010` — D14, D28|0010|[14 28]|[]|sP"}},
		{"duplicates collapse", "0010:D4 and D4", []string{"0010:D4 and D4|0010|[4]|[]|"}},
		// not citations
		{"year and D", "released 2026 D4 here", nil},
		{"date", "on 2026-10-11 D4", nil},
		{"version", "v1.0010 D3 and v0.0010:D3", nil},
		{"no decision", "enhancement 0010 and (enhancements 0010 and 0026)", nil},
		{"id inside number", "10010 D4 and 00100 D4", nil},
		{"D with letters", "0010 Dx and 0010:D4x", nil},
		{"portal head", "portal:D4 and portal:D12:R1", nil},
		{"hex-like word", "abc0010 D4", nil},
		{"path only", "enhancements/0010/ and enhancements/0019/schemas/target.cue", nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var got []string
			for _, c := range Scan(tc.text) {
				flags := ""
				if c.Spoken {
					flags += "s"
				}
				if c.Possessive {
					flags += "p"
				}
				if c.Path {
					flags += "P"
				}
				if c.Text != tc.text[c.Start:c.End] {
					t.Errorf("Text %q does not match the range", c.Text)
				}
				got = append(got, fmt.Sprintf("%s|%s|%v|%v|%s", c.Text, c.ID, c.Decisions, c.OQ, flags))
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("Scan(%q)\n got %q\nwant %q", tc.text, got, tc.want)
			}
		})
	}
}

func TestLead(t *testing.T) {
	text := "per Enhancement 0010:D43 and enhancements 0011 D3."
	cs := Scan(text)
	if len(cs) != 2 {
		t.Fatalf("got %d cites", len(cs))
	}
	if cs[0].Lead(text) != "Enhancement" || text[cs[0].LeadStart:cs[0].End] != "Enhancement 0010:D43" {
		t.Errorf("lead of first: %q", text[cs[0].LeadStart:cs[0].End])
	}
	if cs[1].Lead(text) != "enhancements" {
		t.Errorf("lead of second: %q", cs[1].Lead(text))
	}
	plain := "so 0010:D4 holds"
	if c := Scan(plain)[0]; c.Lead(plain) != "" || c.LeadStart != c.Start {
		t.Errorf("no lead expected")
	}
}

func TestScanParenthesisedDecisions(t *testing.T) {
	text := "Core shipped the contract of enhancement 0019 (D20, D21, D23): the types."
	cs := Scan(text)
	if len(cs) != 1 || cs[0].Text != "0019 (D20, D21, D23)" || !reflect.DeepEqual(cs[0].Decisions, []int{20, 21, 23}) {
		t.Fatalf("got %+v", cs)
	}
	if got := Scan("see 0019 (D20 and more)"); len(got) != 0 {
		t.Errorf("an unclosed list is not a citation: %+v", got)
	}
}
