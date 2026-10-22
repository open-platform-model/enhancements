package vet

import (
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/shipped"
)

// opRenamed is the operation of a RENAMED block; the delta package keeps
// renames apart from requirement blocks.
const opRenamed delta.Op = "RENAMED"

var (
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

// correctionOverlap warns when a live numbered entry has a delta spec for a
// capability that the correction corrects: after the correction is delivered,
// the entry may carry a stale base. The warning names the entry and the
// capabilities.
func (r *run) correctionOverlap(e *ent) {
	corrected := map[string]bool{}
	for _, sp := range e.Specs {
		corrected[sp.Capability] = true
	}
	for _, o := range r.store.Live {
		if o.Kind != entry.Enhancement {
			continue
		}
		var caps []string
		for _, sp := range o.Specs {
			if corrected[sp.Capability] {
				caps = append(caps, sp.Capability)
			}
		}
		if len(caps) == 0 {
			continue
		}
		sort.Strings(caps)
		r.add(e, "V36", Warning, e.rel, 0, "live entry %s has delta specs for capability %s, which this correction also changes; the entry may carry a stale base after this correction is delivered", o.Folder, strings.Join(caps, ", "))
	}
}

// correctionEvidence runs V37: every requirement block of the deltas has one
// row that names the change that shipped it, and the rows name nothing else.
func (r *run) correctionEvidence(e *ent) {
	if !e.Source.Exists {
		return // sourceRules reports the missing file
	}
	src := e.rel + "/source.md"
	rows, found := shipped.Parse(e.Source.Text)
	if !found {
		r.add(e, "V37", Error, src, 0, "source.md has no \"## Shipped by\" table")
		return
	}
	// What the deltas hold: key -> display, plus the names a REMOVED replaces.
	want := map[string]string{}
	opsOf := map[string][]string{}            // capability|name -> operations
	replaced := shipped.Replacements(e.Specs) // an ADDED that replaces a REMOVED needs no code read
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
		}
		for _, rn := range sp.Renames {
			note(sp.Capability, delta.NormalizeName(rn.To), opRenamed)
		}
	}
	seen := map[string]bool{}
	for _, row := range rows {
		if row.Cells < 5 {
			r.add(e, "V37", Error, src, row.Line, "a Shipped by row has %d cells; it needs Capability, Requirement, Change, Shipped by and Code read", row.Cells)
			continue
		}
		k := row.Key()
		_, inDelta := want[k]
		switch {
		case !inDelta && len(opsOf[row.Capability+"\x00"+row.Name]) > 0:
			r.add(e, "V37", Error, src, row.Line, "the row for %q in %s says %s, but the delta says %s", row.Name, row.Capability, row.Op, strings.Join(opsOf[row.Capability+"\x00"+row.Name], " and "))
			continue
		case !inDelta:
			r.add(e, "V37", Error, src, row.Line, "the row for %q in %s names no requirement of the deltas", row.Name, row.Capability)
			continue
		case seen[k]:
			r.add(e, "V37", Error, src, row.Line, "two rows for %s", want[k])
			continue
		}
		seen[k] = true
		r.shippedRefs(e, src, row)
		needsCode := row.Op == string(delta.Modified) ||
			(row.Op == string(delta.Added) && !replaced[row.Capability+"\x00"+row.Name])
		if needsCode && !codeSpanRe.MatchString(row.Code) {
			r.add(e, "V37", Error, src, row.Line, "the row for %s needs the code read, as `path:line` in a code span", want[k])
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
func (r *run) shippedRefs(e *ent, src string, row shipped.Row) {
	refs := shippedRefRe.FindAllStringSubmatch(row.By, -1)
	if len(refs) == 0 {
		r.add(e, "V37", Error, src, row.Line, "the row for %q has no reference; write `<repo>` PR <n> or `<repo>` commit <sha>", row.Name)
		return
	}
	for _, m := range refs {
		if !r.schema.IsRepo(m[1]) {
			r.add(e, "V37", Error, src, row.Line, "the row for %q names repo %q, which #EntryRepo in schema.cue does not list", row.Name, m[1])
		}
	}
	rest := shippedRefRe.ReplaceAllString(row.By, "")
	if strings.Trim(rest, " ,;") != "" {
		r.add(e, "V37", Error, src, row.Line, "the Shipped by cell of %q holds text that is not a reference (%q)", row.Name, strings.TrimSpace(rest))
	}
}
