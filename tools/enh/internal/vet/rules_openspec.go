package vet

import (
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
		if out, err := r.opts.OpenSpec(r.store.Root, "openspec", "validate", e.Folder, "--strict"); err != nil {
			r.add(e, "V35", Error, e.rel, 0, "openspec validate %s --strict failed: %s", e.Folder, summary(out, err))
		}
	}
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
