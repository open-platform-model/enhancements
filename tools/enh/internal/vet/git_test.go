package vet

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// The tests of V7 (ancestry), V27 and V31 run the real git on a temporary
// repository: main holds the base state, and the working tree is the head.

const (
	acceptedCfg = `id: "0100"
slug: demo-entry
title: Demo Entry
summary: One line that says what OPM gains.
status: accepted
category: tooling
breaking: false
affects:
  - enhancements
  - cli
authors:
  - dev@example.com
created: 2026-10-10
accepted: "2026-10-10 %s"
`
	archivedCfg = `id: "0102"
slug: gone-entry
title: Demo Entry
summary: One line that says what OPM gains.
status: superseded
category: tooling
breaking: false
affects:
  - enhancements
  - cli
authors:
  - dev@example.com
created: 2026-10-10
superseded_by:
  date: 2026-10-10
  ids:
    - "0100"
  reason: Replaced by the demo entry.
`
	entryDir   = "openspec/changes/0100-demo-entry"
	specFile   = entryDir + "/specs/demo-cap/spec.md"
	configFile = entryDir + "/config.yaml"
	seedDir    = "openspec/changes/seed-demo-seed"
	closedDir  = "openspec/changes/archive/2026-10-09-0102-gone-entry"
	oldDir     = "archive/0001"
)

type gitRepo struct {
	t   *testing.T
	dir string
}

func (g *gitRepo) git(args ...string) string {
	g.t.Helper()
	cmd := exec.Command("git", append([]string{"-C", g.dir}, args...)...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		g.t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
	}
	return strings.TrimSpace(string(out))
}

func (g *gitRepo) write(rel, body string) {
	g.t.Helper()
	p := filepath.Join(g.dir, filepath.FromSlash(rel))
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		g.t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		g.t.Fatal(err)
	}
}

func (g *gitRepo) read(rel string) string {
	g.t.Helper()
	b, err := os.ReadFile(filepath.Join(g.dir, filepath.FromSlash(rel)))
	if err != nil {
		g.t.Fatal(err)
	}
	return string(b)
}

// replace edits a file of the working tree; the old text must be there.
func (g *gitRepo) replace(rel, old, new string) {
	g.t.Helper()
	s := g.read(rel)
	if !strings.Contains(s, old) {
		g.t.Fatalf("%s has no %q", rel, old)
	}
	g.write(rel, strings.Replace(s, old, new, 1))
}

func (g *gitRepo) remove(rel string) {
	g.t.Helper()
	if err := os.RemoveAll(filepath.Join(g.dir, filepath.FromSlash(rel))); err != nil {
		g.t.Fatal(err)
	}
}

func (g *gitRepo) commit(msg string) string {
	g.t.Helper()
	g.git("add", "-A")
	g.git("commit", "-q", "-m", msg)
	return g.git("rev-parse", "HEAD")
}

// newGitRepo builds the base state on main. Commit one holds the draft tree;
// commit two accepts entry 0100 at commit one and adds a sampled seed, a
// closed folder of each layout, and returns the repo and the two shas.
func newGitRepo(t *testing.T) (*gitRepo, string, string) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git is not installed")
	}
	t.Setenv("GIT_CONFIG_GLOBAL", os.DevNull)
	t.Setenv("GIT_CONFIG_SYSTEM", os.DevNull)
	t.Setenv("GIT_AUTHOR_NAME", "Test")
	t.Setenv("GIT_AUTHOR_EMAIL", "test@example.com")
	t.Setenv("GIT_COMMITTER_NAME", "Test")
	t.Setenv("GIT_COMMITTER_EMAIL", "test@example.com")
	g := &gitRepo{t: t, dir: t.TempDir()}
	g.git("init", "-q", "-b", "main")
	copyTree(t, "testdata/base", g.dir)
	one := g.commit("one: a draft entry")

	g.write(configFile, strings.Replace(acceptedCfg, "%s", one[:12], 1))
	copyTree(t, "testdata/V33/valid/openspec", filepath.Join(g.dir, "openspec"))
	g.write(closedDir+"/config.yaml", archivedCfg)
	g.write(closedDir+"/proposal.md", "# 0102: closed\n\nThe text of the closed entry.\n")
	g.write(closedDir+"/README.md", "# 0102\n\ngenerated\n")
	g.write(oldDir+"/02-design.md", "# design\n\nSee [0014](../../0014/) for the rest.\nA second line.\n")
	two := g.commit("two: accept the entry")
	return g, one, two
}

