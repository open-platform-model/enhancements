package citerewrite

import (
	"regexp"
	"strings"
)

// An id that the text already names must not be written again beside the same
// words: "introduced by enhancement 0001 (enhancement 0001)". The engines ask
// repeats before they write an id.

var sentenceEndRe = regexp.MustCompile(`[.!?]\s+(?:[A-Z0-9(` + "`" + `"'*-]|$)`)

// sentenceBounds returns the part [s, e) of text that is the sentence around
// [ps, pe). A sentence ends at a full stop, a question mark or an exclamation
// mark, followed by blanks and a capital, a digit or an opening mark.
func sentenceBounds(text string, ps, pe int) (int, int) {
	s, e := 0, len(text)
	for _, m := range sentenceEndRe.FindAllStringIndex(text, -1) {
		switch {
		case m[0]+1 <= ps:
			s = m[0] + 1
		case m[0] >= pe:
			if m[0]+1 < e {
				e = m[0] + 1
			}
			return s, e
		}
	}
	return s, e
}

func wordByte(b byte) bool {
	return b >= '0' && b <= '9' || b >= 'a' && b <= 'z' || b >= 'A' && b <= 'Z' || b == '_'
}

// plainMention reports whether text[s:e] names id outside every span of spans:
// a bare "0001" or "enhancement 0001". A part of a path or version does not count.
func plainMention(text string, s, e int, spans [][2]int, id string) bool {
	for from := s; ; {
		i := strings.Index(text[from:e], id)
		if i < 0 {
			return false
		}
		i += from
		from = i + len(id)
		if i > 0 && (wordByte(text[i-1]) || strings.IndexByte("./-@$%", text[i-1]) >= 0) {
			continue
		}
		if from < len(text) && wordByte(text[from]) {
			continue
		}
		inside := false
		for _, sp := range spans {
			inside = inside || i >= sp[0] && from <= sp[1]
		}
		if !inside {
			return true
		}
	}
}

// repeats says which of ids the sentence around phrase i already names: in
// plain words, or in an earlier phrase of the same sentence (which keeps its
// id). The phrases phs are those of text.
func repeats(text string, phs []phrase, i int, ids []string) (named []bool, any, all bool) {
	ph := phs[i]
	s, e := sentenceBounds(text, ph.start, ph.end)
	var spans [][2]int
	for _, p := range phs {
		spans = append(spans, [2]int{p.start, p.end})
	}
	named = make([]bool, len(ids))
	all = len(ids) > 0
	for k, id := range ids {
		named[k] = plainMention(text, s, e, spans, id)
		for j := 0; j < i && !named[k]; j++ {
			if phs[j].start < s || phs[j].end > e {
				continue
			}
			for _, c := range phs[j].cites {
				named[k] = named[k] || c.ID == id
			}
		}
		any = any || named[k]
		all = all && named[k]
	}
	return named, any, all
}

// dropEdit turns the form 1 edit e of a phrase into a deletion of the phrase,
// for a phrase whose ids the sentence names already. ok is false when the
// shape allows no safe deletion.
func dropEdit(text string, e Edit) (Edit, bool) {
	switch {
	case strings.HasPrefix(e.New, " ("):
		// ", per X." became " (enhancement N)."
		return Edit{Start: e.Start, End: e.End, New: "", Form: e.Form}, true
	case e.Start > 0 && text[e.Start-1] == '(' && e.End < len(text) && text[e.End] == ')':
		start := trimBackSpaces(text, e.Start-1)
		if start == 0 {
			return Edit{}, false
		}
		return Edit{Start: start, End: e.End + 1, New: "", Form: e.Form}, true
	}
	return Edit{}, false
}
