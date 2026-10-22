package vet

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/words"
)

var (
	mapSourceRe = regexp.MustCompile(`(?m)^source:\s*(\S+)\s*@\s*([0-9a-f]{7,40})\s*$`)
	oldDecRe    = regexp.MustCompile(`^###\s+D(\d+):`)
	oldReqRe    = regexp.MustCompile(`^-\s+R(\d+):`)
	oldOQRe     = regexp.MustCompile(`^(?:#{2,4}\s+|\s*[-*]\s+\*\*)(OQ\d+)\b`)
	mapReqIDRe  = regexp.MustCompile(`^\d{4}:D\d+:R\d+$`)
	mapDecIDRe  = regexp.MustCompile(`^(D\d+)\b`)
	mapOQIDRe   = regexp.MustCompile(`^(OQ\d+)\b`)
	headingRe   = regexp.MustCompile(`^#{1,6}\s+(.*?)\s*#*\s*$`)
	// cutLineRe reads a line of evidence/cut-requirements.md: the old id, the
	// disposition and an optional qualifier ("carried by: ..." for a cut line,
	// the repo for a repo line), then the old text.
	cutLineRe = regexp.MustCompile(`^-\s+(\d{4}:D\d+:R\d+)\s+\((cut|repo)(?:,\s*(.*?))?\):`)
)

// cutFile is the name the map's cut and repo targets use for the cut list.
const cutFile = "cut-requirements.md"

// cutLine is one parsed line of the cut list.
type cutLine struct {
	disp, qualifier string
	line            int
}

type mapRow struct {
	id, disp, target string
	line             int
}

// mapRules runs V25 on a migrated entry: the map covers every old
// requirement, decision and open question, and each target exists.
func (r *run) mapRules(e *ent) {
	if e.unnumbered() || !containsStr(e.Evidence, "migration-map.md") {
		return
	}
	mapPath := e.rel + "/evidence/migration-map.md"
	b, err := os.ReadFile(filepath.Join(e.Dir, "evidence", "migration-map.md"))
	if err != nil {
		r.add(e, "V25", Error, mapPath, 0, "cannot read the migration map: %v", err)
		return
	}
	text := strings.ReplaceAll(string(b), "\r\n", "\n")
	src := mapSourceRe.FindStringSubmatch(text)
	if src == nil {
		r.add(e, "V25", Error, mapPath, 0, "the map needs a header line \"source: <entry> @ <commit>\"")
		return
	}
	oldEntry, commit := src[1], src[2]

	allReqs, decs, oqs := parseMap(text)
	// A "moved in" row names a requirement of another entry that this entry
	// receives. It is no old id of this entry's source, so the id comparison
	// and the dispositions below leave it out; it has a check of its own.
	var reqs, movedIn []mapRow
	seenIn := map[string]bool{}
	for _, row := range allReqs {
		if isMovedIn(row.disp) {
			if seenIn[row.id] {
				r.add(e, "V25", Error, mapPath, row.line, "moved in row %s appears twice in the map", row.id)
			}
			seenIn[row.id] = true
			movedIn = append(movedIn, row)
		} else {
			reqs = append(reqs, row)
		}
	}

	// The old ids, from git at the source commit.
	oldDec, err := r.opts.GitShow(r.store.Root, commit, oldEntry+"/03-decisions.md")
	if err != nil {
		r.add(e, "V25", Error, mapPath, 0, "cannot read the old decisions: %v", err)
		return
	}
	oldReqIDs, oldDecIDs := oldDecisionIDs(oldEntry, string(oldDec))
	var oldOQIDs []string
	if q, err := r.opts.GitShow(r.store.Root, commit, oldEntry+"/07-questions.md"); err == nil {
		oldOQIDs = oldQuestionIDs(string(q))
	}

	r.sameIDs(e, mapPath, "requirement", oldReqIDs, reqs)
	r.sameIDs(e, mapPath, "decision", oldDecIDs, decs)
	r.sameIDs(e, mapPath, "open question", oldOQIDs, oqs)

	cuts, cutErr := readCutLines(filepath.Join(e.Dir, "evidence", cutFile))
	designHeads := headings(e.Design.Text)
	proposalHeads := headings(e.Proposal.Text)

	for _, row := range reqs {
		first := firstWord(row.disp)
		for _, t := range splitTargets(row.target) {
			ok, why := true, ""
			switch first {
			case "kept", "merged":
				ok, why = r.deltaTarget(e, t)
			case "cut", "repo":
				ok, why = r.cutTarget(e, row, first, t, cuts, cutErr)
			case "moved":
				var warn string
				ok, why, warn = r.movedTarget(t)
				if warn != "" {
					r.add(e, "V25", Warning, mapPath, row.line, "%s: target %q: %s", row.id, t, warn)
				}
			default:
				ok, why = false, "disposition must be kept, merged, cut, repo or moved"
			}
			if !ok {
				r.add(e, "V25", Error, mapPath, row.line, "%s: target %q: %s", row.id, t, why)
			}
		}
		if strings.TrimSpace(row.target) == "" {
			r.add(e, "V25", Error, mapPath, row.line, "%s has no target", row.id)
		}
	}
	r.checkCutList(e, cuts, reqs)
	for _, row := range movedIn {
		r.movedInRow(e, mapPath, oldEntry, row)
	}
	for _, row := range decs {
		r.checkDocRow(e, mapPath, row, designHeads, proposalHeads, []string{"design", "proposal", "evidence", "dropped"})
	}
	proposalRows := 0
	for _, row := range oqs {
		if strings.Contains(strings.ToLower(row.disp), "proposal") {
			proposalRows++
		}
		r.checkDocRow(e, mapPath, row, designHeads, proposalHeads, []string{"design", "proposal", "dropped"})
	}
	// A question's row follows the question. The map has no key per question,
	// so the check is a count: no more "proposal" rows than questions left.
	if proposalRows > len(e.Questions) {
		r.add(e, "V25", Error, mapPath, 0, "%d open question rows say proposal but proposal.md lists %d questions; update the rows of the questions that moved to design.md", proposalRows, len(e.Questions))
	}
}

