package sys

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/testrepo"
)

func TestGit(t *testing.T) {
	dir := testrepo.New(t)
	g := Git{Root: dir, Run: Exec}
	testrepo.Write(t, dir, "a/b.txt", "one\n")
	if err := g.Commit("docs: add a", "a"); err != nil {
		t.Fatal(err)
	}
	base, err := g.MergeBase("main")
	if err != nil || len(base) < 7 {
		t.Fatalf("MergeBase = %q, %v", base, err)
	}
	if !g.HasCommit(base) || g.HasCommit("deadbeefdeadbeef") {
		t.Error("HasCommit")
	}
	if !g.Exists(base, "a/b.txt") || g.Exists(base, "a/missing.txt") {
		t.Error("Exists")
	}
	b, err := g.Show(base, "a/b.txt")
	if err != nil || string(b) != "one\n" {
		t.Errorf("Show = %q, %v", b, err)
	}
	files, err := g.Files(base, "a")
	if err != nil || len(files) != 1 || files[0] != "a/b.txt" {
		t.Errorf("Files = %v, %v", files, err)
	}
	w, err := g.LastWriter("main", "^one", "a/b.txt")
	if err != nil || w == "" {
		t.Errorf("LastWriter = %q, %v", w, err)
	}
	if w, _ := g.LastWriter("main", "^never", "a/b.txt"); w != "" {
		t.Errorf("LastWriter of a pattern nobody wrote = %q", w)
	}
	if ok, err := g.Clean(); err != nil || !ok {
		t.Errorf("Clean = %v, %v", ok, err)
	}
	testrepo.Write(t, dir, "c.txt", "x")
	if ok, _ := g.Clean(); ok {
		t.Error("Clean with an untracked file")
	}
	if g.UserEmail() != "dev@example.com" {
		t.Errorf("UserEmail = %q", g.UserEmail())
	}
	br, err := g.Branches()
	if err != nil || len(br) != 1 || br[0] != "main" {
		t.Errorf("Branches = %v, %v", br, err)
	}
	p, err := g.Dir("enh/x")
	if err != nil || !strings.HasSuffix(p, filepath.Join(".git", "enh", "x")) {
		t.Errorf("Dir = %q, %v", p, err)
	}
	if _, err := g.MergeBase("nope"); err == nil {
		t.Error("MergeBase with an unknown ref succeeded")
	}
}
