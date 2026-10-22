package vet

import (
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/words"
)

// opRenamed is the operation of a RENAMED block; the delta package keeps
// renames apart from requirement blocks.
const opRenamed delta.Op = "RENAMED"

var (
	shippedHeadRe = regexp.MustCompile(`(?i)^##\s+Shipped by\s*$`)
	nextHeadRe    = regexp.MustCompile(`^##\s`)
	separatorRe   = regexp.MustCompile(`^:?-{3,}:?$`)
	// A reference to the change that shipped the behaviour: the repo in a code
	// span, then PR <n> or commit <sha>.
	shippedRefRe = regexp.MustCompile("`([^`]+)`\\s+(PR [0-9]+|commit [0-9a-f]{7,40})\\b")
)

// correctionFiles are the only entries of a correction folder.
var correctionFiles = []string{".openspec.yaml", "source.md", "specs"}

// correctionRules runs V36 on a live correction: the shape of the folder and
// of its deltas. V37 (the evidence) follows in the same call.
func (r *run) correctionRules(e *ent) {
	if !slugRe.MatchString(e.FolderSlug) {
		r.add(e, "V36", Error, e.rel, 0, "correction folder %q must be correction-<slug> with a kebab-case slug", e.Base)
	}
	if e.OpenSpecFile.Exists && e.OpenSpecErr == nil && e.Schema != "correction" {
		r.add(e, "V36", Error, e.rel+"/.openspec.yaml", 0, "schema is %q; a correction uses schema: correction", e.Schema)
	}
	r.correctionLayout(e)
	if len(e.Specs) == 0 {
		r.add(e, "V36", Error, e.rel+"/specs", 0, "a correction needs at least one specs/<capability>/spec.md")
	}
	for _, sp := range e.Specs {
		r.correctionDelta(e, sp)
	}
	r.correctionOverlap(e)
	r.correctionEvidence(e)
}

// correctionLayout refuses any file or folder a correction does not have:
// no config.yaml, proposal, design, tasks, README or evidence.
func (r *run) correctionLayout(e *ent) {
	ents, err := os.ReadDir(e.Dir)
	if err != nil {
		r.add(e, "V36", Error, e.rel, 0, "cannot read the folder: %s", firstLine(err.Error()))
		return
	}
	for _, d := range ents {
		if !containsStr(correctionFiles, d.Name()) {
			r.add(e, "V36", Error, e.rel+"/"+d.Name(), 0, "a correction holds only %s; %q is not allowed", strings.Join(correctionFiles, ", "), d.Name())
		}
	}
	for _, sp := range e.Specs {
		for _, extra := range extraSpecFiles(e, sp) {
			r.add(e, "V36", Error, relSlash(r.store.Root, extra), 0, "specs/ of a correction holds spec.md files only")
		}
	}
}