func (g *gitRepo) vet(opts func(*Options)) *Result {
	g.t.Helper()
	o := Options{Root: g.dir, Today: "2026-10-11", SchemaPath: schemaPath, Base: "main"}
	if opts != nil {
		opts(&o)
	}
	res, err := Run(o)
	if err != nil {
		g.t.Fatal(err)
	}
	return res
}

// has reports a finding of the rule at the level whose message holds text.
func has(res *Result, rule, text string) bool {
	for _, f := range res.Findings {
		if f.Rule == rule && f.Level == Error && strings.Contains(f.Msg, text) {
			return true
		}
	}
	return false
}

func dump(res *Result) string {
	var b strings.Builder
	res.Format(&b)
	return b.String()
}

func count(res *Result, rule string) int {
	n := 0
	for _, f := range res.Findings {
		if f.Rule == rule {
			n++
		}
	}
	return n
}

func TestGitRulesCleanBase(t *testing.T) {
	g, _, _ := newGitRepo(t)
	res := g.vet(nil)
	if len(res.Findings) != 0 {
		t.Fatalf("the base state has findings:\n%s", dump(res))
	}
	for _, sk := range res.Skipped {
		if strings.Contains(sk, "V27") {
			t.Errorf("the git rules are skipped with a base given: %s", sk)
		}
	}
}

func TestGitRulesSkippedWithoutBase(t *testing.T) {
	g, _, _ := newGitRepo(t)
	g.write(closedDir+"/proposal.md", "changed\n")
	res := g.vet(func(o *Options) { o.Base = "" })
	if count(res, "V31")+count(res, "V27")+count(res, "V7") != 0 {
		t.Errorf("git rules ran with no base:\n%s", dump(res))
	}
	named := false
	for _, sk := range res.Skipped {
		named = named || strings.Contains(sk, "V7 ancestry, V27, V31")
	}
	if !named {
		t.Errorf("skipped = %v, want the git rules named", res.Skipped)
	}
}

func TestBaseRefIsRefused(t *testing.T) {
	g, _, _ := newGitRepo(t)
	if _, err := Run(Options{Root: g.dir, SchemaPath: schemaPath, Base: "--output=x"}); err == nil {
		t.Error("a base ref that starts with a dash should be refused")
	}
}

func TestV7Ancestry(t *testing.T) {
	g, one, two := newGitRepo(t)
	g.git("checkout", "-q", "-b", "side", one)
	g.write("side.txt", "x\n")
	side := g.commit("side: a commit that is not on main")
	g.git("checkout", "-q", "main")

	set := func(sha string) {
		g.write(configFile, strings.Replace(acceptedCfg, "%s", sha, 1))
	}
	t.Run("an ancestor", func(t *testing.T) {
		set(two[:12])
		if res := g.vet(nil); has(res, "V7", "") {
			t.Errorf("an ancestor of main drew V7:\n%s", dump(res))
		}
	})
	t.Run("not an ancestor", func(t *testing.T) {
		set(side[:12])
		if res := g.vet(nil); !has(res, "V7", "is not an ancestor of main") {
			t.Errorf("want V7 not an ancestor:\n%s", dump(res))
		}
	})
	t.Run("unknown commit", func(t *testing.T) {
		set("deadbeef1234")
		if res := g.vet(nil); !has(res, "V7", "cannot be checked against main") {
			t.Errorf("want V7 unknown commit:\n%s", dump(res))
		}
	})
	t.Run("hook", func(t *testing.T) {
		set(one[:12])
		res := g.vet(func(o *Options) {
			o.GitAncestor = func(root, commit, ref string) (bool, error) { return false, nil }
		})
		if !has(res, "V7", "is not an ancestor of main") {
			t.Errorf("the GitAncestor hook is not used:\n%s", dump(res))
		}
	})
}

