package cmd

import (
	"bytes"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const (
	baseDir    = "../internal/vet/testdata/base"
	schemaFile = "../../../schema.cue"
)

func run(args ...string) (code int, out, errOut string) {
	var o, e bytes.Buffer
	code = Run(args, &o, &e)
	return code, o.String(), e.String()
}

func TestVetCleanBase(t *testing.T) {
	code, out, errOut := run("vet", "--root", baseDir, "--schema", schemaFile, "--today", "2026-10-11")
	if code != ExitOK {
		t.Fatalf("exit %d\nstdout: %s\nstderr: %s", code, out, errOut)
	}
	if !strings.Contains(out, "enh vet: 0 errors, 0 warnings in 1 entries") {
		t.Errorf("stdout = %q", out)
	}
}

func TestVetFindsAnError(t *testing.T) {
	root := t.TempDir()
	err := filepath.WalkDir(baseDir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(baseDir, p)
		if d.IsDir() {
			return os.MkdirAll(filepath.Join(root, rel), 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(filepath.Join(root, rel), b, 0o644)
	})
	if err != nil {
		t.Fatal(err)
	}
	cfg := filepath.Join(root, "openspec/changes/0100-demo-entry/config.yaml")
	b, _ := os.ReadFile(cfg)
	if err := os.WriteFile(cfg, []byte(strings.Replace(string(b), "Demo Entry", strings.Repeat("T", 81), 1)), 0o644); err != nil {
		t.Fatal(err)
	}
	code, out, _ := run("vet", "--root", root, "--schema", schemaFile, "--today", "2026-10-11")
	if code != ExitError {
		t.Fatalf("exit %d, want %d\n%s", code, ExitError, out)
	}
	if !strings.Contains(out, "V2") || !strings.Contains(out, "81 characters") {
		t.Errorf("stdout = %q", out)
	}
	// Naming an entry that does not exist checks nothing and passes.
	code, out, _ = run("vet", "--root", root, "--schema", schemaFile, "--today", "2026-10-11", "9999")
	if code != ExitOK || !strings.Contains(out, "in 0 entries") {
		t.Errorf("exit %d stdout %q", code, out)
	}
}

func TestUsageErrors(t *testing.T) {
	for name, args := range map[string][]string{
		"no command":      {},
		"unknown command": {"nope"},
		"bad mode":        {"vet", "--mode", "nope"},
		"strict alone":    {"vet", "--strict"},
		"bad flag":        {"vet", "--nope"},
		"missing root":    {"vet", "--root", "/nonexistent-enh-root", "--schema", schemaFile},
	} {
		if code, _, _ := run(args...); code != ExitUsage {
			t.Errorf("%s: exit %d, want %d", name, code, ExitUsage)
		}
	}
	if code, out, _ := run("help"); code != ExitOK || !strings.Contains(out, "enh vet") {
		t.Errorf("help: exit %d out %q", code, out)
	}
}
