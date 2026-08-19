package main

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

// materialize builds the scratch tree. Everything here is setup: it runs
// before any arm and is never inside a measurement, which is why it is free to
// shell out to the `cue` CLI.
func materialize(fixtures, work string, n int) (*tree, error) {
	fixtures, work = abs(fixtures), abs(work)
	if err := os.RemoveAll(work); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(work, 0o755); err != nil {
		return nil, err
	}

	t := &tree{Root: work, Platform: filepath.Join(work, "platform")}
	if err := copyTree(filepath.Join(fixtures, "platform"), t.Platform); err != nil {
		return nil, err
	}

	for i := 0; i < n; i++ {
		instDir := filepath.Join(work, fmt.Sprintf("instance-%d", i))
		if err := copyTree(filepath.Join(fixtures, "instance"), instDir); err != nil {
			return nil, err
		}
		// The one thing that differs between renders. A distinct instance name
		// changes the rendered value throughout (it reaches every resource's
		// labels and names), so no render can be answered out of another
		// render's evaluation state.
		if err := substitute(filepath.Join(instDir, "instance.cue"), "__NAME__", fmt.Sprintf("web-app-%d", i)); err != nil {
			return nil, err
		}
		t.Instances = append(t.Instances, instDir)

		renderDir := filepath.Join(work, fmt.Sprintf("render-%d", i))
		if err := copyTree(filepath.Join(fixtures, "render"), renderDir); err != nil {
			return nil, err
		}
		// local-module.cue is the COMPLETE main-module dependency view rather
		// than a patch (experiment 02, cue/load/config.go:581-620), so it is
		// generated with `cue mod edit --replace` instead of hand-written:
		// writing only the replaced entries silently drops the rest.
		if err := cueModEdit(renderDir,
			"--replace=experiments.opmodel.dev/0019/render-build-cost/instance@v0="+instDir,
			"--replace=experiments.opmodel.dev/0019/render-build-cost/platform@v0="+t.Platform,
		); err != nil {
			return nil, err
		}
		t.Renders = append(t.Renders, renderDir)
	}
	return t, nil
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
