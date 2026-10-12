package citerewrite

import (
	"regexp"
	"strings"
)

// The withdrawn entries 0030 and 0031 lose their id and keep the reason text
// (DECISIONS.md 2026-10-10 18:15 Q1). removal says how to delete one phrase of
// their citations so that the text and its punctuation stay valid.

var (
	afterLabelRe = regexp.MustCompile(`^[ \t]*[,:;][ \t]+`)
	endRe        = regexp.MustCompile(`^[ \t]*\.?[ \t]*$`)
	endSentRe    = regexp.MustCompile(`^[ \t]*\.[ \t]+\S`)
	sourceRe     = regexp.MustCompile(`(?i)\bsources?:[ \t]*$`)
)

// removal is the edit that deletes the phrase text[ps:pe] from text. ok is
// false when no safe deletion exists; lone is true when nothing readable
// would be left.
//
// A source line is not always a whole sentence: in a wrapped Markdown
// paragraph the line start follows a sentence that goes on from the line above
// (prevCont) and the line end goes on below (nextCont). Neither edge is then a
// sentence edge, and a deletion that needs one is not safe.
func removal(text string, ps, pe int, prevCont, nextCont bool) (rs, re int, repl string, ok, lone bool) {
	ls := extendLeadin(text, ps)
	b := trimBackSpaces(text, ls)
	a := skipSpaces(text, pe)
	ss := func(pos int) bool { return sentenceStartAt(text, pos, prevCont) }
	atEnd := func(rest string) bool {
		if endSentRe.MatchString(rest) {
			return true
		}
		return endRe.MatchString(rest) && (!nextCont || strings.Contains(rest, "."))
	}

	left := func(rs, re int) string { return text[:rs] + text[re:] }

	// P1: the phrase is the whole content of a parenthesis.
	if b > 0 && text[b-1] == '(' && a < len(text) && text[a] == ')' {
		open, closeAt := b-1, a
		if strings.TrimSpace(text[:open]) == "" && prevCont {
			// The parenthesis opens a line that goes on from the line above.
			return 0, 0, "", false, false
		}
		if ss(open) {
			if closeAt+1 < len(text) && strings.ContainsRune(".,;:)", rune(text[closeAt+1])) {
				// A wrapped line that opens with the parenthesis: the sentence
				// it ends is on the line above.
				return 0, 0, "", false, false
			}
			rs, re = open, skipSpaces(text, closeAt+1)
			if !hasLetter(left(rs, re)) {
				return 0, 0, "", false, true
			}
			return capitalise(text, rs, re)
		}
		rs, re = trimBackSpaces(text, open), closeAt+1
		return rs, re, "", true, false
	}

	// P2: a lead word or a label, then a comma, colon or semicolon.
	if m := afterLabelRe.FindString(text[pe:]); m != "" && pe+len(m) < len(text) {
		if ls != ps || ss(ps) {
			rs, re = ls, pe+len(m)
			if rs > 0 && !ss(rs) {
				before := strings.TrimRight(text[:rs], " \t")
				if strings.HasSuffix(before, ",") {
					// "foo, per X, bar": keep the comma that precedes the phrase.
					return rs, re, "", true, false
				}
				// "foo per X; bar": the clause break stays, only the phrase goes.
				return trimBackSpaces(text, ls), pe, "", true, false
			}
			return capitalise(text, rs, re)
		}
	}

	// P3: the phrase ends the sentence.
	if atEnd(text[pe:]) {
		if loc := sourceRe.FindStringIndex(text[:ls]); loc != nil && loc[1] == len(text[:ls]) {
			rs = trimBackSpaces(text, loc[0])
			if !hasLetter(left(rs, pe)) {
				return 0, 0, "", false, true
			}
			if rs == 0 || !strings.ContainsAny(text[rs-1:rs], ".!?") {
				// The label does not follow a finished sentence.
				return 0, 0, "", false, false
			}
			// The label has its own full stop; keep one stop only.
			re = pe
			if i := skipSpaces(text, pe); i < len(text) && text[i] == '.' {
				re = i + 1
			}
			return rs, re, "", true, false
		}
		if b > 0 && (text[b-1] == ',' || text[b-1] == ';') {
			return trimBackSpaces(text, b-1), pe, "", true, false
		}
		if ls != ps || ls < ps {
			return trimBackSpaces(text, ls), pe, "", true, false
		}
	}
	return 0, 0, "", false, false
}

// capitalise finishes a deletion at the start of a sentence: the next letter
// becomes a capital.
func capitalise(text string, rs, re int) (int, int, string, bool, bool) {
	if re < len(text) && text[re] >= 'a' && text[re] <= 'z' {
		return rs, re + 1, string(text[re] - 32), true, false
	}
	return rs, re, "", true, false
}
