package citerewrite

import (
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/citelint"
	"github.com/open-platform-model/enhancements/tools/enh/internal/cites"
)

// processCode reads the comments and strings of a Go or CUE file (the lint's
// lexer) and rewrites the citations of kind 2 (form 1) and the retired ids
// (form 3). Every other citation becomes a worklist row.
func processCode(name string, src []byte, tt *Titles) FileResult {
	c := newCtx(name, src, tt)
	paras, strs, ok := citelint.Parse(name, src)
	if !ok {
		return c.res
	}
	for _, s := range strs {
		cs := cites.Scan(s.Text)
		for _, p := range groupPhrases(s.Text, cs) {
			c.site(s.Off+p.start, KindString, p.cites)
		}
		c.bareRetired(s.Text, cs, func(i int) int { return s.Off + i })
		c.oldPathSites(s.Text, func(i int) int { return s.Off + i })
	}
	for _, p := range paras {
		c.codeParagraph(p)
	}
	return c.res
}

// paraMap maps offsets of the joined paragraph text to the source.
type paraMap struct {
	lines  []citelint.Line
	starts []int // offset of each line in the joined text
}

func newParaMap(p citelint.Paragraph) paraMap {
	m := paraMap{lines: p.Lines}
	off := 0
	for _, l := range p.Lines {
		m.starts = append(m.starts, off)
		off += len(l.Text) + 1
	}
	return m
}

// abs maps an offset of the joined text to a source offset.
func (m paraMap) abs(off int) int {
	i := m.lineOf(off)
	return m.lines[i].Off + off - m.starts[i]
}

func (m paraMap) lineOf(off int) int {
	i := 0
	for j := range m.starts {
		if m.starts[j] <= off {
			i = j
		}
	}
	return i
}

// within reports whether [s, e) lies in one source line.
func (m paraMap) within(s, e int) bool {
	i := m.lineOf(s)
	return e <= m.starts[i]+len(m.lines[i].Text)
}

func (c *ctx) codeParagraph(p citelint.Paragraph) {
	joined := p.Joined()
	cs := cites.Scan(joined)
	m := newParaMap(p)
	c.bareRetired(joined, cs, m.abs)
	c.oldPathSites(joined, m.abs)
	phs := groupPhrases(joined, cs)
	for _, ph := range phs {
		c.codePhrase(p, m, joined, ph)
	}
	// A path to an entry in a comment is for an agent: the words around it
	// decide what the comment should say.
	for _, pr := range findPaths(joined) {
		if pr.site {
			continue
		}
		covered := false
		for _, ph := range phs {
			if ph.path && pr.start >= ph.start && pr.end <= ph.end {
				covered = true
			}
		}
		if covered {
			continue
		}
		kind := KindPathRef
		if pr.rest != "" && pr.rest != "/" {
			kind = KindEntryFile
		}
		c.res.Sites = append(c.res.Sites, Site{Path: c.name, Line: c.li.line(m.abs(pr.start)), Kind: kind, Text: c.li.text(c.li.line(m.abs(pr.start)))})
	}
}

