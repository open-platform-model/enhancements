package vet

import (
	"regexp"
	"strings"
	"unicode/utf8"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
)

var (
	shallRe      = regexp.MustCompile(`\b(SHALL|MUST)\b`)
	replacedRe   = regexp.MustCompile(`(?i)\breplaced by\b`)
	replacedForm = regexp.MustCompile(`^Replaced by "([^"]+)"$`)

	urlRe            = regexp.MustCompile(`https?://\S+`)
	cueDefRe         = regexp.MustCompile(`#[A-Za-z_]\w*(\.\w+)*`)
	pathRe           = regexp.MustCompile(`[\w.-]+(?:/[\w.-]+)+\.(?:go|cue|yaml|yml|json|md|sh|toml|mod|sum|txt)\b|\b(?:internal|cmd|pkg)/[\w./-]+|(?:^|[\s(` + "`" + `"'])\.{1,2}/[\w./-]+`)
	bareFileRe       = regexp.MustCompile(`\b[\w-]+\.(?:go|yaml|yml|toml|mod|sum|sh)\b`)
	flagRe           = regexp.MustCompile("(?:^|[\\s(`\"'])(--[a-z][a-z0-9-]*)")
	symbolRe         = regexp.MustCompile(`\b[a-z][a-z0-9]*\.[A-Z][A-Za-z0-9]*\b`)
	callRe           = regexp.MustCompile(`\b[A-Za-z_][A-Za-z0-9_]*\(\)`)
	placeholderStart = regexp.MustCompile(`(?i)^(tbd|todo)\b`)
)

// admissionHits lists what the admission test refuses in a requirement text:
// a file path, a CLI flag and a Go symbol. A published CUE definition (#Name)
// is allowed and is removed first; whether it is published, not internal, is
// judged in the accept sample, not here (DECISIONS.md 2026-10-10 21:50).
func admissionHits(text string) (paths, flags, symbols []string) {
	text = urlRe.ReplaceAllString(text, " ")
	text = cueDefRe.ReplaceAllString(text, " ")
	for _, m := range pathRe.FindAllString(text, -1) {
		paths = append(paths, strings.TrimSpace(strings.Trim(m, "`\"'(")))
	}
	for _, m := range bareFileRe.FindAllString(text, -1) {
		if !endsWithAny(paths, m) {
			paths = append(paths, m)
		}
	}
	for _, m := range flagRe.FindAllStringSubmatch(text, -1) {
		flags = append(flags, m[1])
	}
	symbols = append(symbols, symbolRe.FindAllString(text, -1)...)
	symbols = append(symbols, callRe.FindAllString(text, -1)...)
	return dedupe(paths), dedupe(flags), dedupe(symbols)
}

