// Package links checks the relative links of the Markdown files of the
// enhancements repo (T2.3 section 4.6, rule V28; T2.2 section 6):
//
//   - a link from one entry into another entry's folder, or into an archive
//     folder, is refused: archive adds a date prefix to the folder name, so a
//     path link breaks, and an entry cites another entry by id in words;
//   - a link inside one entry is allowed: it moves with the folder;
//   - every other relative link of a published file must resolve.
//
// Every entry folder is a source, the ten old-layout folders archive/NNNN/
// included. It replaces scripts/check-links.sh and relink.sh.
package links

import (
	"errors"
	"fmt"
	"io/fs"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Rule names.
const (
	RuleCrossEntry = "cross-entry"
	RuleBroken     = "broken"
	RuleAbsolute   = "absolute"
	RuleOutside    = "outside-repo"
)

// Finding is one violation.
type Finding struct {
	Path    string
	Line    int
	Rule    string
	Target  string
	Message string
}

func (f Finding) String() string {
	return fmt.Sprintf("%s:%d: %s: %s", f.Path, f.Line, f.Rule, f.Message)
}

// Result is the outcome of a check.
type Result struct {
	Findings []Finding
	// Files counts the Markdown files read.
	Files int
}

const (
	changesDir        = "openspec/changes"
	changesArchiveDir = "openspec/changes/archive"
	legacyArchiveDir  = "archive"
)

var entryIDRe = regexp.MustCompile(`^\d{4}$`)

// place says where a repo-relative path sits.
type place struct {
	// entry is the entry folder that holds the path, "" if none.
	entry string
	// archive is true for the archive folder itself, with no entry named.
	archive bool
}

// locate classifies a clean, repo-relative, slash-separated path.
func locate(p string) place {
	segs := strings.Split(p, "/")
	switch {
	case p == changesArchiveDir || p == legacyArchiveDir:
		return place{archive: true}
	case strings.HasPrefix(p, changesArchiveDir+"/"):
		return place{entry: changesArchiveDir + "/" + segs[3]}
	case strings.HasPrefix(p, changesDir+"/"):
		return place{entry: changesDir + "/" + segs[2]}
	case segs[0] == legacyArchiveDir && len(segs) > 1:
		return place{entry: legacyArchiveDir + "/" + segs[1]}
	case entryIDRe.MatchString(segs[0]):
		return place{entry: segs[0]}
	}
	return place{}
}

// Published lists the files the site publishes: INDEX.md, GRAPH.md and the
// documents of every entry (README, proposal, design, tasks, the seven
// split documents of an old-layout entry, and the delta specs).
func Published(root string) ([]string, error) {
	var out []string
	for _, f := range []string{"INDEX.md", "GRAPH.md"} {
		if _, err := os.Stat(filepath.Join(root, f)); err == nil {
			out = append(out, f)
		}
	}
	dirs, err := entryDirs(root)
	if err != nil {
		return nil, err
	}
	for _, d := range dirs {
		ents, err := os.ReadDir(filepath.Join(root, d))
		if err != nil {
			return nil, err
		}
		for _, e := range ents {
			n := e.Name()
			if e.IsDir() && n == "specs" {
				caps, err := os.ReadDir(filepath.Join(root, d, n))
				if err != nil {
					return nil, err
				}
				for _, c := range caps {
					rel := path.Join(d, n, c.Name(), "spec.md")
					if _, err := os.Stat(filepath.Join(root, rel)); err == nil {
						out = append(out, rel)
					}
				}
				continue
			}
			if e.IsDir() || !strings.HasSuffix(n, ".md") {
				continue
			}
			switch {
			case n == "README.md", n == "proposal.md", n == "design.md", n == "tasks.md":
				out = append(out, path.Join(d, n))
			case len(n) > 2 && n[0] == '0' && n[1] >= '1' && n[1] <= '7' && n[2] == '-':
				out = append(out, path.Join(d, n))
			}
		}
	}
	sort.Strings(out)
	return out, nil
}

// entryDirs lists the entry folders that exist, repo-relative. The template
// folder 0000 is not an entry for this purpose.
func entryDirs(root string) ([]string, error) {
	var out []string
	add := func(parent string, numericOnly bool, skip string) error {
		ents, err := os.ReadDir(filepath.Join(root, parent))
		if errors.Is(err, fs.ErrNotExist) {
			return nil
		}
		if err != nil {
			return err
		}
		for _, e := range ents {
			n := e.Name()
			if !e.IsDir() || n == skip || strings.HasPrefix(n, ".") {
				continue
			}
			if numericOnly && (!entryIDRe.MatchString(n) || n == "0000") {
				continue
			}
			out = append(out, path.Join(parent, n))
		}
		return nil
	}
	for _, step := range []struct {
		parent  string
		numeric bool
		skip    string
	}{
		{".", true, ""},
		{legacyArchiveDir, true, ""},
		{changesDir, false, "archive"},
		{changesArchiveDir, false, ""},
	} {
		if err := add(step.parent, step.numeric, step.skip); err != nil {
			return nil, err
		}
	}
	for i, d := range out {
		out[i] = strings.TrimPrefix(d, "./")
	}
	return out, nil
}

// entryMarkdown lists every Markdown file inside the entry folders.
func entryMarkdown(root string) ([]string, error) {
	dirs, err := entryDirs(root)
	if err != nil {
		return nil, err
	}
	var out []string
	for _, d := range dirs {
		err := filepath.WalkDir(filepath.Join(root, d), func(p string, e fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if e.IsDir() && (e.Name() == "node_modules" || e.Name() == ".git") {
				return filepath.SkipDir
			}
			if !e.IsDir() && strings.HasSuffix(e.Name(), ".md") {
				rel, rerr := filepath.Rel(root, p)
				if rerr != nil {
					return rerr
				}
				out = append(out, filepath.ToSlash(rel))
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return out, nil
}

// Check runs both checks over the repo at root: the cross-entry rule on every
// Markdown file inside an entry, the resolution check on the published set.
func Check(root string) (Result, error) {
	if info, err := os.Stat(root); err != nil || !info.IsDir() {
		return Result{}, fmt.Errorf("links: %s is not a directory", root)
	}
	pub, err := Published(root)
	if err != nil {
		return Result{}, err
	}
	all, err := entryMarkdown(root)
	if err != nil {
		return Result{}, err
	}
	resolve := map[string]bool{}
	for _, f := range pub {
		resolve[f] = true
	}
	seen := map[string]bool{}
	var files []string
	for _, f := range append(append([]string{}, pub...), all...) {
		if !seen[f] {
			seen[f] = true
			files = append(files, f)
		}
	}
	return check(root, files, func(f string) bool { return resolve[f] })
}

// CheckFiles runs both checks over an explicit list of files, relative to
// root. Every listed file gets both checks.
func CheckFiles(root string, files []string) (Result, error) {
	return check(root, files, func(string) bool { return true })
}

func check(root string, files []string, resolves func(string) bool) (Result, error) {
	var res Result
	var errs []error
	for _, f := range files {
		f = path.Clean(filepath.ToSlash(f))
		src, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(f)))
		if err != nil {
			errs = append(errs, err)
			continue
		}
		res.Files++
		res.Findings = append(res.Findings, checkFile(root, f, string(src), resolves(f))...)
	}
	sort.SliceStable(res.Findings, func(i, j int) bool {
		if res.Findings[i].Path != res.Findings[j].Path {
			return res.Findings[i].Path < res.Findings[j].Path
		}
		return res.Findings[i].Line < res.Findings[j].Line
	})
	return res, errors.Join(errs...)
}

func checkFile(root, rel, src string, resolve bool) []Finding {
	var out []Finding
	from := locate(rel)
	dir := path.Dir(rel)
	for _, l := range extract(src) {
		t := l.target
		if strings.HasPrefix(t, "#") || schemeRe.MatchString(t) {
			continue
		}
		p := t
		if i := strings.IndexAny(p, "#?"); i >= 0 {
			p = p[:i]
		}
		if p == "" {
			continue
		}
		if u, err := url.PathUnescape(p); err == nil {
			p = u
		}
		add := func(rule, msg string) {
			out = append(out, Finding{Path: rel, Line: l.line, Rule: rule, Target: t, Message: msg})
		}
		if strings.HasPrefix(p, "/") {
			if resolve {
				add(RuleAbsolute, fmt.Sprintf("%s (absolute path; use a relative link)", t))
			}
			continue
		}
		target := path.Clean(path.Join(dir, p))
		if target == ".." || strings.HasPrefix(target, "../") {
			if resolve {
				add(RuleOutside, fmt.Sprintf("%s (leaves the repository)", t))
			}
			continue
		}
		if from.entry != "" {
			to := locate(target)
			switch {
			case to.archive:
				add(RuleCrossEntry, fmt.Sprintf("%s (links into archive/: cite the entry by id in words, for example \"enhancement 0014\")", t))
				continue
			case to.entry != "" && to.entry != from.entry:
				add(RuleCrossEntry, fmt.Sprintf("%s (links into another entry's folder %s: cite the entry by id in words, for example \"enhancement 0014\")", t, to.entry))
				continue
			}
		}
		if resolve {
			if _, err := os.Stat(filepath.Join(root, filepath.FromSlash(target))); err != nil {
				add(RuleBroken, fmt.Sprintf("%s (target does not exist)", t))
			}
		}
	}
	return out
}
