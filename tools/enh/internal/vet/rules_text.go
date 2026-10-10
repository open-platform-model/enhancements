package vet

import (
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/words"
)

const (
	proposalCap = 300
	designCap   = 1500
	totalCap    = 3000
)

var (
	angleRe      = regexp.MustCompile(`<([A-Za-z][^<>\n]{2,100})>`)
	htmlTagRe    = regexp.MustCompile(`^/?(br|p|a|b|i|em|strong|code|pre|ul|ol|li|details|summary|sup|sub|kbd|img|table|tr|td|th|div|span|hr)(\s[^>]*)?/?$`)
	nnnnRe       = regexp.MustCompile(`\bNNNN\b`)
	todoRe       = regexp.MustCompile(`\b(TODO|TBD|FIXME)\b`)
	inlineCodeRe = regexp.MustCompile("`[^`\n]*`")
	linkRe       = regexp.MustCompile(`\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)`)
	schemeRe     = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*:`)
	otherEntryRe = regexp.MustCompile(`^(\d{4}(-[a-z0-9-]+)?|archive|seed-[a-z0-9-]+)$`)
	changeRefRe  = regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`)
	prRefRe      = regexp.MustCompile(`^PR \d+$`)
	samplingRe   = regexp.MustCompile(`(?m)^sampled:[ \t]*(.*)$`)
	codeSpanRe   = regexp.MustCompile("`[^`\n]+`")
)

// proseLines returns the lines of md with fenced code, HTML comments and
// inline code spans blanked, so that a rule can scan prose only.
func proseLines(md string) []string {
	lines := strings.Split(md, "\n")
	mask := words.FenceMask(lines)
	var b strings.Builder
	for i, l := range lines {
		if mask[i] {
			l = ""
		}
		b.WriteString(l)
		if i < len(lines)-1 {
			b.WriteByte('\n')
		}
	}
	text := blankComments(b.String())
	out := strings.Split(text, "\n")
	for i := range out {
		out[i] = inlineCodeRe.ReplaceAllString(out[i], "")
	}
	return out
}

// blankComments removes HTML comments but keeps the line count.
func blankComments(s string) string {
	var b strings.Builder
	for {
		i := strings.Index(s, "<!--")
		if i < 0 {
			b.WriteString(s)
			return b.String()
		}
		j := strings.Index(s[i:], "-->")
		if j < 0 {
			b.WriteString(s[:i])
			b.WriteString(strings.Repeat("\n", strings.Count(s[i:], "\n")))
			return b.String()
		}
		b.WriteString(s[:i])
		b.WriteString(strings.Repeat("\n", strings.Count(s[i:i+j+3], "\n")))
		s = s[i+j+3:]
	}
}

// proposalRules runs V14, V15 and V22.
func (r *run) proposalRules(e *ent) {
	if e.isSeed() {
		return
	}
	// V14: the two documents exist.
	needDocs := !e.Archived || e.Config.Status == "delivered"
	if needDocs {
		if !e.Proposal.Exists {
			r.add(e, "V14", Error, e.rel+"/proposal.md", 0, "proposal.md is missing")
		}
		if !e.Design.Exists {
			r.add(e, "V14", Error, e.rel+"/design.md", 0, "design.md is missing")
		}
	}
	// V14: unresolved template placeholders (a warning).
	for _, f := range []struct {
		name string
		file entry.File
	}{{"proposal.md", e.Proposal}, {"design.md", e.Design}, {"tasks.md", e.Tasks}} {
		if f.file.Exists {
			r.placeholders(e, e.rel+"/"+f.name, f.file.Text)
		}
	}

	// V15: word caps, all warnings.
	if e.Proposal.Exists || e.Design.Exists {
		p := words.CountExcluding(e.Proposal.Text, "Open questions")
		d := words.Count(e.Design.Text)
		rq := 0
		for _, sp := range e.Specs {
			for _, q := range sp.Requirements {
				if q.Op == delta.Added || q.Op == delta.Modified {
					rq += words.Count(q.Text)
				}
			}
		}
		if p > proposalCap {
			r.add(e, "V15", Warning, e.rel+"/proposal.md", 0, "proposal has %d words; the soft cap is %d (Open questions not counted)", p, proposalCap)
		}
		if d > designCap {
			r.add(e, "V15", Warning, e.rel+"/design.md", 0, "design has %d words; the soft cap is %d", d, designCap)
		}
		if t := p + d + rq; t > totalCap {
			r.add(e, "V15", Warning, e.rel, 0, "proposal %d + design %d + requirement text %d = %d words; the soft cap is %d", p, d, rq, t, totalCap)
		}
	}

	// V22: open questions.
	for _, q := range e.Questions {
		path := e.rel + "/proposal.md"
		switch q.Kind {
		case "":
			r.add(e, "V22", Warning, path, q.Line, "open question is not marked: start it with \"- Blocking:\" or \"- Not blocking:\"")
		case "blocking":
			r.add(e, "V22", e.from(Accept, Error), path, q.Line, "a blocking question is still open: %s", q.Text)
		case "answered":
			r.add(e, "V22", e.from(Accept, Error), path, q.Line, "an answered question must move into design.md: %s", q.Text)
		}
	}
}

