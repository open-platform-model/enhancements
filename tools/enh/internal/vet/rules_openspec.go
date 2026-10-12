package vet

import (
	"fmt"
	"sort"
	"strings"
)

// openspecValidate runs V32 (`openspec validate <change>`, not strict) at
// accept and deliver, and V35 (the strict run) when the options ask for it.
func (r *run) openspecValidate(e *ent) {
	if r.opts.OpenSpec == nil || e.Archived {
		return
	}
	if e.mode >= Accept {
		if out, err := r.opts.OpenSpec(r.store.Root, "openspec", "validate", e.Folder); err != nil {
			r.add(e, "V32", Error, e.rel, 0, "openspec validate %s failed: %s", e.Folder, summary(out, err))
		}
	}
	if r.opts.Strict {
		r.strictValidate(e)
	}
}

// strictValidate runs V35 for one entry: `openspec validate <change> --strict`.
func (r *run) strictValidate(e *ent) {
	if out, err := r.opts.OpenSpec(r.store.Root, "openspec", "validate", e.Folder, "--strict"); err != nil {
		r.add(e, "V35", Error, e.rel, 0, "openspec validate %s --strict failed: %s", e.Folder, summary(out, err))
	}
}

// v35Only is the whole run of Options.V35Only: V35 for each selected live
// entry and seed, then for openspec/specs. Archived folders are not validated
// (OpenSpec has archived them), and a legacy folder is not converted yet.
func (r *run) v35Only() (*Result, error) {
	if r.opts.OpenSpec == nil {
		return nil, fmt.Errorf("vet: V35 needs the openspec runner")
	}
	for _, e := range r.store.All() {
		if !r.selected(e) || e.Archived {
			continue
		}
		r.res.Checked = append(r.res.Checked, e.Folder)
		r.strictValidate(&ent{Entry: e, rel: relSlash(r.store.Root, e.Dir)})
	}
	r.validateSpecsStrict()
	sort.SliceStable(r.res.Findings, func(i, j int) bool {
		a, b := r.res.Findings[i], r.res.Findings[j]
		return a.Entry+"|"+a.Path < b.Entry+"|"+b.Path
	})
	return r.res, nil
}

// validateSpecsStrict runs `openspec validate --specs --strict` once.
func (r *run) validateSpecsStrict() {
	if len(r.store.Specs) == 0 {
		return
	}
	if out, err := r.opts.OpenSpec(r.store.Root, "openspec", "validate", "--specs", "--strict"); err != nil {
		r.add(nil, "V35", Error, "openspec/specs", 0, "openspec validate --specs --strict failed: %s", summary(out, err))
	}
}

// summary shortens the output of a failed run to its first lines.
func summary(out []byte, err error) string {
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) > 6 {
		lines = append(lines[:6], "...")
	}
	s := strings.Join(lines, " | ")
	if s == "" || s == "..." {
		return err.Error()
	}
	return s
}
