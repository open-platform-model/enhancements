package tasks

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/open-platform-model/enhancements/tools/enh/internal/sys"
	"github.com/open-platform-model/enhancements/tools/enh/internal/testrepo"
)

const schemaRel = "../../../../schema.cue"

// fx is a temporary git repo with one draft entry, one main spec and a fake
// openspec CLI.
type fx struct {
	t        *testing.T
	root     string
	env      *Env
	out, err *bytes.Buffer
	// calls records the openspec calls as "args".
	calls []string
	// failOn makes an openspec call fail when its joined args start with it.
	failOn string
}

func newFx(t *testing.T) *fx {
	t.Helper()
	f := &fx{t: t, root: testrepo.New(t), out: &bytes.Buffer{}, err: &bytes.Buffer{}}
	copyTree(t, "../vet/testdata/base", f.root)
	schema, err := os.ReadFile(schemaRel)
	if err != nil {
		t.Fatal(err)
	}
	f.write("schema.cue", string(schema))
	f.write("archive/0001/config.yaml", "id: \"0001\"\nslug: old-entry\ntitle: Old Entry\nstatus: delivered\ncategory: tooling\ncreated: 2026-01-01\nupdated: 2026-02-01\n")
	f.write("openspec/specs/existing-cap/spec.md", mainSpec())
	f.env = &Env{
		Root: f.root, Run: f.run, Out: f.out, Err: f.err,
		Now: func() time.Time { return time.Date(2026, 10, 11, 9, 0, 0, 0, time.UTC) },
	}
	testrepo.Commit(t, f.root, "docs: base")
	return f
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

func mainSpec() string {
	return `## Purpose

Hold the shipped behaviour of the existing capability for the fixtures.

## Requirements

### Requirement: Render records the held versions

A render SHALL record the version of every catalog path it held.

#### Scenario: Recorded

- **WHEN** a module renders
- **THEN** the versions are recorded

### Requirement: An unadmitted catalog is refused

A render SHALL refuse a module that imports a catalog with no admission entry.

#### Scenario: Refused

- **WHEN** a module imports an unknown catalog
- **THEN** the render is refused

### Requirement: Readiness is reported

The controller SHALL report readiness of every platform.

#### Scenario: Reported

- **WHEN** a platform is ready
- **THEN** the status says so
`
}

func (f *fx) write(rel, text string) { testrepo.Write(f.t, f.root, rel, text) }

func (f *fx) read(rel string) string {
	f.t.Helper()
	b, err := os.ReadFile(filepath.Join(f.root, filepath.FromSlash(rel)))
	if err != nil {
		f.t.Fatal(err)
	}
	return string(b)
}

func (f *fx) exists(rel string) bool {
	_, err := os.Stat(filepath.Join(f.root, filepath.FromSlash(rel)))
	return err == nil
}

func (f *fx) git(args ...string) string { return testrepo.Git(f.t, f.root, args...) }

func (f *fx) commit(msg string) string { return testrepo.Commit(f.t, f.root, msg) }

// reset clears the captured output.
func (f *fx) reset() { f.out.Reset(); f.err.Reset(); f.calls = nil }

// run is the Runner: real git, fake openspec.
func (f *fx) run(dir, name string, args ...string) ([]byte, error) {
	if name == "git" {
		return sys.Exec(dir, name, args...)
	}
	joined := strings.Join(args, " ")
	f.calls = append(f.calls, joined)
	if f.failOn != "" && strings.HasPrefix(joined, f.failOn) {
		return []byte("simulated failure"), fmt.Errorf("exit status 1")
	}
	switch {
	case len(args) >= 3 && args[0] == "new" && args[1] == "change":
		d := filepath.Join(f.root, "openspec", "changes", args[2])
		if err := os.MkdirAll(d, 0o755); err != nil {
			return nil, err
		}
		return nil, os.WriteFile(filepath.Join(d, ".openspec.yaml"), []byte("schema: "+args[4]+"\ncreated: 2026-10-11\n"), 0o644)
	case len(args) >= 2 && args[0] == "archive":
		from := filepath.Join(f.root, "openspec", "changes", args[1])
		to := filepath.Join(f.root, "openspec", "changes", "archive", "2026-10-11-"+args[1])
		if err := os.MkdirAll(filepath.Dir(to), 0o755); err != nil {
			return nil, err
		}
		return nil, os.Rename(from, to)
	}
	return nil, nil
}

// requirements writes n ADDED requirements with distinct words to the delta of the demo entry.
func (f *fx) addedDelta(n int, extra string) {
	var b strings.Builder
	b.WriteString("## Purpose\n\nShow the checker at work on one small capability so that every rule has a fixture.\n\n## ADDED Requirements\n\n")
	for i := 1; i <= n; i++ {
		fmt.Fprintf(&b, "### Requirement: Thing number %d is held\n\nThe system SHALL hold thing%d and report the held versions of the catalog.\n\n#### Scenario: Held %d\n\n- **WHEN** a user asks %d\n- **THEN** thing%d is held\n\n", i, i, i, i, i)
	}
	f.write("openspec/changes/0100-demo-entry/specs/demo-cap/spec.md", b.String())
	if extra != "" {
		f.write("openspec/changes/0100-demo-entry/specs/existing-cap/spec.md", extra)
	}
}

const modifiedAndRemoved = `## MODIFIED Requirements

### Requirement: Render records the held versions

A render SHALL record the version of every catalog path it held and expose it on the instance.

#### Scenario: Recorded

- **WHEN** a module renders
- **THEN** the versions are recorded and exposed

## REMOVED Requirements

### Requirement: Readiness is reported

**Reason**: Readiness moves to the conditions.

**Migration**: Read the conditions of the platform.
`

func (f *fx) mustNil(err error) {
	f.t.Helper()
	if err != nil {
		f.t.Fatalf("error: %v\nstdout:\n%s\nstderr:\n%s", err, f.out, f.err)
	}
}
