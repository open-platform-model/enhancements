// Package cites finds the citations of an enhancement decision in plain text:
// the colon form (0010:D4, 0010:D4:R1/R2, 0010:OQ2) and the spoken form
// (enhancement 0010 D4, (0010 D49), 0011 D3/D15, 0010 D4 and D7). Both are
// decision numbers. The lint (internal/citelint) and the rewrite tool
// (internal/citerewrite) share this grammar, so that what one removes the
// other no longer finds.
package cites

import (
	"regexp"
	"strconv"
	"strings"
)

// Cite is one citation: an id and the decisions or open questions it names.
type Cite struct {
	// Start and End are byte offsets in the scanned text. The range holds the
	// backticks that wrap the citation, and not the lead word or a possessive.
	Start, End int
	// LeadStart is the start of an "enhancement " or "enhancements " lead
	// word in front of the citation; it equals Start when there is none.
	LeadStart int
	// ID is the four-digit id.
	ID string
	// Decisions lists the decision numbers in the order written, once each.
	Decisions []int
	// OQ lists the open-question numbers.
	OQ []int
	// Spoken is true when the id is not followed by a colon.
	Spoken bool
	// Possessive is true when "'s" follows the citation.
	Possessive bool
	// Path is true when the citation reads "enhancements/NNNN" plus decisions.
	Path bool
	// Glued is true when the citation sits in a longer token: a letter, a
	// digit or an underscore follows it (0010:D4x), or a hyphen, dot or slash
	// joins it to the word before (PRE-0010:D41). It is a decision number
	// for the lint, and no safe rewrite exists.
	Glued bool
	// Text is text[Start:End].
	Text string
}

// Lead returns the lead word as written, or "".
func (c Cite) Lead(text string) string { return strings.TrimRight(text[c.LeadStart:c.Start], " \t") }

var (
	idRe = regexp.MustCompile("[0-9]{4}")

	// partRe reads one decision or question: D4, D4:R1/R2, OQ2.
	partRe = regexp.MustCompile(`^(?:D([0-9]+)(?::R[0-9]+(?:(?:/|-)R?[0-9]+|,[ \t]*R[0-9]+)*)*|OQ([0-9]+))`)

	// moreRe reads the joiner of a further decision of the same id.
	moreRe = regexp.MustCompile(`^(?:,[ \t]+and[ \t]+|,[ \t]*|[ \t]+and[ \t]+|[ \t]*&[ \t]*|/)`)

	leadRe = regexp.MustCompile(`(?i)enhancements?[ \t]+$`)
)

// idStartOK reports whether the character before an id may precede one. A
// digit, a letter, a dot, a hyphen, an underscore or a slash makes the number
// part of a longer token (a version, a date, a path).
func idStartOK(b byte) bool {
	switch {
	case b >= '0' && b <= '9', b >= 'a' && b <= 'z', b >= 'A' && b <= 'Z':
		return false
	}
	switch b {
	case '.', '-', '_', '/', '@', '$', '%':
		return false
	}
	return true
}

// lenientStartOK is the old lint rule: only a letter, a digit or an
// underscore in front makes the number part of a longer token.
func lenientStartOK(b byte) bool {
	return !(b >= '0' && b <= '9' || b >= 'a' && b <= 'z' || b >= 'A' && b <= 'Z' || b == '_')
}

func wordEnd(s string, i int) bool {
	if i >= len(s) {
		return true
	}
	c := s[i]
	return !(c >= '0' && c <= '9' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '_')
}

// Scan returns the citations of text in order.
func Scan(text string) []Cite {
	var out []Cite
	next := 0
	prevEnd := -1 // end of the last citation: a slash right after it joins two citations
	for _, loc := range idRe.FindAllStringIndex(text, -1) {
		s, e := loc[0], loc[1]
		if s < next {
			continue
		}
		path := false
		if s > 0 {
			p := text[s-1]
			if p == '/' && strings.HasSuffix(text[:s], "enhancements/") {
				path = true
			} else if !lenientStartOK(p) {
				continue
			}
		}
		if !wordEnd(text, e) && text[e] != ':' {
			continue
		}
		if e < len(text) && text[e] >= '0' && text[e] <= '9' {
			continue
		}
		c, end, ok := parse(text, s, e, path)
		if !ok {
			continue
		}
		// The colon form keeps the old rule (a hyphen or a dot before it is
		// fine: PRE-0010:D41). The spoken form must not sit in a longer token
		// such as a version or a date.
		if c.Spoken && !path && (c.ID[0] != '0' || s > 0 && !idStartOK(text[s-1])) {
			continue
		}
		if !c.Spoken && end < len(text) && !wordEnd(text, end) {
			c.Glued = true
		}
		if !path && s > 0 && (text[s-1] == '-' || text[s-1] == '.' || text[s-1] == '/' && s-1 != prevEnd || text[s-1] == '@' || text[s-1] == '$' || text[s-1] == '%') {
			c.Glued = true
		}
		out = append(out, c)
		next = end
		prevEnd = end
	}
	return out
}

