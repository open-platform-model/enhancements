package specsrule

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// compareSpecs compares openspec/specs/ of the replayed scratch copy with the
// same folder at head, file by file, byte for byte. It returns one line for
// each difference, sorted by path.
func (c *checker) compareSpecs(scratch, head string) ([]string, error) {
	want := map[string][]byte{}
	err := filepath.WalkDir(filepath.Join(scratch, filepath.FromSlash(specsDir)), func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil // no specs/ in the replay: every head file is then extra
			}
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(scratch, p)
		if err != nil {
			return err
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		want[filepath.ToSlash(rel)] = b
		return nil
	})
	if err != nil {
		return nil, err
	}
	tarball, err := c.archiveTree(head, specsDir)
	if err != nil {
		// A head with no specs/ folder: git archive refuses the pathspec.
		if ok, e := c.exists(head, specsDir); e == nil && !ok {
			tarball = nil
		} else {
			return nil, err
		}
	}
	got := map[string][]byte{}
	if len(tarball) > 0 {
		if err := untar(tarball, func(name string, body []byte, _ bool) error {
			got[name] = body
			return nil
		}); err != nil {
			return nil, err
		}
	}
	var diffs []string
	for p, b := range want {
		g, ok := got[p]
		switch {
		case !ok:
			diffs = append(diffs, fmt.Sprintf("%s: the replay writes it, head lacks it", p))
		case !bytes.Equal(b, g):
			diffs = append(diffs, fmt.Sprintf("%s: head differs from the replay (%s)", p, firstDifference(b, g)))
		}
	}
	for p := range got {
		if _, ok := want[p]; !ok {
			diffs = append(diffs, fmt.Sprintf("%s: head has it, the replay does not write it", p))
		}
	}
	sort.Strings(diffs)
	return diffs, nil
}

// firstDifference names the first line where the replay and head differ.
func firstDifference(replay, head []byte) string {
	a, b := strings.Split(string(replay), "\n"), strings.Split(string(head), "\n")
	for i := 0; i < len(a) || i < len(b); i++ {
		var x, y string
		if i < len(a) {
			x = a[i]
		}
		if i < len(b) {
			y = b[i]
		}
		if i >= len(a) || i >= len(b) || x != y {
			return fmt.Sprintf("line %d: replay %q, head %q", i+1, clip(x), clip(y))
		}
	}
	return "same lines, different bytes"
}

func clip(s string) string {
	if len(s) > 60 {
		return s[:57] + "..."
	}
	return s
}
