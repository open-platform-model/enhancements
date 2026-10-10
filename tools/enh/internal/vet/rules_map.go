package vet

import (
	"os"
	"path/filepath"
	"regexp"
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
)

type mapRow struct {
	id, disp, target string
	line             int
}

// mapRules runs V25 on a migrated entry: the map covers every old
// requirement, decision and open question, and each target exists.
func (r *run) mapRules(e *ent) {
	if e.isSeed() || !containsStr(e.Evidence, "migration-map.md") {
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

	reqs, decs, oqs := parseMap(text)

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

	cutText := ""
	if cb, err := os.ReadFile(filepath.Join(e.Dir, "evidence", "cut-requirements.md")); err == nil {
		cutText = string(cb)
	}
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
				if cutText == "" {
					ok, why = false, "evidence/cut-requirements.md is missing"
				} else if !strings.Contains(cutText, t) {
					ok, why = false, "no such line in evidence/cut-requirements.md"
				}
			case "moved":
				ok, why = r.movedTarget(t)
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
	for _, t := range targets {
		ok := false
		for _, d := range disps {
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
			r.add(e, "V25", Error, path, row.line, "%s: target %q is not found for disposition %s", row.id, t, strings.Join(disps, "/"))
		}
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
func (r *run) movedTarget(t string) (bool, string) {
	idPart, rest, ok := strings.Cut(t, " ")
	if !ok || !idRe.MatchString(idPart) {
		return false, "write the target as NNNN capability/Requirement name"
	}
	recv := r.store.Find(idPart)
	if recv == nil {
		return false, "the receiving entry " + idPart + " does not exist"
	}
	cap, name, ok := strings.Cut(rest, "/")
	if !ok {
		return false, "write the target as NNNN capability/Requirement name"
	}
	name = delta.NormalizeName(name)
	for _, sp := range recv.Specs {
		if sp.Capability != cap {
			continue
		}
		for _, q := range sp.Requirements {
			if q.Name == name {
				return true, ""
			}
		}
	}
	return false, "no such requirement in entry " + idPart
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