// parse reads the tail of a citation whose id is text[s:e].
func parse(text string, s, e int, path bool) (Cite, int, bool) {
	c := Cite{ID: text[s:e], Start: s}
	// A backtick in front belongs to the citation when one closes it.
	open := s > 0 && text[s-1] == '`'
	i := e
	closed := false
	paren := false
	if open && i < len(text) && text[i] == '`' {
		closed = true
		i++
	}
	if path && !open && i < len(text) && text[i] == '`' {
		// enhancements/0010` D4: the path closes its code span first.
		i++
		closed = true
		for i < len(text) && (text[i] == ' ' || text[i] == '\t') {
			i++
		}
		for _, dash := range []string{"\u2014", "\u2013", "-", ":", ","} {
			if strings.HasPrefix(text[i:], dash) {
				i += len(dash)
				break
			}
		}
		for i < len(text) && (text[i] == ' ' || text[i] == '\t') {
			i++
		}
		c.Spoken = true
		goto parts
	}
	switch {
	case i < len(text) && text[i] == ':':
		i++
	case i < len(text) && (text[i] == '/' || text[i] == ','):
		if text[i] == '/' {
			i++
		} else {
			i++
			for i < len(text) && (text[i] == ' ' || text[i] == '\t') {
				i++
			}
			c.Spoken = true
		}
	case i < len(text) && (text[i] == ' ' || text[i] == '\t'):
		for i < len(text) && (text[i] == ' ' || text[i] == '\t') {
			i++
		}
		if i+1 < len(text) && text[i] == '(' && partRe.MatchString(text[i+1:]) {
			// 0019 (D20, D21, D23): the decisions in a parenthesis.
			i++
			paren = true
		}
		c.Spoken = true
	default:
		return c, 0, false
	}
	if path {
		c.Spoken = true
	}
parts:
	first := true
	for {
		m := partRe.FindStringSubmatch(text[i:])
		if m == nil {
			break
		}
		if first && c.Spoken && !wordEnd(text, i+len(m[0])) {
			// "D4x" is not a decision.
			break
		}
		if m[1] != "" {
			n, _ := strconv.Atoi(m[1])
			c.Decisions = appendOnce(c.Decisions, n)
		} else {
			n, _ := strconv.Atoi(m[2])
			c.OQ = appendOnce(c.OQ, n)
		}
		i += len(m[0])
		first = false
		j := moreRe.FindString(text[i:])
		if j == "" || partRe.FindString(text[i+len(j):]) == "" {
			break
		}
		i += len(j)
	}
	if first {
		return c, 0, false
	}
	if paren {
		if i >= len(text) || text[i] != ')' {
			return c, 0, false
		}
		i++
	}
	if open && !closed && i < len(text) && text[i] == '`' {
		closed = true
		i++
	}
	if open && closed {
		c.Start = s - 1
	}
	c.End = i
	for _, suf := range []string{"'s", "’s"} {
		if strings.HasPrefix(text[i:], suf) {
			c.Possessive = true
		}
	}
	c.Path = path
	c.LeadStart = c.Start
	if path {
		c.LeadStart = c.Start
		if c.Start >= len("enhancements/") && strings.HasSuffix(text[:c.Start], "enhancements/") {
			c.LeadStart = c.Start - len("enhancements/")
		}
	} else if m := leadRe.FindStringIndex(text[:c.Start]); m != nil {
		c.LeadStart = m[0]
	}
	c.Text = text[c.Start:c.End]
	return c, c.End, true
}

func appendOnce(xs []int, n int) []int {
	for _, x := range xs {
		if x == n {
			return xs
		}
	}
	return append(xs, n)
}