func (c *ctx) codePhrase(p citelint.Paragraph, m paraMap, joined string, ph phrase) {
	at := m.abs(ph.cites[0].Start)
	live, _ := splitRetired(ph.cites)
	switch {
	case ph.path:
		c.codeSite(m, ph, KindPathDecisions)
		return
	case ph.oq:
		c.codeSite(m, ph, KindOQ)
		return
	case ph.glued && len(live) == 0:
		c.codeSite(m, ph, KindRetiredInline)
		return
	case ph.glued:
		c.codeSite(m, ph, KindInline)
		return
	case p.Lone && len(live) == 0:
		c.codeSite(m, ph, KindRetiredLone)
		return
	case p.Lone:
		c.codeSite(m, ph, KindLoneID)
		return
	case ph.possessive:
		c.codeSite(m, ph, KindPossessive)
		return
	}
	if len(live) == 0 {
		c.retiredEdit(m, joined, ph, at)
		return
	}
	// Kind 2: the phrase is a whole parenthesis, or it ends the sentence after
	// a comma or "per".
	ids, bad := resolvedIDs(c.tt, live)
	if bad != "" {
		c.codeSite(m, ph, bad)
		return
	}
	canon := canonicalIDs(ids)
	ls := extendLeadin(joined, ph.start)
	b := trimBackSpaces(joined, ls)
	a := skipSpaces(joined, ph.end)
	var e Edit
	switch {
	case b > 0 && joined[b-1] == '(' && a < len(joined) && joined[a] == ')':
		e = Edit{Start: b, End: a, New: canon, Form: FormCodeComment}
	case a < len(joined) && joined[a] == ')' && b > 0 && hasLetter(joined[:b]) && sepBefore(joined, b):
		// A phrase that closes a parenthesis after a dash, comma or semicolon:
		// "(experimental, see 0010 D47)" keeps its words.
		e = Edit{Start: ph.start, End: ph.end, New: canon, Form: FormCodeComment}
	case endsSentence(joined[ph.end:]) && b > 0 && hasLetter(joined[:b]) &&
		(joined[b-1] == ',' || joined[b-1] == ';' || ls < ph.start):
		rs := b
		switch {
		case joined[b-1] == ',' || joined[b-1] == ';':
			rs = trimBackSpaces(joined, b-1)
		case strings.HasSuffix(joined[:b], "-") || strings.HasSuffix(joined[:b], "\u2014") || strings.HasSuffix(joined[:b], "\u2013"):
			// "case - see X." keeps no dash of its own.
			rs = trimBackSpaces(joined, b-dashLen(joined[:b]))
		}
		e = Edit{Start: rs, End: ph.end, New: " (" + canon + ")", Form: FormCodeComment}
	default:
		c.codeSite(m, ph, KindInline)
		return
	}
	// A lead word on the line above ("(enhancement" then "0015:D1)"): keep the
	// word, replace only the citation with its id.
	var alt *Edit
	if len(ids) == 1 && len(live) == len(ph.cites) && ph.cites[0].LeadStart < ph.cites[0].Start && e.Start <= ph.start {
		alt = &Edit{Start: ph.cites[0].Start, End: ph.end, New: ids[0], Form: FormCodeComment}
	}
	c.commit(m, e, at, ph, alt)
}

// sepBefore reports whether the text before position b (after the blanks)
// ends with a dash, comma or semicolon.
func sepBefore(text string, b int) bool {
	switch {
	case text[b-1] == ',' || text[b-1] == ';':
		return true
	case text[b-1] == '-':
		// a spaced hyphen only: "x - 0010 D4", not "x-0010 D4"
		return b >= 2 && text[b-2] == ' '
	}
	return strings.HasSuffix(text[:b], "\u2014") || strings.HasSuffix(text[:b], "\u2013")
}

// endsSentence reports whether rest closes the sentence: the end of the
// paragraph, or a full stop and a new sentence.
func endsSentence(rest string) bool {
	return endRe.MatchString(rest) || endSentRe.MatchString(rest)
}

// codeSite adds the worklist rows of a phrase of a comment paragraph.
func (c *ctx) codeSite(m paraMap, ph phrase, kind string) {
	offs := make([]int, len(ph.cites))
	for i, ct := range ph.cites {
		offs[i] = m.abs(ct.Start)
	}
	c.siteEach(offs, kind, ph.cites)
}

func (c *ctx) retiredEdit(m paraMap, joined string, ph phrase, at int) {
	rs, re, repl, ok, lone := removal(joined, ph.start, ph.end, false, false)
	switch {
	case lone:
		c.codeSite(m, ph, KindRetiredLone)
	case !ok:
		c.codeSite(m, ph, KindRetiredInline)
	default:
		c.commit(m, Edit{Start: rs, End: re, New: repl, Form: FormRetired}, at, ph, nil)
	}
}

// commit maps an edit of the joined text to the source and adds it, or adds
// a worklist row when the edit crosses a line or overlaps another.
func (c *ctx) commit(m paraMap, e Edit, at int, ph phrase, alt *Edit) {
	if !m.within(e.Start, e.End) && alt != nil && m.within(alt.Start, alt.End) {
		e = *alt
	}
	if !m.within(e.Start, e.End) {
		c.codeSite(m, ph, KindWrapped)
		return
	}
	abs := Edit{Start: m.abs(e.Start), End: m.abs(e.Start) + (e.End - e.Start), New: e.New, Form: e.Form}
	if strings.Contains(c.src[abs.Start:abs.End], "\n") || !c.edit(abs) {
		c.codeSite(m, ph, KindWrapped)
	}
}

// dashLen returns the byte length of the dash that ends text.
func dashLen(text string) int {
	if strings.HasSuffix(text, "-") {
		return 1
	}
	return 3
}