// extraSpecFiles lists the entries beside the spec.md of one capability folder.
func extraSpecFiles(e *ent, sp *delta.Spec) []string {
	dir := sp.Path
	if i := strings.LastIndexAny(dir, `/\`); i >= 0 {
		dir = dir[:i]
	}
	ents, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []string
	for _, d := range ents {
		if d.Name() != "spec.md" {
			out = append(out, dir+"/"+d.Name())
		}
	}
	return out
}

// correctionDelta runs the V36 rules on the delta of one capability.
func (r *run) correctionDelta(e *ent, sp *delta.Spec) {
	path := relSlash(r.store.Root, sp.Path)
	main := r.store.Specs[sp.Capability]
	if main == nil {
		r.add(e, "V36", Error, path, 0, "capability %q is not in openspec/specs/; a correction changes a delivered capability, so make a seed for a new one", sp.Capability)
		return
	}
	if sp.HasPurpose {
		r.add(e, "V36", Error, path, sp.PurposeLine, "a correction delta has no ## Purpose; the capability %q exists", sp.Capability)
	}
	if len(sp.Requirements) == 0 && len(sp.Renames) == 0 {
		r.add(e, "V36", Error, path, 0, "the delta for %q holds no requirement block", sp.Capability)
		return
	}
	mainRaw := map[string]string{}
	for _, q := range main.By(delta.Main) {
		mainRaw[delta.NormalizeName(q.Name)] = fold(q.Raw)
	}
	removed := map[string]bool{}
	for _, q := range sp.Requirements {
		switch q.Op {
		case delta.Modified:
			if old, ok := mainRaw[delta.NormalizeName(q.Name)]; ok && old == fold(q.Raw) {
				r.add(e, "V36", Error, path, q.Line, "MODIFIED requirement %q equals the main requirement; a correction changes text that drifted", q.Name)
			}
		case delta.Removed:
			removed[delta.NormalizeName(q.Name)] = true
		}
	}
	if len(sp.By(delta.Added)) == 0 && len(sp.Renames) == 0 && len(mainRaw) > 0 && allIn(mainRaw, removed) {
		r.add(e, "V36", Error, path, 0, "the REMOVED blocks take every requirement of capability %q; retiring a capability is not a correction", sp.Capability)
	}
}

func allIn(want map[string]string, have map[string]bool) bool {
	for k := range want {
		if !have[k] {
			return false
		}
	}
	return true
}

// correctionOverlap warns when a live numbered entry names a requirement that
// the correction touches: after the correction is delivered, that entry has a
// stale base.
func (r *run) correctionOverlap(e *ent) {
	touched := map[string]bool{}
	for _, sp := range e.Specs {
		for _, q := range sp.Requirements {
			touched[sp.Capability+"\x00"+delta.NormalizeName(q.Name)] = true
		}
		for _, rn := range sp.Renames {
			touched[sp.Capability+"\x00"+delta.NormalizeName(rn.From)] = true
			touched[sp.Capability+"\x00"+delta.NormalizeName(rn.To)] = true
		}
	}
	for _, o := range r.store.Live {
		if o.Kind != entry.Enhancement {
			continue
		}
		var hits []string
		for _, sp := range o.Specs {
			names := map[string]bool{}
			for _, q := range sp.Requirements {
				names[delta.NormalizeName(q.Name)] = true
			}
			for _, rn := range sp.Renames {
				names[delta.NormalizeName(rn.From)] = true
				names[delta.NormalizeName(rn.To)] = true
			}
			for n := range names {
				if touched[sp.Capability+"\x00"+n] {
					hits = append(hits, sp.Capability+" / "+n)
				}
			}
		}
		if len(hits) == 0 {
			continue
		}
		sort.Strings(hits)
		r.add(e, "V36", Warning, e.rel, 0, "live entry %s names the same requirement (%s); it will carry a stale base after this correction is delivered", o.Folder, strings.Join(hits, "; "))
	}
}

// shippedRow is one row of the Shipped by table of source.md.
type shippedRow struct {
	line                 int
	capability, name, op string
	by, code             string
	cells                int
}

// key identifies the requirement a row speaks of, with its operation.
func (s shippedRow) key() string { return s.capability + "\x00" + s.name + "\x00" + s.op }

// parseShipped reads the table under "## Shipped by". found is false when the
// heading is absent. A comment and a fenced block are not read.
func parseShipped(text string) (rows []shippedRow, found bool) {
	lines := strings.Split(blankComments(text), "\n")
	mask := words.FenceMask(lines)
	in := false
	for i, l := range lines {
		if mask[i] {
			continue
		}
		switch {
		case shippedHeadRe.MatchString(l):
			in, found = true, true
			continue
		case in && nextHeadRe.MatchString(l):
			in = false
		}
		t := strings.TrimSpace(l)
		if !in || !strings.HasPrefix(t, "|") {
			continue
		}
		cells := strings.Split(strings.Trim(t, "|"), "|")
		for j := range cells {
			cells[j] = strings.TrimSpace(cells[j])
		}
		if isSeparator(cells) || strings.EqualFold(cells[0], "capability") {
			continue
		}
		row := shippedRow{line: i + 1, cells: len(cells)}
		if len(cells) >= 5 {
			row.capability = strings.Trim(cells[0], "`")
			row.name = delta.NormalizeName(strings.Trim(cells[1], "`"))
			row.op = strings.ToUpper(cells[2])
			row.by, row.code = cells[3], cells[4]
		}
		rows = append(rows, row)
	}
	return rows, found
}

func isSeparator(cells []string) bool {
	for _, c := range cells {
		if !separatorRe.MatchString(c) {
			return false
		}
	}
	return true
}

