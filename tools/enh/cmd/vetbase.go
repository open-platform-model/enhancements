package cmd

import (
	"path/filepath"
	"strings"
)

// defaultBases are the refs `enh vet` tries when --base is not given: the
// remote branch first, since a local main can lag behind it.
var defaultBases = []string{"origin/main", "main"}

// vetBase returns the base ref for V7, V27 and V31. An explicit --base wins and
// is passed on as given. Without one it takes the first of origin/main and
// main that names a commit, and only when root is the top level of its
// repository (the git rules read paths from the top level). It returns "" when
// nothing fits, and vet then prints its skipped line.
func (c *call) vetBase(root string) string {
	if c.o.base != "" {
		return c.o.base
	}
	out, err := c.d.Runner(root, "git", "rev-parse", "--show-toplevel")
	if err != nil || !sameDir(strings.TrimSpace(string(out)), root) {
		return ""
	}
	for _, ref := range defaultBases {
		if _, err := c.d.Runner(root, "git", "rev-parse", "--verify", "--quiet", ref+"^{commit}"); err == nil {
			return ref
		}
	}
	return ""
}

func sameDir(a, b string) bool {
	ra, err := filepath.EvalSymlinks(a)
	if err != nil {
		return false
	}
	rb, err := filepath.EvalSymlinks(b)
	if err != nil {
		return false
	}
	return ra == rb
}
