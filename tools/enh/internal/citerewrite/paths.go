package citerewrite

import (
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/cites"
)

// pathRef is a reference to an entry by path or by site URL:
// enhancements/0010, ../enhancements/0010/, /enhancements/0010/decisions/#d4.
type pathRef struct {
	start, end int
	id         string
	// rest is what follows the id: "", "/", "/decisions/#d4", "/schemas/target.cue".
	rest string
	// site is true for a root-relative or absolute site URL.
	site bool
	// unknownPrefix is true for a path under some other directory.
	unknownPrefix bool
}

var relPrefixRe = regexp.MustCompile(`(?:\.\.?/)+$`)

var pathRestRe = regexp.MustCompile(`^(?:/[A-Za-z0-9._#{}*~-]*)*`)

// findPaths returns the entry path references of a line.
func findPaths(text string) []pathRef {
	var out []pathRef
	const word = "enhancements/"
	from := 0
	for {
		i := strings.Index(text[from:], word)
		if i < 0 {
			return out
		}
		i += from
		from = i + len(word)
		if len(text) < from+4 || text[from] != '0' || !isDigits(text[from:from+4]) {
			continue
		}
		id := text[from : from+4]
		rest := pathRestRe.FindString(text[from+4:])
		rest = strings.TrimRight(rest, ".")
		end := from + 4 + len(rest)
		if end < len(text) && text[end] >= '0' && text[end] <= '9' {
			continue
		}
		if inOldPath(text, i, end) {
			from = end
			continue // the old-layout path matcher reports it
		}
		ref := pathRef{id: id, rest: rest, start: i, end: end}
		if i > 0 {
			p := text[i-1]
			switch {
			case p == '/':
				j := i - 1
				switch m := relPrefixRe.FindStringIndex(text[:i]); {
				case m != nil:
					ref.start = m[0]
				case j == 0 || strings.ContainsRune(" (\"'=<[`", rune(text[j-1])):
					ref.site = true
					ref.start = j
				case hasSuffix(text[:j], "://opmodel.dev"):
					ref.site = true
					ref.start = strings.LastIndex(text[:j], "http")
				default:
					ref.unknownPrefix = true
				}
			case strings.ContainsRune(" (\"'=<[`,:;*>|", rune(p)):
			default:
				continue
			}
		}
		out = append(out, ref)
		from = end
	}
}

// inOldPath reports whether [s, e) lies in a path to an old-layout entry file.
func inOldPath(text string, s, e int) bool {
	for _, op := range cites.OldPaths(text) {
		if s >= op.Start && e <= op.End {
			return true
		}
	}
	return false
}

func isDigits(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return s != ""
}

// oldSlugs are the seven document slugs of the old layout and their page in
// the new layout (design T2.3 section 5, N9).
var oldSlugs = map[string]string{
	"problem":     "proposal",
	"questions":   "proposal",
	"design":      "design",
	"risks":       "design",
	"operational": "design",
	"decisions":   "requirements",
	"graduation":  "tasks",
}

// slugEdit maps the site URL of a converted entry to its new page. It returns
// the new rest, and false when nothing changes: the ten archived entries keep
// their pages, and a rest that names no old slug stays.
func slugEdit(tt *Titles, ref pathRef) (string, bool) {
	if !ref.site || ref.rest == "" || !tt.Known(ref.id) || tt.Archived(ref.id) {
		return "", false
	}
	segs := strings.Split(strings.TrimPrefix(ref.rest, "/"), "/")
	newSlug, ok := oldSlugs[segs[0]]
	if !ok {
		return "", false
	}
	if newSlug == segs[0] {
		return "", false // design stays design, anchors included
	}
	out := "/" + newSlug
	// An anchor such as #d3 does not survive the move (N9).
	if len(segs) > 1 && !strings.HasPrefix(segs[1], "#") && segs[1] != "" {
		return "", false
	}
	if strings.HasSuffix(ref.rest, "/") || len(segs) > 1 {
		out += "/"
	}
	return out, true
}