// isMovedIn reports whether a disposition is "moved in": the row of a
// requirement that another entry's map moved into this entry (its source id is
// the row id). It is not "moved", which is a requirement of this entry's
// source that left for another entry.
func isMovedIn(disp string) bool {
	f := strings.Fields(strings.ToLower(disp))
	return len(f) >= 2 && strings.Trim(f[0], "(),;:") == "moved" && strings.Trim(f[1], "(),;:") == "in"
}

// movedInRow checks one "moved in" row. The row id is the source id
// (NNNN:Dn:Rm); the target is capability/Requirement name in this entry's
// deltas; the map of the source entry must hold a "moved" row for the same id
// whose target is this entry and that same name. A requirement is counted once,
// at its source as moved: the closing sum of rows leaves moved in rows out.
func (r *run) movedInRow(e *ent, mapPath, oldEntry string, row mapRow) {
	src := row.id[:4]
	if src == e.FolderID || src == oldEntry {
		r.add(e, "V25", Error, mapPath, row.line, "%s: a moved in row names a requirement of another entry, not of %s", row.id, src)
		return
	}
	targets := splitTargets(row.target)
	if len(targets) != 1 {
		r.add(e, "V25", Error, mapPath, row.line, "%s: a moved in row has one target, capability/Requirement name", row.id)
		return
	}
	target := targets[0]
	if ok, why := r.deltaTarget(e, target); !ok {
		r.add(e, "V25", Error, mapPath, row.line, "%s: target %q: %s", row.id, target, why)
		return
	}
	se := r.store.Find(src)
	if se == nil {
		if containsStr(r.store.LegacyLive, src) {
			r.add(e, "V25", Warning, mapPath, row.line, "%s: the source entry %s is not converted yet; the row is checked against its map when it is", row.id, src)
			return
		}
		r.add(e, "V25", Error, mapPath, row.line, "%s: the source entry %s does not exist", row.id, src)
		return
	}
	b, err := os.ReadFile(filepath.Join(se.Dir, "evidence", "migration-map.md"))
	if err != nil {
		r.add(e, "V25", Error, mapPath, row.line, "%s: entry %s has no migration map, so it cannot have moved this requirement here", row.id, src)
		return
	}
	srcReqs, _, _ := parseMap(strings.ReplaceAll(string(b), "\r\n", "\n"))
	var found bool
	for _, sr := range srcReqs {
		if sr.id != row.id || isMovedIn(sr.disp) || firstWord(sr.disp) != "moved" {
			continue
		}
		found = true
		for _, t := range splitTargets(sr.target) {
			if sameMovedTarget(t, e.FolderID, target) {
				return
			}
		}
		r.add(e, "V25", Error, mapPath, row.line, "%s: the map of %s moves it to %q, which does not name %s %s", row.id, src, sr.target, e.FolderID, target)
		return
	}
	if !found {
		r.add(e, "V25", Error, mapPath, row.line, "%s: the map of %s has no moved row for it", row.id, src)
	}
}

