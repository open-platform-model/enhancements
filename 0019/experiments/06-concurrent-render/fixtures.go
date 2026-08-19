package main

// Scratch-tree materialization, copied from experiments/04-render-build-cost
// and extended with -reuse. The extension exists because this experiment runs
// each strategy in its OWN process (a shared cue.Context may take the process
// down, and losing the other strategies' numbers with it would be careless),
// so the tree is built by the first process and reused by the rest.

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// tree is the materialized scratch layout. One platform, N instance modules,
// N render modules, each render module directory-replacing its own instance.
//
//	<work>/platform/            the D5 platform, identical for every render
//	<work>/instance-<i>/        one #ModuleInstance, distinct metadata.name
//	<work>/render-<i>/          the generated main module for render i
type tree struct {
	Root      string
	Platform  string
	Instances []string
	Renders   []string
}

// The fixture modules keep experiment 04's paths on purpose; see go.mod.
const (
	fixtureInstanceModule = "experiments.opmodel.dev/0019/render-build-cost/instance@v0"
	fixturePlatformModule = "experiments.opmodel.dev/0019/render-build-cost/platform@v0"
)

// materialize builds the scratch tree, or adopts an existing complete one when
// reuse is set. Everything here is setup: it runs before any strategy and is
// never inside a measurement, which is why it is free to shell out to `cue`.
func materialize(fixtures, work string, n int, reuse bool) (*tree, bool, error) {
	fixtures, work = abs(fixtures), abs(work)
	t := layout(work, n)

	if reuse && complete(t) {
		return t, true, nil
	}
	if err := os.RemoveAll(work); err != nil {
		return nil, false, err
	}
	if err := os.MkdirAll(work, 0o755); err != nil {
		return nil, false, err
	}
	if err := copyTree(filepath.Join(fixtures, "platform"), t.Platform); err != nil {
		return nil, false, err
	}

	for i := 0; i < n; i++ {
		instDir := t.Instances[i]
		if err := copyTree(filepath.Join(fixtures, "instance"), instDir); err != nil {
			return nil, false, err
		}
		// The one thing that differs between renders. A distinct instance name
		// changes the rendered value throughout (it reaches every resource's
		// labels and names), so no render can be answered out of another
		// render's evaluation state -- and, here, so a worker cannot be handed
		// a value another worker has already forced concrete.
		if err := substitute(filepath.Join(instDir, "instance.cue"), "__NAME__", fmt.Sprintf("web-app-%d", i)); err != nil {
			return nil, false, err
		}

		renderDir := t.Renders[i]
		if err := copyTree(filepath.Join(fixtures, "render"), renderDir); err != nil {
			return nil, false, err
		}
		// local-module.cue is the COMPLETE main-module dependency view rather
		// than a patch (experiment 02, cue/load/config.go:581-620), so it is
		// generated with `cue mod edit --replace` instead of hand-written:
		// writing only the replaced entries silently drops the rest.
		if err := cueModEdit(renderDir,
			"--replace="+fixtureInstanceModule+"="+instDir,
			"--replace="+fixturePlatformModule+"="+t.Platform,
		); err != nil {
			return nil, false, err
		}
	}
	return t, false, nil
}

func layout(work string, n int) *tree {
	t := &tree{Root: work, Platform: filepath.Join(work, "platform")}
	for i := 0; i < n; i++ {
		t.Instances = append(t.Instances, filepath.Join(work, fmt.Sprintf("instance-%d", i)))
		t.Renders = append(t.Renders, filepath.Join(work, fmt.Sprintf("render-%d", i)))
	}
	return t
}

// complete reports whether an existing tree covers every index this run needs.
// It checks the generated local-module.cue rather than the directory, because a
// half-materialized tree from an interrupted run would otherwise be adopted and
// fail obscurely inside a timed loop.
func complete(t *tree) bool {
	if _, err := os.Stat(filepath.Join(t.Platform, "cue.mod", "module.cue")); err != nil {
		return false
	}
	for i := range t.Renders {
		if _, err := os.Stat(filepath.Join(t.Renders[i], "cue.mod", "local-module.cue")); err != nil {
			return false
		}
		if _, err := os.Stat(filepath.Join(t.Instances[i], "instance.cue")); err != nil {
			return false
		}
	}
	return true
}

func cueModEdit(dir string, args ...string) error {
	cmd := exec.Command("cue", append([]string{"mod", "edit"}, args...)...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("cue mod edit in %s: %v: %s", dir, err, strings.TrimSpace(string(out)))
	}
	return nil
}

func substitute(path, old, new string) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if !strings.Contains(string(b), old) {
		return fmt.Errorf("%s: placeholder %q not found", path, old)
	}
	return os.WriteFile(path, []byte(strings.ReplaceAll(string(b), old, new)), 0o644)
}

func copyTree(src, dst string) error {
	return filepath.Walk(src, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, p)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		return copyFile(p, target)
	})
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}

func abs(p string) string {
	a, err := filepath.Abs(p)
	if err != nil {
		return p
	}
	return a
}