func dedupe(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range in {
		if s != "" && !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}

// deltaRules runs V13, V16 to V21, V33 (ADDED only) and V34 on the delta
// specs of one entry.
func (r *run) deltaRules(e *ent) {
	added := map[string]bool{} // every ADDED name of the entry, for V21
	for _, sp := range e.Specs {
		for _, q := range sp.By(delta.Added) {
			added[q.Name] = true
		}
		for _, rn := range sp.Renames {
			added[rn.To] = true
		}
	}
	// A correction changes delivered requirements, so its targets are checked
	// in every mode; an entry checks them from accept.
	targetLevel := e.from(Accept, Error)
	if e.isCorrection() {
		targetLevel = Error
	}
	for _, sp := range e.Specs {
		path := relSlash(r.store.Root, sp.Path)
		main := r.store.Specs[sp.Capability]
		mainNames := map[string]bool{}
		if main != nil {
			for _, q := range main.By(delta.Main) {
				mainNames[q.Name] = true
			}
		}
		r.purposeRule(e, sp, path, main != nil)
		for _, rn := range sp.UnpairedRenames {
			r.add(e, "V20", targetLevel, path, rn, "RENAMED line has no FROM and TO pair")
		}

		for _, q := range sp.Requirements {
			switch q.Op {
			case delta.Added, delta.Modified:
				r.requirementRules(e, q, path)
			case delta.Removed:
				r.removedRules(e, q, path, added)
			}
			// V20: targets exist in specs/, an ADDED name is new.
			switch q.Op {
			case delta.Modified, delta.Removed:
				if !mainNames[q.Name] {
					r.add(e, "V20", targetLevel, path, q.Line, "%s target %q is not in openspec/specs/%s", q.Op, q.Name, sp.Capability)
				}
			case delta.Added:
				if mainNames[q.Name] {
					r.add(e, "V20", targetLevel, path, q.Line, "ADDED requirement %q is already in openspec/specs/%s", q.Name, sp.Capability)
				}
			}
			if e.isSeed() && q.Op != delta.Added {
				r.add(e, "V33", Error, path, q.Line, "a seed holds ADDED requirements only; found %s", q.Op)
			}
		}
		for _, rn := range sp.Renames {
			if !mainNames[rn.From] {
				r.add(e, "V20", targetLevel, path, rn.Line, "RENAMED source %q is not in openspec/specs/%s", rn.From, sp.Capability)
			}
			if e.isSeed() {
				r.add(e, "V33", Error, path, rn.Line, "a seed holds ADDED requirements only; found RENAMED")
			}
		}
		r.retireRule(e, sp, path, main)
	}
}

// requirementRules: V16, V17, V18, V19 on an ADDED or MODIFIED block.
func (r *run) requirementRules(e *ent, q delta.Requirement, path string) {
	if n := len(strings.Fields(q.Name)); n > 8 {
		r.add(e, "V16", Warning, path, q.Line, "requirement name %q has %d words; the advice is at most 8", q.Name, n)
	}
	if n := utf8.RuneCountInString(q.Text); n > 500 {
		r.add(e, "V16", Warning, path, q.Line, "requirement %q has %d characters of text; the advice is at most 500", q.Name, n)
	}
	if q.RealScenarios() == 0 {
		r.add(e, "V17", Error, path, q.Line, "requirement %q has no #### Scenario with a body", q.Name)
	}
	if !shallRe.MatchString(q.Text) {
		r.add(e, "V18", Error, path, q.Line, "requirement %q has no SHALL or MUST in its text", q.Name)
	}
	paths, flags, syms := admissionHits(q.Text)
	if len(paths) > 0 {
		r.add(e, "V19", Error, path, q.Line, "requirement %q names a file path (%s); the admission test refuses it", q.Name, strings.Join(paths, ", "))
	}
	if len(flags) > 0 {
		r.add(e, "V19", Error, path, q.Line, "requirement %q names a CLI flag (%s); the admission test refuses it", q.Name, strings.Join(flags, ", "))
	}
	if len(syms) > 0 {
		r.add(e, "V19", Error, path, q.Line, "requirement %q names a Go symbol (%s); the admission test refuses it", q.Name, strings.Join(syms, ", "))
	}
}

// removedRules: V21.
func (r *run) removedRules(e *ent, q delta.Requirement, path string, added map[string]bool) {
	if q.Bullet {
		r.add(e, "V21", Error, path, q.Line, "REMOVED requirement %q is a list item, which cannot carry **Reason** and **Migration**; write a ### Requirement block", q.Name)
		return
	}
	if !q.HasReason || q.Reason == "" {
		r.add(e, "V21", Error, path, q.Line, "REMOVED requirement %q has no **Reason**", q.Name)
	}
	if !q.HasMigration || q.Migration == "" {
		r.add(e, "V21", Error, path, q.Line, "REMOVED requirement %q has no **Migration**", q.Name)
		return
	}
	if !replacedRe.MatchString(q.Migration) {
		return
	}
	m := replacedForm.FindStringSubmatch(q.Migration)
	if m == nil {
		r.add(e, "V21", Error, path, q.Line, `REMOVED requirement %q: a reversal reads exactly **Migration**: Replaced by "<new name>"`, q.Name)
		return
	}
	if !added[delta.NormalizeName(m[1])] {
		r.add(e, "V21", Error, path, q.Line, "REMOVED requirement %q is replaced by %q, but the entry has no ADDED requirement of that name", q.Name, m[1])
	}
}

// V34: a delta that creates a capability has a usable Purpose.
func (r *run) purposeRule(e *ent, sp *delta.Spec, path string, mainExists bool) {
	if mainExists || len(sp.By(delta.Added)) == 0 {
		return
	}
	lv := e.from(Accept, Error)
	switch {
	case !sp.HasPurpose:
		r.add(e, "V34", lv, path, 0, "capability %q is new but the delta has no ## Purpose", sp.Capability)
	case utf8.RuneCountInString(sp.Purpose) < 50:
		r.add(e, "V34", lv, path, sp.PurposeLine, "Purpose of new capability %q has %d characters; OpenSpec wants at least 50", sp.Capability, utf8.RuneCountInString(sp.Purpose))
	case placeholderStart.MatchString(sp.Purpose) || strings.Contains(sp.Purpose, "TBD - created by archiving change"):
		r.add(e, "V34", lv, path, sp.PurposeLine, "Purpose of new capability %q is a placeholder", sp.Capability)
	}
}

// V13: a REMOVED that takes the last requirement of a capability needs
// retire_capabilities: true.
func (r *run) retireRule(e *ent, sp *delta.Spec, path string, main *delta.Spec) {
	// A correction never retires a capability; V36 refuses it with its own message.
	if e.isCorrection() || main == nil || len(main.By(delta.Main)) == 0 || e.RetireCaps {
		return
	}
	removed := map[string]bool{}
	for _, q := range sp.By(delta.Removed) {
		removed[q.Name] = true
	}
	for _, rn := range sp.Renames {
		removed[rn.From] = true
	}
	if len(sp.By(delta.Added)) > 0 || len(sp.Renames) > 0 {
		return
	}
	for _, q := range main.By(delta.Main) {
		if !removed[q.Name] {
			return
		}
	}
	r.add(e, "V13", e.from(Deliver, Error), path, 0, "the REMOVED blocks take every requirement of capability %q; set retire_capabilities: true in .openspec.yaml", sp.Capability)
}

// endsWithAny reports whether one of the paths already ends with the file name.
func endsWithAny(paths []string, name string) bool {
	for _, p := range paths {
		if strings.HasSuffix(p, name) {
			return true
		}
	}
	return false
}
