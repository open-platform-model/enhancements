// Package testrepo builds temporary git repositories for tests.
package testrepo

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// New makes an empty git repo on branch main and returns its path.
func New(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init", "-q", "-b", "main"},
		{"config", "user.email", "dev@example.com"},
		{"config", "user.name", "Dev"},
		{"config", "commit.gpgsign", "false"},
	} {
		Git(t, dir, args...)
	}
	return dir
}

// Git runs git in dir and fails the test on an error.
func Git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return string(out)
}

// Write writes a file under dir, making its folders.
func Write(t *testing.T, dir, rel, text string) {
	t.Helper()
	p := filepath.Join(dir, filepath.FromSlash(rel))
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

// Commit stages everything and commits it, returning the short commit.
func Commit(t *testing.T, dir, message string) string {
	t.Helper()
	Git(t, dir, "add", "-A")
	Git(t, dir, "commit", "-q", "-m", message)
	return trim(Git(t, dir, "rev-parse", "--short", "HEAD"))
}

func trim(s string) string {
	for len(s) > 0 && (s[len(s)-1] == '\n' || s[len(s)-1] == '\r') {
		s = s[:len(s)-1]
	}
	return s
}