func TestV27EditAfterAccept(t *testing.T) {
	const ruleText = "The checker SHALL accept an entry that follows the format."
	t.Run("changed text, accepted unchanged", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(specFile, ruleText, "The checker SHALL accept every entry.")
		res := g.vet(nil)
		if !has(res, "V27", "differs from main while accepted is unchanged") {
			t.Errorf("want V27:\n%s", dump(res))
		}
		if !has(res, "V27", "run task resample") {
			t.Errorf("the message should name task resample:\n%s", dump(res))
		}
		for _, f := range res.Findings {
			if f.Rule == "V27" && (f.Line == 0 || !strings.HasSuffix(f.Path, "demo-cap/spec.md")) {
				t.Errorf("V27 should name the spec file and line: %s", f)
			}
		}
	})
	t.Run("changed scenario", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(specFile, "it reports no error", "it reports a warning")
		if res := g.vet(nil); !has(res, "V27", "differs from main") {
			t.Errorf("a scenario edit is an edit:\n%s", dump(res))
		}
	})
	t.Run("changed text, accepted rewritten", func(t *testing.T) {
		g, _, two := newGitRepo(t)
		g.replace(specFile, ruleText, "The checker SHALL accept every entry.")
		g.write(configFile, strings.Replace(acceptedCfg, `2026-10-10 %s`, `2026-10-11 `+two[:12], 1))
		if res := g.vet(nil); count(res, "V27") != 0 {
			t.Errorf("a re-sample rewrites accepted, so V27 is silent:\n%s", dump(res))
		}
	})
	t.Run("new requirement", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.write(specFile, g.read(specFile)+"\n### Requirement: The checker names a line\n\nThe checker SHALL name the line.\n\n#### Scenario: A line\n\n- **WHEN** a rule fails\n- **THEN** the line is named\n")
		if res := g.vet(nil); !has(res, "V27", "is new since main") {
			t.Errorf("a requirement added after accept needs a re-sample:\n%s", dump(res))
		}
	})
	t.Run("whitespace only", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(specFile, "The checker SHALL accept an entry", "The checker  SHALL accept an\nentry")
		if res := g.vet(nil); count(res, "V27") != 0 {
			t.Errorf("whitespace is not an edit:\n%s", dump(res))
		}
	})
	t.Run("a draft at the base is the accept itself", func(t *testing.T) {
		g, one, _ := newGitRepo(t)
		g.replace(specFile, ruleText, "The checker SHALL accept every entry.")
		res := g.vet(func(o *Options) { o.Base = one })
		if count(res, "V27") != 0 {
			t.Errorf("the entry was a draft at the base:\n%s", dump(res))
		}
	})
	t.Run("a new entry", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.git("mv", entryDir, "openspec/changes/0103-other-entry")
		g.replace("openspec/changes/0103-other-entry/config.yaml", `id: "0100"`, `id: "0103"`)
		g.replace("openspec/changes/0103-other-entry/config.yaml", "slug: demo-entry", "slug: other-entry")
		if res := g.vet(nil); count(res, "V27") != 0 {
			t.Errorf("an entry that is not at the base is new:\n%s", dump(res))
		}
	})
	t.Run("the hook reads the base", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(specFile, ruleText, "The checker SHALL accept every entry.")
		var asked []string
		res := g.vet(func(o *Options) {
			o.GitShow = func(root, ref, p string) ([]byte, error) {
				asked = append(asked, ref+":"+p)
				return gitShow(root, ref, p)
			}
		})
		if !has(res, "V27", "differs") || len(asked) == 0 || !strings.HasPrefix(asked[0], "main:") {
			t.Errorf("GitShow was not asked for the base: %v", asked)
		}
	})
}

