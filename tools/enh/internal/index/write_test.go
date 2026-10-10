package index

import (
	"bytes"
	"crypto/sha256"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

// copyTree copies the fixture into a new temporary folder.
func copyTree(t *testing.T) string {
	t.Helper()
	dst := t.TempDir()
	src := os.DirFS(fixture)
	err := fs.WalkDir(src, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		target := filepath.Join(dst, filepath.FromSlash(p))
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		b, err := fs.ReadFile(src, p)
		if err != nil {
			return err
		}
		return os.WriteFile(target, b, 0o644)
	})
	if err != nil {
		t.Fatal(err)
	}
	return dst
}

// hashes returns the digest of every file under dir/sub.
func hashes(t *testing.T, dir, sub string) map[string][32]byte {
	t.Helper()
	out := map[string][32]byte{}
	root := filepath.Join(dir, filepath.FromSlash(sub))
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := os.ReadFile(p)
		out[p] = sha256.Sum256(b)
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func generateIn(t *testing.T, root string) []File {
	t.Helper()
	tree, err := Load(os.DirFS(root))
	if err != nil {
		t.Fatal(err)
	}
	files, err := Generate(tree)
	if err != nil {
		t.Fatal(err)
	}
	return files
}

func TestWrite_writesOnlyChangesAndNeverSpecs(t *testing.T) {
	root := copyTree(t)
	specsBefore := hashes(t, root, "openspec/specs")
	archiveBefore := hashes(t, root, "archive")
	files := generateIn(t, root)

	changed, err := Write(root, files)
	if err != nil {
		t.Fatalf("Write: %v", err)
	}
	if len(changed) != len(files) {
		t.Errorf("first Write changed %d files, want all %d", len(changed), len(files))
	}
	for _, f := range files {
		got, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(f.Path)))
		if err != nil || !bytes.Equal(got, f.Content) {
			t.Errorf("%s on disk differs from the generated content (read error %v)", f.Path, err)
		}
	}
	if !equalHashes(specsBefore, hashes(t, root, "openspec/specs")) {
		t.Error("Write changed a file under openspec/specs/")
	}
	if !equalHashes(archiveBefore, hashes(t, root, "archive")) {
		t.Error("Write changed a file under the old archive/")
	}

	// A second run changes nothing and leaves the modification times alone.
	readme := filepath.Join(root, "INDEX.md")
	old := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	if err := os.Chtimes(readme, old, old); err != nil {
		t.Fatal(err)
	}
	changed, err = Write(root, generateIn(t, root))
	if err != nil {
		t.Fatalf("second Write: %v", err)
	}
	if len(changed) != 0 {
		t.Errorf("second Write changed %v, want nothing", changed)
	}
	if fi, _ := os.Stat(readme); !fi.ModTime().Equal(old) {
		t.Error("second Write touched an unchanged file")
	}

	// Leftover temporary files would show in the tree.
	_ = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err == nil && strings.HasSuffix(p, ".tmp") {
			t.Errorf("temporary file left behind: %s", p)
		}
		return nil
	})
}

func equalHashes(a, b map[string][32]byte) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if b[k] != v {
			return false
		}
	}
	return true
}

func TestWrite_refusesBeforeWritingAnything(t *testing.T) {
	root := t.TempDir()
	files := []File{
		{Path: "INDEX.md", Content: []byte("x\n")},
		{Path: "openspec/specs/cap/spec.md", Content: []byte("x\n")},
	}
	if _, err := Write(root, files); err == nil {
		t.Fatal("Write of a path under specs/ returned no error")
	}
	if _, err := os.Stat(filepath.Join(root, "INDEX.md")); err == nil {
		t.Error("Write wrote INDEX.md before it refused the second file")
	}
	for _, p := range []string{"../escape.md", "/abs.md"} {
		if _, err := Write(root, []File{{Path: p, Content: []byte("x")}}); err == nil {
			t.Errorf("Write(%q) returned no error", p)
		}
	}
}

func TestFresh(t *testing.T) {
	root := copyTree(t)

	diffs, err := Fresh(os.DirFS(root))
	if err != nil {
		t.Fatalf("Fresh: %v", err)
	}
	if len(diffs) != len(generateIn(t, root)) {
		t.Fatalf("a tree with no generated file: %d differences, want one per generated file", len(diffs))
	}
	for _, d := range diffs {
		if d.Kind != Missing {
			t.Errorf("%s: kind %s, want %s", d.Path, d.Kind, Missing)
		}
	}

	if _, err := Write(root, generateIn(t, root)); err != nil {
		t.Fatal(err)
	}
	if diffs, err := Fresh(os.DirFS(root)); err != nil || len(diffs) != 0 {
		t.Fatalf("Fresh after Write = %v, %v; want no difference", diffs, err)
	}

	// A config change makes INDEX.md, GRAPH.md and the README stale; nothing else.
	cfg := filepath.Join(root, "openspec/changes/0041-all-shipped/config.yaml")
	b, _ := os.ReadFile(cfg)
	if err := os.WriteFile(cfg, bytes.Replace(b, []byte("title: All Shipped"), []byte("title: All Done"), 1), 0o644); err != nil {
		t.Fatal(err)
	}
	diffs, err = Fresh(os.DirFS(root))
	if err != nil {
		t.Fatal(err)
	}
	var paths []string
	for _, d := range diffs {
		paths = append(paths, d.Path)
		if d.Kind != Stale || !strings.Contains(d.Diff, "All Done") || !strings.Contains(d.Diff, "-") {
			t.Errorf("%s: kind %s, diff %q; want a stale diff that shows the new title", d.Path, d.Kind, d.Diff)
		}
	}
	want := []string{"GRAPH.md", "INDEX.md", "openspec/changes/0041-all-shipped/README.md"}
	if !slices.Equal(paths, want) {
		t.Errorf("stale paths = %v, want %v", paths, want)
	}

	// A hand edit of a generated file is reported, and a deleted one is missing.
	if _, err := Write(root, generateIn(t, root)); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(root, "GRAPH.md")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "INDEX.md"), []byte("by hand\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	diffs, err = Fresh(os.DirFS(root))
	if err != nil {
		t.Fatal(err)
	}
	kinds := map[string]string{}
	for _, d := range diffs {
		kinds[d.Path] = d.Kind
	}
	if kinds["GRAPH.md"] != Missing || kinds["INDEX.md"] != Stale || len(kinds) != 2 {
		t.Errorf("differences = %v, want GRAPH.md missing and INDEX.md stale", kinds)
	}
}

func TestFresh_loadErrorIsAnError(t *testing.T) {
	root := copyTree(t)
	if err := os.Remove(filepath.Join(root, "openspec/changes/0041-all-shipped/config.yaml")); err != nil {
		t.Fatal(err)
	}
	if _, err := Fresh(os.DirFS(root)); err == nil {
		t.Error("Fresh of a tree with a broken entry returned no error")
	}
}

func TestLineDiff(t *testing.T) {
	got := lineDiff("a\nb\nc\n", "a\nX\nc\n")
	if want := "@@ line 2 @@\n-b\n+X\n"; got != want {
		t.Errorf("lineDiff = %q, want %q", got, want)
	}
	var old, now strings.Builder
	for range 30 {
		old.WriteString("old\n")
		now.WriteString("new\n")
	}
	got = lineDiff(old.String(), now.String())
	if !strings.Contains(got, "-... 10 more lines") || !strings.Contains(got, "+... 10 more lines") {
		t.Errorf("lineDiff does not cap long output:\n%s", got)
	}
}