// sameMovedTarget reports whether the target "NNNN capability/Name" of a
// moved row names the requirement capability/Name of entry id.
func sameMovedTarget(moved, id, target string) bool {
	idPart, rest, ok := strings.Cut(moved, " ")
	if !ok || idPart != id {
		return false
	}
	c1, n1, ok1 := strings.Cut(rest, "/")
	c2, n2, ok2 := strings.Cut(target, "/")
	return ok1 && ok2 && c1 == c2 && delta.NormalizeName(n1) == delta.NormalizeName(n2)
}

func (r *run) sameIDs(e *ent, path, kind string, old []string, rows []mapRow) {
	have := map[string]bool{}
	for _, row := range rows {
		if have[row.id] {
			r.add(e, "V25", Error, path, row.line, "%s %s appears twice in the map", kind, row.id)
		}
		have[row.id] = true
	}
	want := map[string]bool{}
	for _, id := range old {
		want[id] = true
		if !have[id] {
			r.add(e, "V25", Error, path, 0, "old %s %s has no row in the map", kind, id)
		}
	}
	for _, row := range rows {
		if !want[row.id] {
			r.add(e, "V25", Error, path, row.line, "map row %s is not an old %s", row.id, kind)
		}
	}
}

// checkDocRow checks one decision or question row.
func (r *run) checkDocRow(e *ent, path string, row mapRow, design, proposal map[string]bool, allowed []string) {
	var disps []string
	for _, seg := range splitTop(row.disp) {
		if w := firstWord(seg); w != "" {
			disps = append(disps, w)
		}
	}
	if len(disps) == 0 {
		r.add(e, "V25", Error, path, row.line, "%s has no disposition", row.id)
		return
	}
	for _, d := range disps {
		if !containsStr(allowed, d) {
			r.add(e, "V25", Error, path, row.line, "%s: disposition %q is not one of %s", row.id, d, strings.Join(allowed, ", "))
			return
		}
	}
	targets := splitTargets(row.target)
	if len(targets) == 0 {
		r.add(e, "V25", Error, path, row.line, "%s has no target (a dropped row needs its reason)", row.id)
		return
	}
	named := map[string]bool{}
	for _, t := range targets {
		// A target may start with the disposition it belongs to ("design:
		// A theme"). A row with two dispositions needs it on every target, to
		// tell them apart, and each disposition needs a target.
		use := disps
		if d, rest, ok := targetPrefix(t, allowed); ok {
			if !containsStr(disps, d) {
				r.add(e, "V25", Error, path, row.line, "%s: target %q starts with %q, which is not a disposition of the row", row.id, t, d)
				continue
			}
			use, t = []string{d}, rest
			named[d] = true
		} else if len(uniqueStrs(disps)) > 1 {
			r.add(e, "V25", Error, path, row.line, "%s: the row has dispositions %s, so target %q must start with one of them and a colon", row.id, strings.Join(disps, "/"), t)
			continue
		}
		ok := false
		for _, d := range use {
			switch d {
			case "design":
				ok = ok || hasHeading(design, t)
			case "proposal":
				ok = ok || hasHeading(proposal, t)
			case "evidence":
				ok = ok || containsStr(e.Evidence, strings.TrimPrefix(t, "evidence/"))
			case "dropped":
				ok = true // the target column holds the reason
			}
		}
		if !ok {
			r.add(e, "V25", Error, path, row.line, "%s: target %q is not found for disposition %s", row.id, t, strings.Join(use, "/"))
		}
	}
	if len(uniqueStrs(disps)) > 1 {
		for _, d := range uniqueStrs(disps) {
			if !named[d] {
				r.add(e, "V25", Error, path, row.line, "%s: the row has the disposition %s but no target starts with %q", row.id, d, d+":")
			}
		}
	}
}

// uniqueStrs returns the distinct values of ss.
func uniqueStrs(ss []string) []string {
	var out []string
	for _, s := range ss {
		if !containsStr(out, s) {
			out = append(out, s)
		}
	}
	return out
}

// targetPrefix splits "design: A theme" into "design" and "A theme" when the
// word before the first colon is one of the allowed dispositions.
func targetPrefix(t string, allowed []string) (disp, rest string, ok bool) {
	head, tail, found := strings.Cut(t, ":")
	if !found {
		return "", t, false
	}
	head = strings.ToLower(strings.TrimSpace(head))
	if !containsStr(allowed, head) {
		return "", t, false
	}
	return head, strings.TrimSpace(tail), true
}

