package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// tree is the materialized scratch layout:
//
//	<work>/platform/                      the D5 platform, identical everywhere
//	<work>/mods/                          ONE CUE module holding
//	  fleet_bp/ fleet_raw/                  the four fixture module packages
//	  complex_bp/ complex_raw/
//	  i/<point>_n<idx>/                     one #ModuleInstance per render
//	<work>/render/                        ONE CUE module holding
//	  cue.mod/local-module.cue              generated ONCE by `cue mod edit`
//	  baseline/                             the baseline arm's platform-only build
//	  r/r_<point>_n<idx>/                   one generated render package per render
//
// One CUE module for every instance rather than one per render is the reason
// `cue mod edit` runs once instead of once per render: each generated render
// package imports a DIFFERENT package from the SAME replaced module, so
// cue.mod/local-module.cue is identical for all of them. That file is the
// complete main-module dependency view rather than a patch (experiment 02),
// which is why it is generated rather than hand-written.
type tree struct {
	Root     string
	Platform string
	Mods     string
	Render   string
	N        int
	Points   []point
}

func (t *tree) instDir(p point, idx int) string {
	return filepath.Join(t.Mods, "i", instPkg(p, idx))
}

func (t *tree) renderDir(p point, idx int) string {
	return filepath.Join(t.Render, "r", renderPkg(p, idx))
}

// materialize builds the scratch tree, or reuses one already on disk.
//
// Everything here is setup: it runs before any arm and is never inside a
// measurement, which is why it is free to shell out to the `cue` CLI. It
// returns whether the tree was reused, so a run always states which it did.
func materialize(fixtures, work string, points []point, n int, reuse bool) (*tree, bool, error) {
	fixtures, work = abs(fixtures), abs(work)
	t := &tree{
		Root:     work,
		Platform: filepath.Join(work, "platform"),
		Mods:     filepath.Join(work, "mods"),
		Render:   filepath.Join(work, "render"),
		N:        n,
		Points:   points,
	}

	if reuse && t.complete() {
		return t, true, nil
	}

	if err := os.RemoveAll(work); err != nil {
		return nil, false, err
	}
	if err := os.MkdirAll(work, 0o755); err != nil {
		return nil, false, err
	}
	for _, d := range []string{"platform", "mods", "render"} {
		if err := copyTree(filepath.Join(fixtures, d), filepath.Join(work, d)); err != nil {
			return nil, false, err
		}
	}

	for _, p := range points {
		for i := 0; i < n; i++ {
			id := t.instDir(p, i)
			if err := os.MkdirAll(id, 0o755); err != nil {
				return nil, false, err
			}
			if err := os.WriteFile(filepath.Join(id, "instance.cue"), []byte(instanceCUE(p, i)), 0o644); err != nil {
				return nil, false, err
			}
			rd := t.renderDir(p, i)
			if err := os.MkdirAll(rd, 0o755); err != nil {
				return nil, false, err
			}
			if err := os.WriteFile(filepath.Join(rd, "render.cue"), []byte(renderCUE(p, i)), 0o644); err != nil {
				return nil, false, err
			}
		}
	}

	if err := cueModEdit(t.Render,
		"--replace=experiments.opmodel.dev/0019/module-scale-cost/mods@v0="+t.Mods,
		"--replace=experiments.opmodel.dev/0019/module-scale-cost/platform@v0="+t.Platform,
	); err != nil {
		return nil, false, err
	}
	return t, false, nil
}

// complete reports whether an existing tree already carries every directory
// this run needs. Cheap and structural: it checks the generated files exist,
// not that they say what this build of the harness would generate. Delete
// _out/run (or drop -reuse) after editing gen.go.
func (t *tree) complete() bool {
	if _, err := os.Stat(filepath.Join(t.Render, "cue.mod", "local-module.cue")); err != nil {
		return false
	}
	for _, p := range t.Points {
		for i := 0; i < t.N; i++ {
			if _, err := os.Stat(filepath.Join(t.instDir(p, i), "instance.cue")); err != nil {
				return false
			}
			if _, err := os.Stat(filepath.Join(t.renderDir(p, i), "render.cue")); err != nil {
				return false
			}
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
