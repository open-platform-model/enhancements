package vet

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
)

// The rules in this file read git history through the hooks of Options, never
// by their own command, so a test can use a temporary repository or a stub.
// They need Options.Base, the base ref of the pull request (for example
// origin/main). With no Base the rules are skipped and the result says so.
//
//   - V7 (ancestry): the commit of `accepted:` is an ancestor of Base.
//   - V27: an accepted entry (or a sampled seed) whose requirement text
//     differs from Base while `accepted:` (`sampled:`) is unchanged.
//   - V31: an archived folder that differs from Base, except the generated
//     README.md and the one-time link fix of migration step M4.
//
// The paths given to the hooks are relative to the repository top level, so
// Options.Root must be that folder (as it is for the V25 hook).

// maxPerFolder caps the V31 findings of one folder, so that a deleted folder
// does not print one line for each of its files.
const maxPerFolder = 5

var (
	baseRefRe = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._/@{}~^-]*$`)
	// linkTargetRe finds the target of a Markdown inline link.
	linkTargetRe = regexp.MustCompile(`\]\(([^)\s]+)\)`)
)

func gitFiles(root, ref, dir string) ([]byte, error) {
	out, err := exec.Command("git", "-C", root, "ls-tree", "-r", "--name-only", "--full-name", "-z", ref, "--", dir).Output()
	if err != nil {
		return nil, fmt.Errorf("git ls-tree %s %s: %w", ref, dir, err)
	}
	return out, nil
}

// defaultGitFiles lists the files under dir at ref, as paths relative to the
// top level. A folder that does not exist at ref gives an empty list.
func defaultGitFiles(root, ref, dir string) ([]string, error) {
	out, err := gitFiles(root, ref, dir)
	if err != nil {
		return nil, err
	}
	var files []string
	for _, p := range bytes.Split(out, []byte{0}) {
		if len(p) > 0 {
			files = append(files, string(p))
		}
	}
	return files, nil
}

// defaultGitAncestor reports whether commit is an ancestor of ref. An unknown
// commit is an error, not "no".
func defaultGitAncestor(root, commit, ref string) (bool, error) {
	err := exec.Command("git", "-C", root, "merge-base", "--is-ancestor", commit, ref).Run()
	if err == nil {
		return true, nil
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) && ee.ExitCode() == 1 {
		return false, nil
	}
	return false, fmt.Errorf("git merge-base %s %s: %w", commit, ref, err)
}

func (r *run) haveBase() bool { return r.opts.Base != "" }

// gitRules runs the git rules that belong to one entry.
func (r *run) gitRules(e *ent) {
	if !r.haveBase() {
		return
	}
	if !e.isSeed() {
		r.acceptedAncestry(e)
	}
	if e.Archived {
		return
	}
	if e.isSeed() {
		r.editAfterSample(e)
	} else if e.Config.Status == "accepted" {
		r.editAfterAccept(e)
	}
}

// V7: the accepted commit is an ancestor of the base ref. The format of the
// line is checked by recordRules; a malformed line is not checked here.
func (r *run) acceptedAncestry(e *ent) {
	acc := e.Config.Accepted
	if !acceptedRe.MatchString(acc) {
		return
	}
	commit := acc[strings.IndexByte(acc, ' ')+1:]
	ok, err := r.opts.GitAncestor(r.store.Root, commit, r.opts.Base)
	switch {
	case err != nil:
		r.addField(e, "V7", Error, "accepted", "accepted commit %s cannot be checked against %s: %s (a shallow clone lacks it; fetch the full history)", commit, r.opts.Base, firstLine(err.Error()))
	case !ok:
		r.addField(e, "V7", Error, "accepted", "accepted commit %s is not an ancestor of %s", commit, r.opts.Base)
	}
}

// V27 for an entry: its requirement text differs from Base while accepted is unchanged.
func (r *run) editAfterAccept(e *ent) {
	baseCfg, ok := r.baseFile(path.Join(e.rel, "config.yaml"))
	if !ok {
		return // the entry is new on this branch
	}
	var c struct {
		Accepted string `yaml:"accepted"`
	}
	if yaml.Unmarshal(baseCfg, &c) != nil || c.Accepted == "" {
		return // a draft at Base: this branch is the accept
	}
	if c.Accepted != e.Config.Accepted {
		return // rewritten by a re-sample or a new accept
	}
	r.compareSpecs(e, "accepted")
}

// V27 for a seed: the requirement text differs from Base after `sampled:`.
func (r *run) editAfterSample(e *ent) {
	baseSrc, ok := r.baseFile(path.Join(e.rel, "source.md"))
	if !ok {
		return
	}
	bm := samplingRe.FindSubmatch(baseSrc)
	if bm == nil {
		return // not sampled yet at Base
	}
	hm := samplingRe.FindStringSubmatch(e.Source.Text)
	if hm != nil && strings.TrimSpace(hm[1]) != strings.TrimSpace(string(bm[1])) {
		return // sampled again
	}
	r.compareSpecs(e, "sampled")
}

// baseFile reads a file at the base ref; ok is false when it is not there.
func (r *run) baseFile(rel string) ([]byte, bool) {
	b, err := r.opts.GitShow(r.store.Root, r.opts.Base, rel)
	return b, err == nil
}

// compareSpecs reports every requirement of e that is new or differs from the
// copy at Base. A requirement that only left the entry is not reported: no
// text remains to sample.
func (r *run) compareSpecs(e *ent, marker string) {
	files, err := r.opts.GitFiles(r.store.Root, r.opts.Base, path.Join(e.rel, "specs"))
	if err != nil {
		r.add(e, "V27", Error, e.rel, 0, "cannot read specs/ at %s: %s", r.opts.Base, firstLine(err.Error()))
		return
	}
	base := map[string]string{}  // capability|op|name -> folded block
	renames := map[string]bool{} // from|to
	for _, f := range files {
		if path.Base(f) != "spec.md" {
			continue
		}
		b, ok := r.baseFile(f)
		if !ok {
			continue
		}
		cap := path.Base(path.Dir(f))
		sp := delta.Parse(f, cap, b)
		for _, q := range sp.Requirements {
			base[specKey(cap, q)] = fold(q.Raw)
		}
		for _, rn := range sp.Renames {
			renames[cap+"|"+rn.From+"|"+rn.To] = true
		}
	}
	for _, sp := range e.Specs {
		rel := relSlash(r.store.Root, sp.Path)
		for _, q := range sp.Requirements {
			old, had := base[specKey(sp.Capability, q)]
			switch {
			case !had:
				r.add(e, "V27", Error, rel, q.Line, "%s requirement %q is new since %s while %s is unchanged: run task resample, review it, and confirm", q.Op, q.Name, r.opts.Base, marker)
			case old != fold(q.Raw):
				r.add(e, "V27", Error, rel, q.Line, "%s requirement %q differs from %s while %s is unchanged: run task resample, review it, and confirm", q.Op, q.Name, r.opts.Base, marker)
			}
		}
		for _, rn := range sp.Renames {
			if !renames[sp.Capability+"|"+rn.From+"|"+rn.To] {
				r.add(e, "V27", Error, rel, rn.Line, "RENAMED %q to %q is new since %s while %s is unchanged: run task resample, review it, and confirm", rn.From, rn.To, r.opts.Base, marker)
			}
		}
	}
}

func specKey(capability string, q delta.Requirement) string {
	return capability + "|" + string(q.Op) + "|" + delta.NormalizeName(q.Name)
}

// fold makes whitespace differences invisible.
func fold(s string) string { return strings.Join(strings.Fields(s), " ") }

// archiveRoots are the two places an archived folder lives: the new layout
// (README.md is generated there) and the ten old-layout entries.
var archiveRoots = []struct {
	dir         string
	generatedMD bool
}{
	{"openspec/changes/archive", true},
	{"archive", false},
}

// V31: a folder archived at Base is unchanged at head.
func (r *run) closedFolders() {
	if !r.haveBase() {
		return
	}
	for _, ar := range archiveRoots {
		files, err := r.opts.GitFiles(r.store.Root, r.opts.Base, ar.dir)
		if err != nil {
			r.add(nil, "V31", Error, ar.dir, 0, "cannot list %s at %s: %s", ar.dir, r.opts.Base, firstLine(err.Error()))
			continue
		}
		byFolder := map[string][]string{}
		for _, f := range files {
			rest := strings.TrimPrefix(f, ar.dir+"/")
			if rest == f || !strings.Contains(rest, "/") {
				continue // a file of the archive folder itself
			}
			folder := rest[:strings.IndexByte(rest, '/')]
			byFolder[folder] = append(byFolder[folder], f)
		}
		var names []string
		for n := range byFolder {
			names = append(names, n)
		}
		sort.Strings(names)
		for _, n := range names {
			if !r.folderSelected(n) {
				continue
			}
			r.closedFolder(path.Join(ar.dir, n), byFolder[n], ar.generatedMD)
		}
	}
}

// folderSelected applies Options.Keys to an archive folder name.
func (r *run) folderSelected(name string) bool {
	if len(r.opts.Keys) == 0 {
		return true
	}
	for _, k := range r.opts.Keys {
		if k == name || strings.Contains(name, "-"+k+"-") || strings.HasSuffix(name, "-"+k) {
			return true
		}
	}
	return false
}

func (r *run) closedFolder(dir string, baseFiles []string, generatedMD bool) {
	var problems []string
	inBase := map[string]bool{}
	for _, f := range baseFiles {
		inBase[f] = true
		rel := strings.TrimPrefix(f, dir+"/")
		if generatedMD && rel == "README.md" {
			continue
		}
		head, err := os.ReadFile(filepath.Join(r.store.Root, filepath.FromSlash(f)))
		if errors.Is(err, fs.ErrNotExist) {
			problems = append(problems, fmt.Sprintf("%s was deleted", f))
			continue
		}
		if err != nil {
			problems = append(problems, fmt.Sprintf("%s cannot be read: %s", f, firstLine(err.Error())))
			continue
		}
		old, err := r.opts.GitShow(r.store.Root, r.opts.Base, f)
		if err != nil {
			problems = append(problems, fmt.Sprintf("%s cannot be read at %s: %s", f, r.opts.Base, firstLine(err.Error())))
			continue
		}
		if bytes.Equal(old, head) || linkFixOnly(string(old), string(head)) {
			continue
		}
		problems = append(problems, fmt.Sprintf("%s was changed", f))
	}
	_ = filepath.WalkDir(filepath.Join(r.store.Root, filepath.FromSlash(dir)), func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		rel, rerr := filepath.Rel(r.store.Root, p)
		if rerr != nil {
			return nil
		}
		f := filepath.ToSlash(rel)
		if inBase[f] || (generatedMD && f == dir+"/README.md") {
			return nil
		}
		problems = append(problems, fmt.Sprintf("%s was added", f))
		return nil
	})
	sort.Strings(problems)
	for i, p := range problems {
		if i == maxPerFolder {
			r.add(nil, "V31", Error, dir, 0, "and %d more changes in %s", len(problems)-maxPerFolder, dir)
			break
		}
		r.add(nil, "V31", Error, dir, 0, "%s since %s: an archived folder is closed (only README.md regeneration and the one-time link fix are allowed)", p, r.opts.Base)
	}
}

// linkFixOnly reports whether head differs from old only by links that left
// the folder: the same lines, and on each changed line every link that
// pointed out of the folder is gone (the M4 rewrite into the words
// "enhancement NNNN").
func linkFixOnly(old, head string) bool {
	ol := strings.Split(strings.ReplaceAll(old, "\r\n", "\n"), "\n")
	hl := strings.Split(strings.ReplaceAll(head, "\r\n", "\n"), "\n")
	if len(ol) != len(hl) {
		return false
	}
	for i := range ol {
		if ol[i] == hl[i] {
			continue
		}
		out := 0
		for _, m := range linkTargetRe.FindAllStringSubmatch(ol[i], -1) {
			t := m[1]
			if !strings.HasPrefix(t, "../") {
				continue
			}
			if strings.Contains(hl[i], "]("+t+")") {
				return false // an out-of-folder link is still there
			}
			out++
		}
		if out == 0 {
			return false // the line changed but held no such link
		}
	}
	return true
}
