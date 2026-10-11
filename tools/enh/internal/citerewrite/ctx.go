package citerewrite

import (
	"regexp"

	"github.com/open-platform-model/enhancements/tools/enh/internal/cites"
)

// ctx collects the edits and the worklist rows of one file.
type ctx struct {
	name string
	src  string
	li   *lineIndex
	tt   *Titles
	res  FileResult
}

func newCtx(name string, src []byte, tt *Titles) *ctx {
	s := string(src)
	return &ctx{name: name, src: s, li: newLineIndex(s), tt: tt}
}

// site adds a worklist row for the line of offset off. The citations cs lie
// on that line.
func (c *ctx) site(off int, kind string, cs []cites.Cite) {
	line := c.li.line(off)
	c.res.Sites = append(c.res.Sites, Site{
		Path: c.name, Line: line, Kind: kind, Text: c.li.text(line), Title: titleLine(c.tt, cs),
	})
}

// siteEach adds one row per source line that holds a citation of cs, so that
// a phrase wrapped over several comment lines has a row for each finding of
// cite-lint. offs holds the source offset of each citation.
func (c *ctx) siteEach(offs []int, kind string, cs []cites.Cite) {
	var order []int
	rows := map[int][]cites.Cite{}
	for i, ct := range cs {
		l := c.li.line(offs[i])
		if _, ok := rows[l]; !ok {
			order = append(order, l)
		}
		rows[l] = append(rows[l], ct)
	}
	for _, l := range order {
		c.res.Sites = append(c.res.Sites, Site{
			Path: c.name, Line: l, Kind: kind, Text: c.li.text(l), Title: titleLine(c.tt, rows[l]),
		})
	}
}

// edit adds an edit unless it overlaps one that exists. It reports whether
// the edit was kept.
func (c *ctx) edit(e Edit) bool {
	for _, o := range c.res.Edits {
		if e.Start < o.End && o.Start < e.End || e.Start == o.Start && e.End == o.End {
			return false
		}
	}
	c.res.Edits = append(c.res.Edits, e)
	return true
}

var bareRetiredRe = regexp.MustCompile(`\b003[01]\b`)

// bareRetired lists the worklist rows for a bare 0030 or 0031 in text (a
// line or a paragraph) that no citation covers. base is the offset of text in
// the source; offOf maps an offset in text to a source offset.
func (c *ctx) bareRetired(text string, cs []cites.Cite, offOf func(int) int) {
	for _, loc := range bareRetiredRe.FindAllStringIndex(text, -1) {
		covered := false
		for _, ct := range cs {
			if loc[0] >= ct.LeadStart && loc[1] <= ct.End {
				covered = true
			}
		}
		if !covered && !pathLike(text, loc[0]) {
			c.site(offOf(loc[0]), KindRetiredID, nil)
		}
	}
}

// pathLike reports whether the number at pos sits in a path or a version.
func pathLike(text string, pos int) bool {
	if pos > 0 && (text[pos-1] == '/' || text[pos-1] == '.' || text[pos-1] == '-' || text[pos-1] == '_') {
		return text[pos-1] != '/' || !hasSuffix(text[:pos], "enhancements/")
	}
	return false
}

func hasSuffix(s, suf string) bool { return len(s) >= len(suf) && s[len(s)-len(suf):] == suf }
