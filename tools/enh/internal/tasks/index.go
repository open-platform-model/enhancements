package tasks

import (
	"fmt"
	"os"
	"sort"

	"github.com/open-platform-model/enhancements/tools/enh/internal/index"
)

// Index writes README.md of every new-layout entry, INDEX.md and GRAPH.md. It
// never writes under openspec/specs/. It returns the paths that changed.
func (e *Env) Index() ([]string, error) {
	t, err := index.Load(os.DirFS(e.Root))
	if err != nil {
		return nil, err
	}
	files, err := index.Generate(t)
	if err != nil {
		return nil, err
	}
	changed, err := index.Write(e.Root, files)
	if err != nil {
		return nil, err
	}
	sort.Strings(changed)
	return changed, nil
}

// RunIndex is the command: it prints the changed files.
func (e *Env) RunIndex() error {
	changed, err := e.Index()
	if err != nil {
		return err
	}
	e.printIndex(changed)
	return nil
}

func (e *Env) printIndex(changed []string) {
	if len(changed) == 0 {
		e.printf("index: all generated files are up to date\n")
		return
	}
	for _, p := range changed {
		e.printf("index: wrote %s\n", p)
	}
}

// Fresh reports the generated files that are missing or stale. It writes
// nothing and returns a Refusal when any differ.
func (e *Env) Fresh() error {
	diffs, err := index.Fresh(os.DirFS(e.Root))
	if err != nil {
		return err
	}
	if len(diffs) == 0 {
		e.printf("fresh: generated files are up to date\n")
		return nil
	}
	for _, d := range diffs {
		fmt.Fprintf(e.Out, "%s: %s\n%s", d.Kind, d.Path, d.Diff)
	}
	return refuse("fresh: %d generated files are not up to date; run `enh index`", len(diffs))
}
