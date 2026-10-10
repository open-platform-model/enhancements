// Package sys runs the external programs of enh: git and the openspec CLI.
// Every call goes through a Runner, so a test can replace the program.
package sys

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Runner runs a program in dir and returns its combined output. It has the
// same shape as vet.Runner, so one value serves both.
type Runner func(dir, name string, args ...string) ([]byte, error)

// Exec runs the program with an argument vector and no shell. The telemetry of
// the OpenSpec CLI is off and its colour too.
func Exec(dir, name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "OPENSPEC_TELEMETRY=0", "NO_COLOR=1")
	return cmd.CombinedOutput()
}

// Git wraps a Runner for the git calls of enh. Root is any directory of the
// checkout.
type Git struct {
	Root string
	Run  Runner
}

func (g Git) run(args ...string) (string, error) {
	out, err := g.Run(g.Root, "git", args...)
	s := strings.TrimRight(string(out), "\r\n")
	if err != nil {
		return s, fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, firstLine(s))
	}
	return s, nil
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}

// MergeBase returns the short commit the current branch started from, which
// is the commit of ref the accept PR is cut from. ref is a local branch name.
func (g Git) MergeBase(ref string) (string, error) {
	full, err := g.run("merge-base", "HEAD", ref)
	if err != nil {
		return "", fmt.Errorf("no merge base with %q (use --base to name the main branch): %w", ref, err)
	}
	return g.run("rev-parse", "--short", full)
}

// Head returns the full commit that HEAD names.
func (g Git) Head() (string, error) {
	return g.run("rev-parse", "HEAD")
}

// HasCommit reports whether commit names a commit of the repo.
func (g Git) HasCommit(commit string) bool {
	_, err := g.run("cat-file", "-e", commit+"^{commit}")
	return err == nil
}

// Exists reports whether path exists in the tree of commit.
func (g Git) Exists(commit, path string) bool {
	_, err := g.run("cat-file", "-e", commit+":"+path)
	return err == nil
}

// Show returns the file path at commit.
func (g Git) Show(commit, path string) ([]byte, error) {
	out, err := g.Run(g.Root, "git", "show", commit+":"+path)
	if err != nil {
		return nil, fmt.Errorf("git show %s:%s: %w", commit, path, err)
	}
	return out, nil
}

// Files lists the files under dir at commit, as paths from the repo root.
func (g Git) Files(commit, dir string) ([]string, error) {
	s, err := g.run("ls-tree", "-r", "--name-only", commit, "--", dir)
	if err != nil {
		return nil, err
	}
	if s == "" {
		return nil, nil
	}
	return strings.Split(s, "\n"), nil
}

// LastWriter returns the newest commit on ref whose change touched a line of
// path that matches the regular expression pattern, or "" when none did.
func (g Git) LastWriter(ref, pattern, path string) (string, error) {
	s, err := g.run("log", "-n", "1", "--format=%h", "-G"+pattern, ref, "--", path)
	if err != nil {
		return "", err
	}
	return s, nil
}

// Branches lists the local and remote branch names, no fetch.
func (g Git) Branches() ([]string, error) {
	s, err := g.run("branch", "-a", "--format=%(refname:short)")
	if err != nil {
		return nil, err
	}
	if s == "" {
		return nil, nil
	}
	return strings.Split(s, "\n"), nil
}

// UserEmail returns the configured author address, or "".
func (g Git) UserEmail() string {
	s, err := g.run("config", "user.email")
	if err != nil {
		return ""
	}
	return s
}

// Clean reports whether the working tree has no change and no untracked file.
func (g Git) Clean() (bool, error) {
	s, err := g.run("status", "--porcelain")
	if err != nil {
		return false, err
	}
	return s == "", nil
}

// Commit stages the pathspecs (additions, changes and removals under them) and
// makes one commit. Only the given paths are staged.
func (g Git) Commit(message string, paths ...string) error {
	args := append([]string{"add", "-A", "--"}, paths...)
	if _, err := g.run(args...); err != nil {
		return err
	}
	_, err := g.run("commit", "-m", message)
	return err
}

// Dir returns the path of a file kept inside the git directory, such as the
// marker of a plain run. The git directory is private to a worktree.
func (g Git) Dir(name string) (string, error) {
	s, err := g.run("rev-parse", "--git-path", name)
	if err != nil {
		return "", err
	}
	if !filepath.IsAbs(s) {
		s = filepath.Join(g.Root, s)
	}
	return s, nil
}

// ArchiveOrder returns the order in which the folders under
// openspec/changes/archive first appeared in the history of HEAD, oldest
// first, to break a tie between two folders of one date.
func (g Git) ArchiveOrder() (map[string]int, error) {
	s, err := g.run("log", "--reverse", "--diff-filter=A", "--name-only", "--format=", "--", "openspec/changes/archive")
	if err != nil {
		return nil, err
	}
	const prefix = "openspec/changes/archive/"
	order := map[string]int{}
	for _, line := range strings.Split(s, "\n") {
		rest, ok := strings.CutPrefix(line, prefix)
		if !ok {
			continue
		}
		folder, _, _ := strings.Cut(rest, "/")
		if _, seen := order[folder]; !seen && folder != "" {
			order[folder] = len(order)
		}
	}
	return order, nil
}
