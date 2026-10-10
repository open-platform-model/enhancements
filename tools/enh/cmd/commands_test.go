package cmd

import (
	"bytes"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/open-platform-model/enhancements/tools/enh/internal/sys"
	"github.com/open-platform-model/enhancements/tools/enh/internal/testrepo"
)

// repo is a temporary git repo with the demo entry, one main spec and a fake
// openspec CLI.
type repo struct {
	t     *testing.T
	root  string
	calls []string
	env   map[string]string
	stdin string
}

func newRepo(t *testing.T) *repo {
	t.Helper()
	r := &repo{t: t, root: testrepo.New(t), env: map[string]string{}}
	copyTree(t, baseDir, r.root)
	schema, err := os.ReadFile(schemaFile)
	if err != nil {
		t.Fatal(err)
	}
	testrepo.Write(t, r.root, "schema.cue", string(schema))
	testrepo.Write(t, r.root, "archive/0001/config.yaml", "id: \"0001\"\nslug: old\ntitle: Old\nstatus: delivered\ncategory: tooling\ncreated: 2026-01-01\nupdated: 2026-02-01\n")
	testrepo.Commit(t, r.root, "docs: base")
	return r
}

func copyTree(t *testing.T, from, to string) {
	t.Helper()
	err := filepath.WalkDir(from, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(from, p)
		if d.IsDir() {
			return os.MkdirAll(filepath.Join(to, rel), 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(filepath.Join(to, rel), b, 0o644)
	})
	if err != nil {
		t.Fatal(err)
	}
}

func (r *repo) runner(dir, name string, args ...string) ([]byte, error) {
	if name == "git" {
		return sys.Exec(dir, name, args...)
	}
	r.calls = append(r.calls, strings.Join(args, " "))
	switch {
	case len(args) >= 5 && args[0] == "new":
		d := filepath.Join(r.root, "openspec", "changes", args[2])
		if err := os.MkdirAll(d, 0o755); err != nil {
			return nil, err
		}
		return nil, os.WriteFile(filepath.Join(d, ".openspec.yaml"), []byte("schema: "+args[4]+"\ncreated: 2026-10-11\n"), 0o644)
	case len(args) >= 2 && args[0] == "archive":
		to := filepath.Join(r.root, "openspec", "changes", "archive", "2026-10-11-"+args[1])
		if err := os.MkdirAll(filepath.Dir(to), 0o755); err != nil {
			return nil, err
		}
		return nil, os.Rename(filepath.Join(r.root, "openspec", "changes", args[1]), to)
	}
	return nil, nil
}

// do runs enh with --root appended where the command takes one.
func (r *repo) do(args ...string) (code int, out, errOut string) {
	var o, e bytes.Buffer
	d := Deps{
		Runner: r.runner,
		Now:    func() time.Time { return time.Date(2026, 10, 11, 9, 0, 0, 0, time.UTC) },
		Getenv: func(k string) string { return r.env[k] },
		Stdin:  strings.NewReader(r.stdin),
		Cwd:    func() (string, error) { return r.root, nil },
	}
	code = RunWith(d, args, &o, &e)
	return code, o.String(), e.String()
}

func (r *repo) file(rel string) string {
	b, err := os.ReadFile(filepath.Join(r.root, filepath.FromSlash(rel)))
	if err != nil {
		r.t.Fatal(err)
	}
	return string(b)
}

func (r *repo) put(rel, text string) { testrepo.Write(r.t, r.root, rel, text) }

func wantCode(t *testing.T, what string, got, want int, out, errOut string) {
	t.Helper()
	if got != want {
		t.Fatalf("%s: exit %d, want %d\nstdout:\n%s\nstderr:\n%s", what, got, want, out, errOut)
	}
}

func TestEveryCommandHasHelp(t *testing.T) {
	for _, c := range commands {
		code, out, errOut := run(c.name, "--help")
		if code != ExitOK || !strings.HasPrefix(out, "Usage: enh "+c.name) || errOut != "" {
			t.Errorf("%s --help: exit %d out %q err %q", c.name, code, out, errOut)
		}
		if code, out, _ := run("help", c.name); code != ExitOK || !strings.HasPrefix(out, "Usage: enh "+c.name) {
			t.Errorf("help %s: exit %d out %q", c.name, code, out)
		}
	}
	for _, name := range []string{"vet", "new", "seed:new", "accept", "resample", "deliver", "reject", "withdraw", "supersede", "tick",
		"index", "fresh", "history", "stale", "links", "reconcile", "cite-lint", "specs-rule", "list", "show", "questions"} {
		if lookup(name) == nil {
			t.Errorf("command %s is not wired", name)
		}
	}
}

func TestArgumentErrorsAreUsageErrors(t *testing.T) {
	r := newRepo(t)
	for name, args := range map[string][]string{
		"accept without id":      {"accept"},
		"accept with two":        {"accept", "0100", "0101"},
		"new with four":          {"new", "a", "b", "c", "d"},
		"reject without reason":  {"reject", "0100"},
		"unknown flag":           {"show", "--nope", "0100"},
		"bad seed":               {"accept", "0100", "--seed", "abc"},
		"flag needs a value":     {"accept", "0100", "--seed"},
		"unknown entry":          {"show", "9999"},
		"history without name":   {"history"},
		"help of unknown":        {"help", "nope"},
		"tick short":             {"tick", "0100", "1.1"},
		"list takes no argument": {"list", "extra"},
	} {
		code, out, errOut := r.do(args...)
		wantCode(t, name, code, ExitUsage, out, errOut)
		if errOut == "" {
			t.Errorf("%s: nothing on stderr", name)
		}
	}
}

func TestFlagsComeBeforeOrAfterArguments(t *testing.T) {
	r := newRepo(t)
	for _, args := range [][]string{{"show", "--root", r.root, "0100"}, {"show", "0100", "--root", r.root}, {"show", "0100", "--root=" + r.root}} {
		code, out, errOut := r.do(args...)
		wantCode(t, strings.Join(args, " "), code, ExitOK, out, errOut)
		if !strings.Contains(out, "id:       0100") {
			t.Errorf("%v: %s", args, out)
		}
	}
	// after "--" a leading hyphen is an argument
	code, out, errOut := r.do("show", "--", "-weird")
	wantCode(t, "-- handling", code, ExitUsage, out, errOut)
	if !strings.Contains(errOut, `no entry "-weird"`) {
		t.Errorf("the argument after -- was not taken as a name: %q", errOut)
	}
}

func TestLifecycleThroughTheCommands(t *testing.T) {
	r := newRepo(t)

	code, out, errOut := r.do("new", "my-feature", "My Feature", "OPM gains a feature.", "tooling", "core,cli")
	wantCode(t, "new", code, ExitOK, out, errOut)
	if !strings.Contains(out, "created openspec/changes/0002-my-feature/") {
		t.Errorf("new:\n%s", out)
	}
	code, out, errOut = r.do("new", "Bad Slug", "T", "S", "tooling", "core")
	wantCode(t, "new bad", code, ExitUsage, out, errOut)
	code, out, errOut = r.do("new", "x", "T", "S", "tooling", "core", "--id", "0001")
	wantCode(t, "new used id", code, ExitError, out, errOut)
}

func TestAcceptDeliverExitCodes(t *testing.T) {
	r := newRepo(t)
	code, out, errOut := r.do("accept", "0100", "--seed", "4")
	wantCode(t, "accept", code, ExitOK, out, errOut)
	if !strings.Contains(out, "Random seed: 4") || !strings.Contains(out, "Collision review.") {
		t.Errorf("accept:\n%s", out)
	}
	code, out, errOut = r.do("accept", "0100", "--confirm")
	wantCode(t, "confirm", code, ExitOK, out, errOut)
	if !strings.Contains(r.file("openspec/changes/0100-demo-entry/config.yaml"), "status: accepted") {
		t.Error("status not written")
	}
	// CONFIRM=1 in the environment is the same as --confirm, and the second confirm is refused by the state
	r.env["CONFIRM"] = "1"
	code, out, errOut = r.do("accept", "0100")
	wantCode(t, "accept of an accepted entry", code, ExitError, out, errOut)
	delete(r.env, "CONFIRM")

	testrepo.Commit(t, r.root, "docs: accept")
	code, out, errOut = r.do("deliver", "0100")
	wantCode(t, "deliver with unticked lines", code, ExitError, out, errOut)
	if !strings.Contains(out, "V24") || !strings.Contains(errOut, "deliver refused") {
		t.Errorf("deliver:\n%s\n%s", out, errOut)
	}
	for _, line := range []string{"1.1", "1.2"} {
		code, out, errOut = r.do("tick", "0100", line, "done-"+strings.ReplaceAll(line, ".", "-"))
		wantCode(t, "tick "+line, code, ExitOK, out, errOut)
	}
	code, out, errOut = r.do("tick", "0100", "1.1", "again")
	wantCode(t, "tick twice", code, ExitError, out, errOut)
	testrepo.Commit(t, r.root, "docs: ticks")

	code, out, errOut = r.do("deliver", "0100")
	wantCode(t, "deliver", code, ExitOK, out, errOut)
	if !strings.Contains(out, "committed: docs: deliver enhancement 0100 demo-entry") {
		t.Errorf("deliver:\n%s", out)
	}

	code, out, errOut = r.do("fresh")
	wantCode(t, "fresh", code, ExitOK, out, errOut)
	code, out, errOut = r.do("list", "--archived")
	wantCode(t, "list archived", code, ExitOK, out, errOut)
	if !strings.Contains(out, "Demo Entry") {
		t.Errorf("list --archived:\n%s", out)
	}
	code, out, errOut = r.do("history", "The checker accepts a clean entry")
	wantCode(t, "history", code, ExitOK, out, errOut)
	if !strings.Contains(out, "demo-cap / The checker accepts a clean entry") {
		t.Errorf("history:\n%s", out)
	}
	code, out, errOut = r.do("history", "No such requirement")
	wantCode(t, "history unknown", code, ExitUsage, out, errOut)
}

func TestVetAtDeliverModeRunsV26(t *testing.T) {
	r := newRepo(t)
	r.put("openspec/specs/other-cap/spec.md", r.file("openspec/specs/other-cap/spec.md"))
	r.put("openspec/changes/0100-demo-entry/specs/other-cap/spec.md", "## MODIFIED Requirements\n\n### Requirement: Existing thing\n\nThe system SHALL keep the existing thing, and more.\n\n#### Scenario: Kept\n\n- **WHEN** a user asks\n- **THEN** the thing is kept\n")
	testrepo.Commit(t, r.root, "docs: entry")
	code, out, errOut := r.do("accept", "0100")
	wantCode(t, "accept", code, ExitOK, out, errOut)
	code, out, errOut = r.do("accept", "0100", "--confirm")
	wantCode(t, "confirm", code, ExitOK, out, errOut)
	testrepo.Commit(t, r.root, "docs: accept")

	_, out, _ = r.do("vet", "--mode", "deliver", "0100")
	if strings.Contains(out, "V26") {
		t.Fatalf("V26 before any change:\n%s", out)
	}
	s := r.file("openspec/specs/other-cap/spec.md")
	r.put("openspec/specs/other-cap/spec.md", strings.Replace(s, "keep the existing thing", "keep the existing thing safe", 1))
	testrepo.Commit(t, r.root, "docs: another delivery")
	code, out, errOut = r.do("vet", "--mode", "deliver", "0100")
	wantCode(t, "vet deliver with a stale base", code, ExitError, out, errOut)
	if !strings.Contains(out, "V26") || !strings.Contains(out, "stale base: other-cap / Existing thing (MODIFIED)") {
		t.Errorf("vet:\n%s", out)
	}
	// draft mode does not run V26
	_, out, _ = r.do("vet", "0100")
	if strings.Contains(out, "V26") {
		t.Errorf("V26 in draft mode:\n%s", out)
	}
}

func TestResampleAndStaleCommands(t *testing.T) {
	r := newRepo(t)
	code, out, errOut := r.do("stale", "0100")
	wantCode(t, "stale of a draft", code, ExitError, out, errOut)
	code, out, errOut = r.do("resample", "0100")
	wantCode(t, "resample of a draft", code, ExitError, out, errOut)
}

func TestReadOnlyCommands(t *testing.T) {
	r := newRepo(t)
	for _, args := range [][]string{{"list"}, {"show", "0100"}, {"questions", "0100"}, {"index"}, {"links"}} {
		code, out, errOut := r.do(args...)
		wantCode(t, strings.Join(args, " "), code, ExitOK, out, errOut)
	}
	code, out, errOut := r.do("fresh")
	wantCode(t, "fresh after index", code, ExitOK, out, errOut)
}

func TestCiteLint(t *testing.T) {
	r := newRepo(t)
	r.put("pkg/a.go", "package a\n\n// This holds the retry limit (enhancement 0010).\nvar x = 1\n")
	code, out, errOut := r.do("cite-lint", "--root", r.root)
	wantCode(t, "clean", code, ExitOK, out, errOut)
	r.put("pkg/b.go", "package a\n\n// The limit comes from 0010:D3.\nvar y = 1\n")
	code, out, errOut = r.do("cite-lint", "--root", r.root)
	wantCode(t, "decision number", code, ExitError, out, errOut)
	if !strings.Contains(out, "pkg/b.go:3") {
		t.Errorf("cite-lint:\n%s", out)
	}
	// a path list from standard input narrows the run
	r.stdin = "pkg/a.go\n"
	code, out, errOut = r.do("cite-lint", "--root", r.root, "--files-from", "-")
	wantCode(t, "files-from", code, ExitOK, out, errOut)
	code, out, errOut = r.do("cite-lint", "--root", r.root, "--exclude", "b.go")
	wantCode(t, "exclude", code, ExitOK, out, errOut)
	code, _, _ = r.do("cite-lint", "--root", r.root, "no-such-file.go")
	if code != ExitUsage {
		t.Errorf("missing file: exit %d", code)
	}
}

func TestReconcile(t *testing.T) {
	r := newRepo(t)
	code, out, errOut := r.do("reconcile", "--workspace", t.TempDir())
	wantCode(t, "reconcile", code, ExitOK, out, errOut)
	if !strings.Contains(out, "reconcile:") {
		t.Errorf("reconcile:\n%s", out)
	}
}

func TestFindRootErrors(t *testing.T) {
	d := Deps{Cwd: func() (string, error) { return t.TempDir(), nil }}
	var o, e bytes.Buffer
	if code := RunWith(d, []string{"index"}, &o, &e); code != ExitUsage || !strings.Contains(e.String(), "use --root") {
		t.Errorf("exit %d err %q", code, e.String())
	}
}

// vet takes the base of V7, V27 and V31 from --base, else from origin/main,
// else from main, and prints a skipped line when none of them exists.
func TestVetBase(t *testing.T) {
	skipped := "V7 ancestry, V27, V31: no base ref"
	closed := func(r *repo) {
		// edit an old closed folder on a branch: V31 needs a base to see it
		r.put("archive/0001/README.md", "# old\n")
		testrepo.Commit(t, r.root, "docs: add closed readme")
		testrepo.Git(t, r.root, "checkout", "-q", "-b", "work")
		r.put("archive/0001/config.yaml", "id: \"0001\"\nslug: old\ntitle: Old edited\nstatus: delivered\ncategory: tooling\ncreated: 2026-01-01\nupdated: 2026-02-01\n")
		testrepo.Commit(t, r.root, "docs: edit a closed entry")
	}

	r := newRepo(t)
	closed(r)
	code, out, errOut := r.do("vet")
	if code != ExitError || !strings.Contains(out, "V31") || strings.Contains(out, skipped) {
		t.Errorf("default base main: exit %d\n%s\n%s", code, out, errOut)
	}

	// an explicit base wins: HEAD itself as the base shows no edit
	code, out, errOut = r.do("vet", "--base", "HEAD")
	if code != ExitOK || strings.Contains(out, "V31") || strings.Contains(out, skipped) {
		t.Errorf("--base HEAD: exit %d\n%s\n%s", code, out, errOut)
	}

	// origin/main is preferred when it exists; here it points at the work commit
	testrepo.Git(t, r.root, "update-ref", "refs/remotes/origin/main", "HEAD")
	code, out, errOut = r.do("vet")
	if code != ExitOK || strings.Contains(out, "V31") {
		t.Errorf("origin/main preferred: exit %d\n%s\n%s", code, out, errOut)
	}

	// no main and no origin/main: the rules are skipped and the line says so
	r2 := newRepo(t)
	testrepo.Git(t, r2.root, "branch", "-m", "trunk")
	code, out, errOut = r2.do("vet")
	if code != ExitOK || !strings.Contains(out, skipped) {
		t.Errorf("no base: exit %d\n%s\n%s", code, out, errOut)
	}

	// a bad ref is an error, not a skip
	code, _, errOut = r.do("vet", "--base", "no-such-branch")
	if code != ExitUsage || !strings.Contains(errOut, "merge base") {
		t.Errorf("bad base: exit %d\n%s", code, errOut)
	}
}

func TestSpecsRuleCommand(t *testing.T) {
	r := newRepo(t)
	base := strings.TrimSpace(testrepo.Git(t, r.root, "rev-parse", "HEAD"))
	testrepo.Git(t, r.root, "checkout", "-q", "-b", "work")

	// nothing under specs/ changed: pass
	r.put("notes.txt", "x")
	testrepo.Commit(t, r.root, "docs: notes")
	code, out, errOut := r.do("specs-rule", "--base", base)
	wantCode(t, "no change", code, ExitOK, out, errOut)
	if !strings.Contains(out, "enh specs-rule: pass") {
		t.Errorf("out: %s", out)
	}

	// a spec file written by hand: fail, exit 1
	r.put("openspec/specs/sneaky/spec.md", "# sneaky\n\n## Purpose\nA hand written capability with a purpose that is long enough.\n")
	testrepo.Commit(t, r.root, "docs: a spec by hand")
	code, out, errOut = r.do("specs-rule", "--base", base)
	wantCode(t, "hand edit", code, ExitError, out, errOut)
	if !strings.Contains(out, "FAIL step 2") || !strings.Contains(out, "1 failure(s)") {
		t.Errorf("out: %s", out)
	}

	// usage errors: exit 2
	for name, args := range map[string][]string{
		"no base":          {"specs-rule"},
		"chain with base":  {"specs-rule", "--chain", "--base", base},
		"chain no since":   {"specs-rule", "--chain"},
		"since not chain":  {"specs-rule", "--since", base, "--base", base},
		"base with a dash": {"specs-rule", "--base=-x"},
	} {
		code, out, errOut := r.do(args...)
		if code != ExitUsage {
			t.Errorf("%s: exit %d\n%s\n%s", name, code, out, errOut)
		}
	}

	// chain mode: the hand-written commit is not an archive
	code, out, errOut = r.do("specs-rule", "--chain", "--since", base)
	wantCode(t, "chain", code, ExitError, out, errOut)
	if !strings.Contains(out, "1 commit(s) after") {
		t.Errorf("out: %s", out)
	}
}