// correctionEvidence runs V37: every requirement block of the deltas has one
// row that names the change that shipped it, and the rows name nothing else.
func (r *run) correctionEvidence(e *ent) {
	if !e.Source.Exists {
		return // sourceRules reports the missing file
	}
	src := e.rel + "/source.md"
	rows, found := parseShipped(e.Source.Text)
	if !found {
		r.add(e, "V37", Error, src, 0, "source.md has no \"## Shipped by\" table")
		return
	}
	// What the deltas hold: key -> display, plus the names a REMOVED replaces.
	want := map[string]string{}
	opsOf := map[string][]string{} // capability|name -> operations
	replaced := map[string]bool{}  // capability|name of an ADDED that replaces a REMOVED
	var order []string
	note := func(capability, name string, op delta.Op) {
		k := capability + "\x00" + name + "\x00" + string(op)
		want[k] = fmt.Sprintf("%s %q in %s", op, name, capability)
		order = append(order, k)
		pair := capability + "\x00" + name
		opsOf[pair] = append(opsOf[pair], string(op))
	}
	for _, sp := range e.Specs {
		for _, q := range sp.Requirements {
			note(sp.Capability, delta.NormalizeName(q.Name), q.Op)
			if q.Op == delta.Removed {
				if m := replacedForm.FindStringSubmatch(q.Migration); m != nil {
					for _, other := range e.Specs { // a replacement may sit in another capability
						replaced[other.Capability+"\x00"+delta.NormalizeName(m[1])] = true
					}
				}
			}
		}
		for _, rn := range sp.Renames {
			note(sp.Capability, delta.NormalizeName(rn.To), opRenamed)
		}
	}
	seen := map[string]bool{}
	for _, row := range rows {
		if row.cells < 5 {
			r.add(e, "V37", Error, src, row.line, "a Shipped by row has %d cells; it needs Capability, Requirement, Change, Shipped by and Code read", row.cells)
			continue
		}
		k := row.key()
		_, inDelta := want[k]
		switch {
		case !inDelta && len(opsOf[row.capability+"\x00"+row.name]) > 0:
			r.add(e, "V37", Error, src, row.line, "the row for %q in %s says %s, but the delta says %s", row.name, row.capability, row.op, strings.Join(opsOf[row.capability+"\x00"+row.name], " and "))
			continue
		case !inDelta:
			r.add(e, "V37", Error, src, row.line, "the row for %q in %s names no requirement of the deltas", row.name, row.capability)
			continue
		case seen[k]:
			r.add(e, "V37", Error, src, row.line, "two rows for %s", want[k])
			continue
		}
		seen[k] = true
		r.shippedRefs(e, src, row)
		needsCode := row.op == string(delta.Modified) ||
			(row.op == string(delta.Added) && !replaced[row.capability+"\x00"+row.name])
		if needsCode && !codeSpanRe.MatchString(row.code) {
			r.add(e, "V37", Error, src, row.line, "the row for %s needs the code read, as `path:line` in a code span", want[k])
		}
	}
	for _, k := range order {
		if !seen[k] {
			r.add(e, "V37", Error, src, 0, "no row in the Shipped by table for %s", want[k])
		}
	}
}

// shippedRefs checks the Shipped by cell of one row: at least one reference,
// every reference with a repo that #EntryRepo lists, and no text besides them.
func (r *run) shippedRefs(e *ent, src string, row shippedRow) {
	refs := shippedRefRe.FindAllStringSubmatch(row.by, -1)
	if len(refs) == 0 {
		r.add(e, "V37", Error, src, row.line, "the row for %q has no reference; write `<repo>` PR <n> or `<repo>` commit <sha>", row.name)
		return
	}
	for _, m := range refs {
		if !r.schema.IsRepo(m[1]) {
			r.add(e, "V37", Error, src, row.line, "the row for %q names repo %q, which #EntryRepo in schema.cue does not list", row.name, m[1])
		}
	}
	rest := shippedRefRe.ReplaceAllString(row.by, "")
	if strings.Trim(rest, " ,;") != "" {
		r.add(e, "V37", Error, src, row.line, "the Shipped by cell of %q holds text that is not a reference (%q)", row.name, strings.TrimSpace(rest))
	}
}