func TestV27EditAfterSample(t *testing.T) {
	seedSpec := seedDir + "/specs/demo-seed/spec.md"
	src := seedDir + "/source.md"
	t.Run("changed text, sampled unchanged", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(seedSpec, "The system SHALL hold the shipped thing.", "The system SHALL hold the other thing.")
		if res := g.vet(nil); !has(res, "V27", "while sampled is unchanged") {
			t.Errorf("want V27 for a seed:\n%s", dump(res))
		}
	})
	t.Run("changed text, sampled again", func(t *testing.T) {
		g, _, two := newGitRepo(t)
		g.replace(seedSpec, "The system SHALL hold the shipped thing.", "The system SHALL hold the other thing.")
		g.replace(src, "sampled: 2026-10-10 abcdef1", "sampled: 2026-10-11 "+two[:12])
		if res := g.vet(nil); count(res, "V27") != 0 {
			t.Errorf("a new sampled line is the re-sample:\n%s", dump(res))
		}
	})
	t.Run("not sampled at the base", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(src, "sampled: 2026-10-10 abcdef1\n", "")
		g.commit("three: the seed loses its sampled line")
		g.replace(seedSpec, "The system SHALL hold the shipped thing.", "The system SHALL hold the other thing.")
		if res := g.vet(nil); count(res, "V27") != 0 {
			t.Errorf("an edit before sampling is free:\n%s", dump(res))
		}
	})
}