func (r *run) placeholders(e *ent, path, text string) {
	for i, l := range proseLines(text) {
		reported := false
		for _, m := range angleRe.FindAllStringSubmatch(l, -1) {
			if htmlTagRe.MatchString(m[1]) || strings.HasPrefix(m[1], "http") {
				continue
			}
			r.add(e, "V14", Warning, path, i+1, "unresolved placeholder <%s>", m[1])
			reported = true
			break
		}
		if !reported && nnnnRe.MatchString(l) {
			r.add(e, "V14", Warning, path, i+1, "unresolved placeholder NNNN")
		} else if !reported {
			if m := todoRe.FindString(l); m != "" {
				r.add(e, "V14", Warning, path, i+1, "unresolved marker %s", m)
			}
		}
	}
}

// taskRules runs V23 and V24.
func (r *run) taskRules(e *ent) {
	if e.isSeed() || e.Archived {
		return
	}
	path := e.rel + "/tasks.md"
	for _, ln := range e.TaskLineErrors {
		r.add(e, "V23", e.warnThenError(Accept), path, ln, "task line does not match \"- [ ] n.m repo: outcome\"")
	}
	if e.mode >= Accept {
		if !e.Tasks.Exists {
			r.add(e, "V23", Error, path, 0, "tasks.md is missing; accept needs one line per repo change")
			return
		}
		if len(e.TaskLines) == 0 {
			r.add(e, "V23", Error, path, 0, "tasks.md has no task line")
		}
		have := map[string]bool{}
		for _, t := range e.TaskLines {
			have[t.Repo] = true
			if !containsStr(e.Config.Affects, t.Repo) {
				r.add(e, "V23", Warning, path, t.Line, "task %d.%d names repo %q, which is not in affects", t.Section, t.Index, t.Repo)
			}
		}
		for _, a := range e.Config.Affects {
			if !have[a] {
				r.add(e, "V23", Error, path, 0, "repo %q is in affects but has no task line", a)
			}
		}
	}
	if e.mode >= Deliver {
		if len(e.TaskLines) == 0 {
			r.add(e, "V24", Error, path, 0, "tasks.md has no task line to deliver")
		}
		for _, t := range e.TaskLines {
			switch {
			case !t.Done:
				r.add(e, "V24", Error, path, t.Line, "task %d.%d is not ticked", t.Section, t.Index)
			case !(prRefRe.MatchString(t.Ref) || changeRefRe.MatchString(t.Ref)):
				r.add(e, "V24", Error, path, t.Line, "task %d.%d is ticked but does not end with (<change-name>) or (PR <n>)", t.Section, t.Index)
			}
		}
	}
}

