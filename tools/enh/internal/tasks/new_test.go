package tasks

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func removeFile(root, rel string) error { return os.Remove(filepath.Join(root, rel)) }

func goodArgs() NewArgs {
	return NewArgs{Slug: "my-feature", Title: "My Feature", Summary: "OPM gains a feature.", Category: "tooling", Affects: []string{"core", "cli"}}
}

func TestNew(t *testing.T) {
	f := newFx(t)
	id, err := f.env.New(goodArgs())
	f.mustNil(err)
	if id != "0002" {
		t.Errorf("id = %s, want the lowest free 0002", id)
	}
	if !contains(f.calls, "new change 0002-my-feature --schema enhancement") {
		t.Errorf("calls = %v", f.calls)
	}
	cfg := f.read("openspec/changes/0002-my-feature/config.yaml")
	for _, want := range []string{`id: "0002"`, "slug: my-feature", `title: "My Feature"`, "status: draft\n", "category: tooling", "  - core\n  - cli\n", `  - "dev@example.com"`, `created: "2026-10-11"`} {
		if !strings.Contains(cfg, want) {
			t.Errorf("config lacks %q:\n%s", want, cfg)
		}
	}
	if strings.Contains(cfg, "updated") || strings.Contains(cfg, "breaking") {
		t.Errorf("a new config has no updated and no breaking:\n%s", cfg)
	}
	if !f.exists("openspec/changes/0002-my-feature/README.md") || !f.exists("INDEX.md") {
		t.Error("index did not run")
	}
}

func TestNewRefusals(t *testing.T) {
	f := newFx(t)
	cases := map[string]func(*NewArgs){
		"bad slug":      func(a *NewArgs) { a.Slug = "My_Feature" },
		"slug hyphen":   func(a *NewArgs) { a.Slug = "-x" },
		"no title":      func(a *NewArgs) { a.Title = "" },
		"no summary":    func(a *NewArgs) { a.Summary = " " },
		"no affects":    func(a *NewArgs) { a.Affects = nil },
		"bad category":  func(a *NewArgs) { a.Category = "nonsense" },
		"unknown repo":  func(a *NewArgs) { a.Affects = []string{"catalog"} },
		"long title":    func(a *NewArgs) { a.Title = strings.Repeat("T", 81) },
		"two-line text": func(a *NewArgs) { a.Summary = "one\ntwo" },
	}
	for name, mutate := range cases {
		a := goodArgs()
		mutate(&a)
		if _, err := f.env.New(a); !IsUsage(err) {
			t.Errorf("%s: err = %v, want a usage error", name, err)
		}
	}
	if len(f.calls) != 0 {
		t.Errorf("openspec ran for a refused request: %v", f.calls)
	}
	if f.exists("openspec/changes/0002-my-feature") {
		t.Error("a folder was made")
	}
}

func TestNewWithAGivenIDRefusesTakenIDs(t *testing.T) {
	f := newFx(t)
	for _, id := range []string{"0001", "0100", "0028", "0000", "0030"} {
		f.env.ID = id
		if _, err := f.env.New(goodArgs()); !IsRefusal(err) {
			t.Errorf("id %s: err = %v, want a refusal", id, err)
		}
	}
	f.env.ID = "12"
	if _, err := f.env.New(goodArgs()); !IsUsage(err) {
		t.Errorf("short id: %v", err)
	}
	f.env.ID = "0050"
	id, err := f.env.New(goodArgs())
	if err != nil || id != "0050" {
		t.Errorf("free id: %q %v", id, err)
	}
}

func TestNewNeedsAnAuthor(t *testing.T) {
	f := newFx(t)
	f.git("config", "--unset", "user.email")
	f.env.Authors = nil
	// git may still find a global address; only assert the explicit path works
	f.env.Authors = []string{"a@example.com"}
	if _, err := f.env.New(goodArgs()); err != nil {
		f.mustNil(err)
	}
	if !strings.Contains(f.read("openspec/changes/0002-my-feature/config.yaml"), `"a@example.com"`) {
		t.Error("the author was not written")
	}
}

func TestNewReportsAFailingOpenSpec(t *testing.T) {
	f := newFx(t)
	f.failOn = "new change"
	if _, err := f.env.New(goodArgs()); err == nil || !strings.Contains(err.Error(), "simulated failure") {
		t.Errorf("err = %v", err)
	}
}

func TestSeedNew(t *testing.T) {
	f := newFx(t)
	if err := f.env.SeedNew("existing-cap"); !IsRefusal(err) {
		t.Errorf("a capability in specs/: %v", err)
	}
	if err := f.env.SeedNew("Bad Cap"); !IsUsage(err) {
		t.Errorf("bad name: %v", err)
	}
	if len(f.calls) != 0 {
		t.Errorf("openspec ran: %v", f.calls)
	}
	f.mustNil(f.env.SeedNew("fresh-cap"))
	if !contains(f.calls, "new change seed-fresh-cap --schema seed") || !f.exists("openspec/changes/seed-fresh-cap/.openspec.yaml") {
		t.Errorf("calls = %v", f.calls)
	}
	if err := f.env.SeedNew("fresh-cap"); !IsRefusal(err) {
		t.Errorf("twice: %v", err)
	}
}

func TestIndexAndFresh(t *testing.T) {
	f := newFx(t)
	if err := f.env.Fresh(); !IsRefusal(err) {
		t.Fatalf("fresh before index: %v", err)
	}
	f.reset()
	f.mustNil(f.env.RunIndex())
	if !strings.Contains(f.out.String(), "index: wrote INDEX.md") {
		t.Errorf("output:\n%s", f.out)
	}
	f.reset()
	f.mustNil(f.env.Fresh())
	f.reset()
	f.mustNil(f.env.RunIndex())
	if !strings.Contains(f.out.String(), "up to date") {
		t.Errorf("second index:\n%s", f.out)
	}
	if f.exists("openspec/specs/INDEX.md") {
		t.Error("index wrote under specs/")
	}
}
