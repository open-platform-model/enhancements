package index

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Output paths at the repo root.
const (
	IndexPath = "INDEX.md"
	GraphPath = "GRAPH.md"
)

// Generate returns every generated file of the tree, sorted by path: the
// README.md of each new-layout entry (live and archived), INDEX.md and
// GRAPH.md. The ten old-layout entries keep their hand-written READMEs. It
// returns no file when it returns an error.
func Generate(t *Tree) ([]File, error) {
	graph, err := Graphmd(t)
	if err != nil {
		return nil, err
	}
	files := []File{
		{Path: IndexPath, Content: Indexmd(t)},
		{Path: GraphPath, Content: graph},
	}
	for _, e := range t.Entries {
		if e.Layout != LayoutOpenSpec {
			continue
		}
		files = append(files, File{Path: readmePath(e), Content: Readme(e)})
	}
	for _, f := range files {
		if err := checkPath(f.Path); err != nil {
			return nil, err
		}
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	return files, nil
}

// Write writes the files under root and returns the paths whose content
// changed. A file with the same bytes is left alone. A path outside the repo or
// under specs/ is refused before any file is written.
func Write(root string, files []File) ([]string, error) {
	for _, f := range files {
		if err := checkPath(f.Path); err != nil {
			return nil, err
		}
	}
	var changed []string
	for _, f := range files {
		full := filepath.Join(root, filepath.FromSlash(f.Path))
		old, err := os.ReadFile(full)
		if err == nil && bytes.Equal(old, f.Content) {
			continue
		}
		if err != nil && !errors.Is(err, fs.ErrNotExist) {
			return changed, fmt.Errorf("index: read %s: %w", f.Path, err)
		}
		if err := replaceFile(full, f.Content); err != nil {
			return changed, fmt.Errorf("index: write %s: %w", f.Path, err)
		}
		changed = append(changed, f.Path)
	}
	return changed, nil
}

// replaceFile writes a temporary file beside the target and renames it over
// the target, so a failed write leaves the old file whole.
func replaceFile(full string, content []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(full), ".index-*.tmp")
	if err != nil {
		return err
	}
	name := tmp.Name()
	if _, err := tmp.Write(content); err != nil {
		_ = tmp.Close() // the write error is the one to report
		_ = os.Remove(name)
		return err
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(name)
		return err
	}
	if err := os.Chmod(name, 0o644); err != nil {
		_ = os.Remove(name)
		return err
	}
	if err := os.Rename(name, full); err != nil {
		_ = os.Remove(name)
		return err
	}
	return nil
}

// Difference kinds.
const (
	Missing = "missing"
	Stale   = "stale"
)

// Difference is one generated file that does not match the tree.
type Difference struct {
	Path string
	// Kind is Missing or Stale.
	Kind string
	// Diff is a short line diff of the file on disk against the generated one.
	Diff string
}

// Fresh regenerates every file in memory and reports each one that is missing
// or differs from the file on disk. It writes nothing. No difference means the
// generated files are fresh.
func Fresh(fsys fs.FS) ([]Difference, error) {
	t, err := Load(fsys)
	if err != nil {
		return nil, err
	}
	files, err := Generate(t)
	if err != nil {
		return nil, err
	}
	var diffs []Difference
	for _, f := range files {
		old, err := fs.ReadFile(fsys, f.Path)
		if errors.Is(err, fs.ErrNotExist) {
			diffs = append(diffs, Difference{Path: f.Path, Kind: Missing})
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("index: read %s: %w", f.Path, err)
		}
		if !bytes.Equal(old, f.Content) {
			diffs = append(diffs, Difference{Path: f.Path, Kind: Stale, Diff: lineDiff(string(old), string(f.Content))})
		}
	}
	return diffs, nil
}

const maxDiffLines = 20

// lineDiff shows the lines that differ, between the common head and the common
// tail of the two texts, at most maxDiffLines on each side.
func lineDiff(old, now string) string {
	a, b := strings.Split(old, "\n"), strings.Split(now, "\n")
	p := 0
	for p < len(a) && p < len(b) && a[p] == b[p] {
		p++
	}
	s := 0
	for s < len(a)-p && s < len(b)-p && a[len(a)-1-s] == b[len(b)-1-s] {
		s++
	}
	var out strings.Builder
	fmt.Fprintf(&out, "@@ line %d @@\n", p+1)
	emit := func(sign string, lines []string) {
		for i, l := range lines {
			if i == maxDiffLines {
				fmt.Fprintf(&out, "%s... %d more lines\n", sign, len(lines)-i)
				break
			}
			out.WriteString(sign + l + "\n")
		}
	}
	emit("-", a[p:len(a)-s])
	emit("+", b[p:len(b)-s])
	return out.String()
}