// linkRules runs V28.
func (r *run) linkRules(e *ent) {
	if e.isSeed() {
		return
	}
	files := []struct{ rel, text string }{
		{"proposal.md", e.Proposal.Text}, {"design.md", e.Design.Text}, {"tasks.md", e.Tasks.Text},
	}
	for _, ev := range e.Evidence {
		if strings.HasSuffix(ev, ".md") {
			if b, err := os.ReadFile(filepath.Join(e.Dir, "evidence", filepath.FromSlash(ev))); err == nil {
				files = append(files, struct{ rel, text string }{"evidence/" + ev, string(b)})
			}
		}
	}
	for _, f := range files {
		lines := strings.Split(f.text, "\n")
		mask := words.FenceMask(lines)
		for i, l := range lines {
			if mask[i] {
				continue
			}
			for _, m := range linkRe.FindAllStringSubmatch(inlineCodeRe.ReplaceAllString(l, ""), -1) {
				if target := foreignEntryLink(f.rel, m[1]); target != "" {
					r.add(e, "V28", Error, e.rel+"/"+f.rel, i+1, "relative link %q leads into %s; cite another entry by its id in words", m[1], target)
				}
			}
		}
	}
}

// foreignEntryLink returns the name of another entry's folder (or "archive")
// that a relative link from file rel leaves the entry for, or "".
func foreignEntryLink(rel, target string) string {
	if i := strings.IndexAny(target, "#?"); i >= 0 {
		target = target[:i]
	}
	if target == "" || strings.HasPrefix(target, "/") || schemeRe.MatchString(target) {
		return ""
	}
	clean := path.Clean(path.Join(path.Dir(rel), target))
	if clean != ".." && !strings.HasPrefix(clean, "../") {
		return ""
	}
	for _, seg := range strings.Split(clean, "/") {
		if seg != ".." && otherEntryRe.MatchString(seg) {
			return seg
		}
	}
	return ""
}

// evidenceRules runs V29. The `cue vet` of evidence modules is left for CI.
func (r *run) evidenceRules(e *ent) {
	if e.isSeed() || !e.HasEvidence {
		return
	}
	var readme string
	hasReadme := false
	var others []string
	for _, f := range e.Evidence {
		if f == "README.md" {
			hasReadme = true
			if b, err := os.ReadFile(filepath.Join(e.Dir, "evidence", "README.md")); err == nil {
				readme = string(b)
			}
			continue
		}
		others = append(others, f)
	}
	if len(others) == 0 {
		return
	}
	path := e.rel + "/evidence/README.md"
	if !hasReadme {
		r.add(e, "V29", Warning, e.rel+"/evidence", 0, "evidence/ has %d files and no README.md index", len(others))
		return
	}
	for _, f := range others {
		key := f
		if i := strings.IndexByte(f, '/'); i > 0 {
			key = f[:i] // a folder is indexed by its name
		}
		if !strings.Contains(readme, key) {
			r.add(e, "V29", Warning, path, 0, "evidence/%s has no line in the index", key)
		}
	}
}

// seedRules runs the V33 rules that are about the seed folder itself.
func (r *run) seedRules(e *ent) {
	if !e.isSeed() || e.Archived {
		return
	}
	if !slugRe.MatchString(e.FolderSlug) {
		r.add(e, "V1", Error, e.rel, 0, "seed folder %q must be seed-<capability> with a kebab-case capability", e.Base)
	}
	if len(e.Specs) == 0 {
		r.add(e, "V33", Error, e.rel+"/specs", 0, "a seed needs specs/<capability>/spec.md")
	}
	for _, sp := range e.Specs {
		if sp.Capability != e.FolderSlug {
			r.add(e, "V33", Error, relSlash(r.store.Root, sp.Path), 0, "seed-%s holds capability %q; a seed holds the one capability it is named for", e.FolderSlug, sp.Capability)
		}
	}
	src := e.rel + "/source.md"
	if !e.Source.Exists {
		r.add(e, "V33", Error, src, 0, "source.md is missing")
		return
	}
	if !codeSpanRe.MatchString(e.Source.Text) {
		r.add(e, "V33", Error, src, 0, "source.md names no repo spec or code (write each as a `code span`)")
	}
	// A line inside an HTML comment is the template's note, not a sample.
	m := samplingRe.FindStringSubmatch(blankComments(e.Source.Text))
	switch {
	case m == nil:
		r.add(e, "V33", e.from(Deliver, Error), src, 0, "source.md has no \"sampled: <date> <commit>\" line")
	case !acceptedRe.MatchString(strings.TrimSpace(m[1])):
		r.add(e, "V33", Error, src, 0, "sampled line %q must read \"<date> <commit>\"", strings.TrimSpace(m[1]))
	}
}