// readCutLines parses evidence/cut-requirements.md into a map by old id.
func readCutLines(p string) (map[string]cutLine, error) {
	b, err := os.ReadFile(p)
	if err != nil {
		return nil, err
	}
	out := map[string]cutLine{}
	for i, l := range strings.Split(strings.ReplaceAll(string(b), "\r\n", "\n"), "\n") {
		if m := cutLineRe.FindStringSubmatch(l); m != nil {
			out[m[1]] = cutLine{disp: m[2], qualifier: strings.TrimSpace(m[3]), line: i + 1}
		}
	}
	return out, nil
}

// cutTarget checks the target of a cut or repo row: "cut-requirements.md: <old
// id>", where the line for the row's own id exists, has the row's disposition,
// and, for a cut line with a "carried by" list, names requirements of this
// entry.
func (r *run) cutTarget(e *ent, row mapRow, disp, t string, cuts map[string]cutLine, cutErr error) (bool, string) {
	if cutErr != nil {
		return false, "evidence/cut-requirements.md is missing"
	}
	rest, hasFile := strings.CutPrefix(t, cutFile+":")
	if !hasFile {
		return false, "write the target as " + cutFile + ": <old id>"
	}
	id := strings.TrimSpace(rest)
	if !mapReqIDRe.MatchString(id) {
		return false, "write the target as " + cutFile + ": <old id>"
	}
	if id != row.id {
		return false, "a " + disp + " row points at the line of its own id, " + row.id
	}
	l, ok := cuts[id]
	if !ok {
		return false, "no line for " + id + " in evidence/cut-requirements.md (a line reads \"- " + id + " (" + disp + "): old text\")"
	}
	if l.disp != disp {
		return false, "the map says " + disp + " but the line in evidence/cut-requirements.md says " + l.disp
	}
	if disp == "cut" && l.qualifier != "" {
		names, isCarried := carriedBy(l.qualifier)
		if !isCarried {
			return false, "line " + strconv.Itoa(l.line) + " of evidence/cut-requirements.md has the qualifier " + strconv.Quote(l.qualifier) + "; a cut line has none or \"carried by: <capability/Requirement name>; ...\""
		}
		for _, c := range splitTargets(names) {
			if ok, why := r.deltaTarget(e, c); !ok {
				return false, "line " + strconv.Itoa(l.line) + " of evidence/cut-requirements.md is carried by " + strconv.Quote(c) + ": " + why
			}
		}
	}
	return true, ""
}

// carriedBy returns the names after "carried by:" (any case), and whether the
// qualifier has that form.
func carriedBy(q string) (string, bool) {
	const key = "carried by:"
	if len(q) < len(key) || !strings.EqualFold(q[:len(key)], key) {
		return "", false
	}
	return q[len(key):], true
}