func TestV31ClosedFolders(t *testing.T) {
	t.Run("README is regenerated", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.write(closedDir+"/README.md", "# 0102\n\nregenerated\n")
		if res := g.vet(nil); count(res, "V31") != 0 {
			t.Errorf("README regeneration is allowed:\n%s", dump(res))
		}
	})
	t.Run("README is added where the base had none", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.remove(closedDir + "/README.md")
		g.commit("three: no README yet")
		g.write(closedDir+"/README.md", "# 0102\n\ngenerated later\n")
		if res := g.vet(nil); count(res, "V31") != 0 {
			t.Errorf("a generated README may appear:\n%s", dump(res))
		}
	})
	t.Run("a file is changed", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(closedDir+"/proposal.md", "The text", "Other text")
		if res := g.vet(nil); !has(res, "V31", closedDir+"/proposal.md was changed since main") {
			t.Errorf("want V31 changed:\n%s", dump(res))
		}
	})
	t.Run("a file is deleted", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.remove(closedDir + "/proposal.md")
		if res := g.vet(nil); !has(res, "V31", "proposal.md was deleted") {
			t.Errorf("want V31 deleted:\n%s", dump(res))
		}
	})
	t.Run("a file is added", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.write(closedDir+"/evidence/new.md", "late\n")
		if res := g.vet(nil); !has(res, "V31", "evidence/new.md was added") {
			t.Errorf("want V31 added:\n%s", dump(res))
		}
	})
	t.Run("a whole folder is deleted", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.remove(closedDir)
		res := g.vet(nil)
		if !has(res, "V31", "was deleted") {
			t.Errorf("want V31 deleted:\n%s", dump(res))
		}
	})
	t.Run("a many-file folder is capped", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		for i := 0; i < 8; i++ {
			g.write(closedDir+"/ev/"+string(rune('a'+i))+".md", "x\n")
		}
		g.commit("three: more files")
		g.remove(closedDir)
		res := g.vet(nil)
		if n := count(res, "V31"); n != maxPerFolder+1 {
			t.Errorf("V31 findings = %d, want %d (the cap and one summary):\n%s", n, maxPerFolder+1, dump(res))
		}
		if !has(res, "V31", "more changes in") {
			t.Errorf("want a summary line:\n%s", dump(res))
		}
	})
	t.Run("an old-layout folder is changed", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(oldDir+"/02-design.md", "A second line.", "A different line.")
		if res := g.vet(nil); !has(res, "V31", oldDir+"/02-design.md was changed") {
			t.Errorf("want V31 on an old-layout folder:\n%s", dump(res))
		}
	})
	t.Run("the link fix of M4", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(oldDir+"/02-design.md", "See [0014](../../0014/) for the rest.", "See enhancement 0014 for the rest.")
		if res := g.vet(nil); count(res, "V31") != 0 {
			t.Errorf("the link fix is the one allowed edit:\n%s", dump(res))
		}
	})
	t.Run("the link fix plus another edit", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(oldDir+"/02-design.md", "See [0014](../../0014/) for the rest.", "See enhancement 0014 for the rest.")
		g.replace(oldDir+"/02-design.md", "A second line.", "A different line.")
		if res := g.vet(nil); !has(res, "V31", "was changed") {
			t.Errorf("another edit beside the link fix must fail:\n%s", dump(res))
		}
	})
	t.Run("a link line that keeps its link", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(oldDir+"/02-design.md", "for the rest.", "for all the rest.")
		if res := g.vet(nil); !has(res, "V31", "was changed") {
			t.Errorf("an edit that keeps the link is not the fix:\n%s", dump(res))
		}
	})
	t.Run("the link fix changes the line count", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(oldDir+"/02-design.md", "See [0014](../../0014/) for the rest.\n", "See enhancement 0014.\nFor the rest.\n")
		if res := g.vet(nil); !has(res, "V31", "was changed") {
			t.Errorf("the fix keeps the line count:\n%s", dump(res))
		}
	})
	t.Run("a folder archived by this branch", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.write("openspec/changes/archive/2026-10-11-0103-new-entry/proposal.md", "new\n")
		if res := g.vet(nil); count(res, "V31") != 0 {
			t.Errorf("a folder that is not at the base is the archive itself:\n%s", dump(res))
		}
	})
	t.Run("keys limit the folders", func(t *testing.T) {
		g, _, _ := newGitRepo(t)
		g.replace(closedDir+"/proposal.md", "The text", "Other text")
		g.replace(oldDir+"/02-design.md", "A second line.", "A different line.")
		res := g.vet(func(o *Options) { o.Keys = []string{"0001"} })
		if !has(res, "V31", oldDir) || has(res, "V31", closedDir) {
			t.Errorf("only archive/0001 was asked for:\n%s", dump(res))
		}
		res = g.vet(func(o *Options) { o.Keys = []string{"0102"} })
		if has(res, "V31", oldDir) || !has(res, "V31", closedDir) {
			t.Errorf("only 0102 was asked for:\n%s", dump(res))
		}
	})
}

func TestLinkFixOnly(t *testing.T) {
	for _, tc := range []struct {
		name, old, head string
		want            bool
	}{
		{"same", "a\n", "a\n", true},
		{"link removed", "See [x](../../0014/).\n", "See enhancement 0014.\n", true},
		{"two links, one left", "[a](../a/) [b](../b/)\n", "enhancement a [b](../b/)\n", false},
		{"two links, both gone", "[a](../a/) [b](../b/)\n", "enhancement a and b\n", true},
		{"an inside link changes", "[a](a.md)\n", "[a](b.md)\n", false},
		{"a link kept and text changed", "[a](../a/) now\n", "[a](../a/) later\n", false},
		{"line added", "x\n", "x\ny\n", false},
	} {
		if got := linkFixOnly(tc.old, tc.head); got != tc.want {
			t.Errorf("%s: linkFixOnly = %v, want %v", tc.name, got, tc.want)
		}
	}
}
