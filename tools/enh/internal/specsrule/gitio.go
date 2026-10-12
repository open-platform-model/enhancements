package specsrule

import (
	"archive/tar"
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
)

// git runs git in the repository and returns standard output only. The rule
// reads blobs and tar streams, so standard error must not mix into the bytes.
func (c *checker) git(args ...string) ([]byte, error) {
	cmd := exec.Command("git", append([]string{"-C", c.opts.Root}, args...)...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if i := strings.IndexByte(msg, '\n'); i >= 0 {
			msg = msg[:i]
		}
		return nil, fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, msg)
	}
	return out, nil
}

func (c *checker) gitString(args ...string) (string, error) {
	out, err := c.git(args...)
	return strings.TrimSpace(string(out)), err
}

// change is one path of a name-status listing.
type change struct {
	Status byte // 'A', 'M' or 'D'
	Path   string
}

// diff lists the changed paths under dir between two commits. Renames are
// reported as a delete and an add.
func (c *checker) diff(base, head, dir string) ([]change, error) {
	out, err := c.git("diff", "--name-status", "--no-renames", "-z", base, head, "--", dir)
	if err != nil {
		return nil, err
	}
	parts := strings.Split(string(out), "\x00")
	var list []change
	for i := 0; i+1 < len(parts); i += 2 {
		if parts[i] == "" {
			continue
		}
		list = append(list, change{Status: parts[i][0], Path: parts[i+1]})
	}
	return list, nil
}

// exists reports whether any file lives under dir at the commit.
func (c *checker) exists(commit, dir string) (bool, error) {
	out, err := c.git("ls-tree", "-r", "--name-only", commit, "--", dir)
	return len(bytes.TrimSpace(out)) > 0, err
}

// show returns the file at the commit.
func (c *checker) show(commit, file string) ([]byte, error) {
	return c.git("show", commit+":"+file)
}

// untar reads a tar stream of regular files and calls put with the path and
// content of each. It refuses a path that leaves the archive root.
func untar(data []byte, put func(name string, body []byte, exec bool) error) error {
	return untarKinds(data, put, nil)
}

// untarKinds is untar with a callback for each entry that is not a regular
// file or a directory (a symlink, for one).
func untarKinds(data []byte, put func(name string, body []byte, exec bool) error, other func(name string)) error {
	tr := tar.NewReader(bytes.NewReader(data))
	for {
		h, err := tr.Next()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return err
		}
		if h.Typeflag != tar.TypeReg {
			if h.Typeflag != tar.TypeDir && h.Typeflag != tar.TypeXGlobalHeader && other != nil {
				other(path.Clean(h.Name))
			}
			continue // directories come with their files
		}
		name := path.Clean(h.Name)
		if path.IsAbs(name) || name == ".." || strings.HasPrefix(name, "../") {
			return fmt.Errorf("tar path %q leaves the archive", h.Name)
		}
		body, err := io.ReadAll(tr)
		if err != nil {
			return err
		}
		if err := put(name, body, h.Mode&0o111 != 0); err != nil {
			return err
		}
	}
}

// archiveTree returns `git archive commit -- paths` as a tar stream.
func (c *checker) archiveTree(commit string, paths ...string) ([]byte, error) {
	return c.git(append([]string{"archive", "--format=tar", commit, "--"}, paths...)...)
}

// writeTree writes a tar stream under dir, mapping each name through rename.
func writeTree(data []byte, dir string, rename func(string) (string, bool)) error {
	return untar(data, func(name string, body []byte, exe bool) error {
		to, ok := rename(name)
		if !ok {
			return nil
		}
		full := filepath.Join(dir, filepath.FromSlash(to))
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			return err
		}
		mode := os.FileMode(0o644)
		if exe {
			mode = 0o755
		}
		return os.WriteFile(full, body, mode)
	})
}