// checkCutList reports a line of the cut list that no cut or repo row points at.
func (r *run) checkCutList(e *ent, cuts map[string]cutLine, reqs []mapRow) {
	used := map[string]bool{}
	for _, row := range reqs {
		if d := firstWord(row.disp); d == "cut" || d == "repo" {
			used[row.id] = true
		}
	}
	var ids []string
	for id := range cuts {
		if !used[id] {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	for _, id := range ids {
		r.add(e, "V25", Error, e.rel+"/evidence/"+cutFile, cuts[id].line, "%s has a line here but no cut or repo row in the map", id)
	}
}

// deltaTarget checks "capability/Requirement name" against the entry's deltas.
func (r *run) deltaTarget(e *ent, t string) (bool, string) {
	cap, name, ok := strings.Cut(t, "/")
	if !ok {
		return false, "write the target as capability/Requirement name"
	}
	name = delta.NormalizeName(name)
	for _, sp := range e.Specs {
		if sp.Capability != cap {
			continue
		}
		for _, q := range sp.Requirements {
			if q.Name == name {
				return true, ""
			}
		}
	}
	return false, "no such requirement in this entry's delta specs"
}

// movedTarget checks "NNNN capability/Requirement name" in the receiving entry.
// While the receiving entry is still an old-layout folder it has no
// requirements to check: the result is a warning, and the target is checked
// once the entry converts.
func (r *run) movedTarget(t string) (ok bool, why, warn string) {
	idPart, rest, found := strings.Cut(t, " ")
	if !found || !idRe.MatchString(idPart) {
		return false, "write the target as NNNN capability/Requirement name", ""
	}
	cap, name, found := strings.Cut(rest, "/")
	if !found {
		return false, "write the target as NNNN capability/Requirement name", ""
	}
	recv := r.store.Find(idPart)
	if recv == nil {
		if containsStr(r.store.LegacyLive, idPart) {
			return true, "", "the receiving entry " + idPart + " is not converted yet; the target is checked when it is"
		}
		return false, "the receiving entry " + idPart + " does not exist", ""
	}
	name = delta.NormalizeName(name)
	for _, sp := range recv.Specs {
		if sp.Capability != cap {
			continue
		}
		for _, q := range sp.Requirements {
			if q.Name == name {
				return true, "", ""
			}
		}
	}
	return false, "no such requirement in entry " + idPart, ""
}

// parseMap reads the three tables of a migration map.
func parseMap(text string) (reqs, decs, oqs []mapRow) {
	_, secs := words.Sections(text)
	for _, s := range secs {
		var dst *[]mapRow
		var idRe *regexp.Regexp
		switch strings.ToLower(s.Name) {
		case "requirements":
			dst, idRe = &reqs, mapReqIDRe
		case "decisions":
			dst, idRe = &decs, mapDecIDRe
		case "open questions":
			dst, idRe = &oqs, mapOQIDRe
		default:
			continue
		}
		for i, l := range strings.Split(s.Body, "\n") {
			l = strings.TrimSpace(l)
			if !strings.HasPrefix(l, "|") {
				continue
			}
			cells := strings.Split(strings.Trim(l, "|"), "|")
			for k := range cells {
				cells[k] = strings.TrimSpace(cells[k])
			}
			if len(cells) < 3 {
				continue
			}
			m := idRe.FindStringSubmatch(cells[0])
			if m == nil {
				continue // header or separator row
			}
			id := m[0]
			if len(m) > 1 {
				id = m[1]
			}
			*dst = append(*dst, mapRow{id: id, disp: cells[1], target: cells[2], line: s.Line + i + 1})
		}
	}
	return reqs, decs, oqs
}

func oldDecisionIDs(entryID, text string) (reqs, decs []string) {
	cur := ""
	for _, l := range strings.Split(text, "\n") {
		if m := oldDecRe.FindStringSubmatch(l); m != nil {
			cur = m[1]
			decs = append(decs, "D"+cur)
			continue
		}
		if m := oldReqRe.FindStringSubmatch(l); m != nil && cur != "" {
			reqs = append(reqs, entryID+":D"+cur+":R"+m[1])
		}
	}
	return reqs, decs
}

func oldQuestionIDs(text string) []string {
	var out []string
	seen := map[string]bool{}
	for _, l := range strings.Split(text, "\n") {
		if m := oldOQRe.FindStringSubmatch(l); m != nil && !seen[m[1]] {
			seen[m[1]] = true
			out = append(out, m[1])
		}
	}
	return out
}

func headings(md string) map[string]bool {
	out := map[string]bool{}
	lines := strings.Split(md, "\n")
	mask := words.FenceMask(lines)
	for i, l := range lines {
		if mask[i] {
			continue
		}
		if m := headingRe.FindStringSubmatch(l); m != nil {
			out[strings.ToLower(m[1])] = true
		}
	}
	return out
}

func firstWord(s string) string {
	f := strings.Fields(strings.ToLower(s))
	if len(f) == 0 {
		return ""
	}
	return strings.Trim(f[0], "(),;:")
}

func splitTargets(s string) []string {
	var out []string
	for _, t := range splitTop(strings.ReplaceAll(s, "<br>", ";")) {
		if t = strings.TrimSpace(t); t != "" {
			out = append(out, t)
		}
	}
	return out
}

// splitTop splits at semicolons that are not inside parentheses.
func splitTop(s string) []string {
	var out []string
	depth, start := 0, 0
	for i, r := range s {
		switch r {
		case '(':
			depth++
		case ')':
			if depth > 0 {
				depth--
			}
		case ';':
			if depth == 0 {
				out = append(out, s[start:i])
				start = i + 1
			}
		}
	}
	return append(out, s[start:])
}

// hasHeading reports whether a heading equals the target, or the target is
// the heading followed by a comma and a qualifier ("Open questions, not
// blocking" names the heading "Open questions").
func hasHeading(heads map[string]bool, target string) bool {
	t := strings.ToLower(strings.TrimSpace(target))
	if heads[t] {
		return true
	}
	if i := strings.Index(t, ","); i > 0 {
		return heads[strings.TrimSpace(t[:i])]
	}
	return false
}
