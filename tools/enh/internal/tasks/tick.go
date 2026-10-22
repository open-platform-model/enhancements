package tasks

import (
	"os"
	"path/filepath"
	"regexp"

	"github.com/open-platform-model/enhancements/tools/enh/internal/record"
)

var (
	changeRefRe = regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`)
	prRefRe     = regexp.MustCompile(`^PR [0-9]+$`)
	commitRefRe = regexp.MustCompile(`^commit [0-9a-f]{7,40}$`)
)

// Tick ticks the line "n.m" of the entry's tasks.md and appends "(ref)": the
// change name without date, "PR <n>" for a repo with no OpenSpec change, or
// "commit <sha>" for the commit that delivers the line.
func (e *Env) Tick(key, line, ref string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en, err := live(st, key)
	if err != nil {
		return err
	}
	if en.Kind.Unnumbered() {
		return usage("%s is a %s and has no tasks.md", en.Base, kindWord(en))
	}
	if !changeRefRe.MatchString(ref) && !prRefRe.MatchString(ref) && !commitRefRe.MatchString(ref) {
		return usage("REF %q must be a change name (lower-case, hyphens), \"PR <n>\" or \"commit <sha>\"", ref)
	}
	path := filepath.Join(en.Dir, "tasks.md")
	src, err := os.ReadFile(path)
	if err != nil {
		return usage("%s has no tasks.md", en.Base)
	}
	out, err := record.Tick(string(src), line, ref)
	if err != nil {
		return refuse("%s: %v", en.Base, err)
	}
	if err := record.WriteFile(path, []byte(out)); err != nil {
		return err
	}
	e.printf("ticked %s in %s/tasks.md: (%s)\n", line, e.rel(en), ref)
	return e.indexAfter()
}
