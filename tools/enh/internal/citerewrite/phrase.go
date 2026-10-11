package citerewrite

import (
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/cites"
)

// phrase is a run of citations that read as one: "0010:D4, 0011:D12" or
// "enhancement 0010 D4 and 0026 D1".
type phrase struct {
	cites []cites.Cite
	// start includes the lead word of the first citation; end is the end of
	// the last one.
	start, end int
	possessive bool
	path       bool
	oq         bool
}

var joinRe = regexp.MustCompile(`^(?:[ \t]*,[ \t]*and[ \t]+|[ \t]*[,;/&][ \t]*|[ \t]+and[ \t]+|[ \t]+or[ \t]+)$`)

func groupPhrases(text string, cs []cites.Cite) []phrase {
	var out []phrase
	for _, c := range cs {
		if n := len(out); n > 0 && !c.Path && !out[n-1].path {
			gap := text[out[n-1].end:c.LeadStart]
			if joinRe.MatchString(gap) {
				p := &out[n-1]
				p.cites = append(p.cites, c)
				p.end = c.End
				p.possessive = c.Possessive
				p.oq = p.oq || len(c.OQ) > 0
				continue
			}
		}
		out = append(out, phrase{cites: []cites.Cite{c}, start: c.LeadStart, end: c.End, possessive: c.Possessive, path: c.Path, oq: len(c.OQ) > 0})
	}
	return out
}

func isRetired(id string) bool { return id == "0030" || id == "0031" }

// splitRetired separates the citations of the withdrawn entries 0030 and 0031.
func splitRetired(cs []cites.Cite) (live, retired []cites.Cite) {
	for _, c := range cs {
		if isRetired(c.ID) {
			retired = append(retired, c)
		} else {
			live = append(live, c)
		}
	}
	return live, retired
}

// distinctIDs returns the ids of the citations once each, in order written.
func distinctIDs(cs []cites.Cite) []string {
	var out []string
	seen := map[string]bool{}
	for _, c := range cs {
		if !seen[c.ID] {
			seen[c.ID] = true
			out = append(out, c.ID)
		}
	}
	return out
}

// canonicalIDs writes ids beside the word "enhancement": "enhancement 0010",
// "enhancements 0010 and 0026", "enhancements 0010, 0019 and 0026".
func canonicalIDs(ids []string) string {
	switch len(ids) {
	case 0:
		return ""
	case 1:
		return "enhancement " + ids[0]
	case 2:
		return "enhancements " + ids[0] + " and " + ids[1]
	}
	return "enhancements " + strings.Join(ids[:len(ids)-1], ", ") + " and " + ids[len(ids)-1]
}

// joinWords joins items as "a", "a and b", "a, b and c".
func joinWords(items []string) string {
	switch len(items) {
	case 0:
		return ""
	case 1:
		return items[0]
	}
	return strings.Join(items[:len(items)-1], ", ") + " and " + items[len(items)-1]
}

// titleLine returns the decision titles of the citations, for a worklist row.
func titleLine(tt *Titles, cs []cites.Cite) string {
	var parts []string
	for _, c := range cs {
		for _, n := range c.Decisions {
			if t, ok := tt.Title(c.ID, n); ok {
				parts = append(parts, c.ID+" D"+itoa(n)+": "+t)
			}
		}
	}
	return strings.Join(parts, " | ")
}

// textForm renders live citations as prose (form 2): enhancement 0010
// ("title"), enhancement 0010 ("a" and "b"), enhancement 0010 ("a"), and so on.
// compact writes the single-id form for a parenthesis, without nested
// parentheses: enhancement 0010, "title". The second result names the kind of
// a failure.
func textForm(tt *Titles, cs []cites.Cite, compact bool) (string, string) {
	var ids []string
	byID := map[string][]int{}
	for _, c := range cs {
		if len(c.Decisions) == 0 {
			return "", KindOQ
		}
		if !tt.Known(c.ID) {
			return "", KindUnknownID
		}
		if _, ok := byID[c.ID]; !ok {
			ids = append(ids, c.ID)
		}
		for _, n := range c.Decisions {
			if _, ok := tt.Title(c.ID, n); !ok {
				return "", KindUnknownDec
			}
			byID[c.ID] = appendOnce(byID[c.ID], n)
		}
	}
	var parts []string
	for _, id := range ids {
		var titles []string
		for _, n := range byID[id] {
			t, _ := tt.Title(id, n)
			titles = append(titles, Quoted(t))
		}
		if compact && len(ids) == 1 {
			return "enhancement " + id + ", " + joinWords(titles), ""
		}
		parts = append(parts, "enhancement "+id+" ("+joinWords(titles)+")")
	}
	return joinWords(parts), ""
}

func appendOnce(xs []int, n int) []int {
	for _, x := range xs {
		if x == n {
			return xs
		}
	}
	return append(xs, n)
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b []byte
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	return string(b)
}

var (
	leadinRe = regexp.MustCompile(`(?i)(?:^|[\s(])(per|see|cf\.?|also)[ \t]+$`)
	listLead = regexp.MustCompile(`^\s*(?:[-*+>|#]+|\d+[.)])?\s*$`)
)

// extendLeadin moves a phrase start back over "per", "see", "cf." or "also".
func extendLeadin(text string, start int) int {
	m := leadinRe.FindStringSubmatchIndex(text[:start])
	if m == nil {
		return start
	}
	return m[2]
}

// sentenceStart reports whether pos begins a sentence: the start of the text,
// after a sentence end, or after a Markdown list, quote, heading or table mark.
func sentenceStart(text string, pos int) bool {
	before := strings.TrimRight(text[:pos], " \t")
	if listLead.MatchString(before) {
		return true
	}
	last := before[len(before)-1]
	return last == '.' || last == '!' || last == '?'
}

func startsUpper(s string) bool { return s != "" && s[0] >= 'A' && s[0] <= 'Z' }

func upperFirst(s string) string {
	if s != "" && s[0] >= 'a' && s[0] <= 'z' {
		return string(s[0]-32) + s[1:]
	}
	return s
}

func hasLetter(s string) bool {
	for _, r := range s {
		if r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r > 127 {
			return true
		}
	}
	return false
}

func trimBackSpaces(text string, i int) int {
	for i > 0 && (text[i-1] == ' ' || text[i-1] == '\t') {
		i--
	}
	return i
}

func skipSpaces(text string, i int) int {
	for i < len(text) && (text[i] == ' ' || text[i] == '\t') {
		i++
	}
	return i
}
