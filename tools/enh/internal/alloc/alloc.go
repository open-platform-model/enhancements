// Package alloc picks the next enhancement id (design part two, section 4.5).
//
// The next id is the lowest four-digit number, from 0001 up, that is not
// used, reserved or blocked. The package reads the repo through an fs.FS and
// takes the branch names as a list. It never runs git and never fetches, so
// the caller says when the list is stale.
package alloc

import (
	"errors"
	"fmt"
	"io/fs"
	"regexp"
	"sort"
	"strings"
)

// FetchNote is the warning for a call that got no branch names.
const FetchNote = "no branch names given: fetch and pass `git branch -a` to see ids that open branches use"

// branchPrefixes are the branch name prefixes that carry an id, as in
// docs/0033-title. A ref is matched after its refs/heads/ or remote prefix.
var branchPrefixes = []string{"docs"}

// Inputs is everything Next reads.
type Inputs struct {
	// FS is the repo root.
	FS fs.FS
	// Schema is the text of schema.cue, which holds reservedIds and blockedIds.
	Schema []byte
	// Refs are local and remote branch names, one per entry, as git prints them.
	Refs []string
}

// Result is the answer and the facts behind it.
type Result struct {
	// ID is the next id, four digits.
	ID string
	// Taken maps each id that is used, reserved or blocked to the reasons.
	Taken map[string][]string
	// Warnings are notes for the caller to print.
	Warnings []string
}

var (
	idRe        = regexp.MustCompile(`^[0-9]{4}$`)
	liveRe      = regexp.MustCompile(`^([0-9]{4})-`)
	archivedRe  = regexp.MustCompile(`^[0-9]{4}-[0-9]{2}-[0-9]{2}-([0-9]{4})-`)
	quotedIDRe  = regexp.MustCompile(`"([^"]*)"`)
	listStartRe = regexp.MustCompile(`(?m)^(reservedIds|blockedIds):[ \t]*\[`)
)

// Next returns the lowest free id.
func Next(in Inputs) (Result, error) {
	taken, err := Taken(in)
	if err != nil {
		return Result{}, err
	}
	res := Result{Taken: taken}
	if len(in.Refs) == 0 {
		res.Warnings = append(res.Warnings, FetchNote)
	}
	// 0000 was the template folder. It is never handed out, whatever the lists say.
	for n := 1; n <= 9999; n++ {
		id := fmt.Sprintf("%04d", n)
		if _, ok := taken[id]; !ok {
			res.ID = id
			return res, nil
		}
	}
	return Result{}, errors.New("no free id: 0001 to 9999 are all taken")
}

// Taken returns every id that Next must not hand out, with the reasons.
func Taken(in Inputs) (map[string][]string, error) {
	if in.FS == nil {
		return nil, errors.New("alloc: no file system")
	}
	reserved, blocked, err := ReadLists(in.Schema)
	if err != nil {
		return nil, err
	}
	taken := map[string][]string{}
	add := func(id, why string) {
		for _, w := range taken[id] {
			if w == why {
				return
			}
		}
		taken[id] = append(taken[id], why)
	}
	for _, id := range reserved {
		add(id, "reserved in schema.cue")
	}
	for _, id := range blocked {
		add(id, "blocked in schema.cue")
	}
	// Live entries and seeds. A seed folder starts with "seed-", so it has no id.
	if err := eachDir(in.FS, "openspec/changes", func(name string) {
		if m := liveRe.FindStringSubmatch(name); m != nil {
			add(m[1], "openspec/changes/"+name)
		}
	}); err != nil {
		return nil, err
	}
	if err := eachDir(in.FS, "openspec/changes/archive", func(name string) {
		if m := archivedRe.FindStringSubmatch(name); m != nil {
			add(m[1], "openspec/changes/archive/"+name)
		}
	}); err != nil {
		return nil, err
	}
	if err := eachDir(in.FS, "archive", func(name string) {
		if idRe.MatchString(name) {
			add(name, "archive/"+name)
		}
	}); err != nil {
		return nil, err
	}
	if err := eachDir(in.FS, ".", func(name string) {
		if idRe.MatchString(name) {
			add(name, name+"/ (old layout, live)")
		}
	}); err != nil {
		return nil, err
	}
	for _, ref := range in.Refs {
		if id, ok := BranchID(ref); ok {
			add(id, "branch "+strings.TrimSpace(ref))
		}
	}
	for id := range taken {
		if !idRe.MatchString(id) {
			return nil, fmt.Errorf("alloc: %q is not a four-digit id", id)
		}
	}
	return taken, nil
}

// BranchID returns the id in a branch name like docs/0033-title, with an
// optional refs/heads/, refs/remotes/<remote>/ or <remote>/ prefix.
func BranchID(ref string) (string, bool) {
	name := strings.TrimSpace(ref)
	// git branch -a marks the checked-out branch with "* " and a branch checked
	// out in a linked worktree with "+ ".
	name = strings.TrimPrefix(name, "* ")
	name = strings.TrimPrefix(name, "+ ")
	name = strings.TrimPrefix(name, "remotes/")
	switch {
	case strings.HasPrefix(name, "refs/heads/"):
		name = strings.TrimPrefix(name, "refs/heads/")
	case strings.HasPrefix(name, "refs/remotes/"):
		name = strings.TrimPrefix(name, "refs/remotes/")
		name = dropFirstSegment(name)
	}
	for _, p := range branchPrefixes {
		for _, cand := range []string{name, dropFirstSegment(name)} {
			if rest, ok := strings.CutPrefix(cand, p+"/"); ok && len(rest) >= 5 && idRe.MatchString(rest[:4]) && rest[4] == '-' {
				return rest[:4], true
			}
		}
	}
	return "", false
}

func dropFirstSegment(s string) string {
	if _, rest, ok := strings.Cut(s, "/"); ok {
		return rest
	}
	return s
}

// eachDir calls fn with the name of each directory in dir. A missing dir is
// not an error: a repo without openspec/changes/archive has no archived ids.
func eachDir(fsys fs.FS, dir string, fn func(name string)) error {
	entries, err := fs.ReadDir(fsys, dir)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("alloc: read %s: %w", dir, err)
	}
	for _, e := range entries {
		if e.IsDir() {
			fn(e.Name())
		}
	}
	return nil
}

// ReadLists reads reservedIds and blockedIds from the text of schema.cue.
// It is a narrow reader for two string lists, so that this package needs no
// CUE dependency. It fails when a list is missing, so that an edit which
// removes one cannot let a reserved id through.
func ReadLists(schema []byte) (reserved, blocked []string, err error) {
	reserved, err = readList(schema, "reservedIds")
	if err != nil {
		return nil, nil, err
	}
	blocked, err = readList(schema, "blockedIds")
	if err != nil {
		return nil, nil, err
	}
	return reserved, blocked, nil
}

func readList(schema []byte, name string) ([]string, error) {
	text := string(schema)
	var ids []string
	found := false
	for _, loc := range listStartRe.FindAllStringSubmatchIndex(text, -1) {
		if text[loc[2]:loc[3]] != name {
			continue
		}
		if found {
			return nil, fmt.Errorf("schema.cue: %s is defined twice", name)
		}
		found = true
		closed := false
		for _, line := range strings.Split(text[loc[1]:], "\n") {
			if i := strings.Index(line, "//"); i >= 0 {
				line = line[:i]
			}
			if i := strings.Index(line, "]"); i >= 0 {
				line, closed = line[:i], true
			}
			for _, m := range quotedIDRe.FindAllStringSubmatch(line, -1) {
				if !idRe.MatchString(m[1]) {
					return nil, fmt.Errorf("schema.cue: %s holds %q, which is not a four-digit id", name, m[1])
				}
				ids = append(ids, m[1])
			}
			if rest := strings.TrimSpace(strings.ReplaceAll(quotedIDRe.ReplaceAllString(line, ""), ",", "")); rest != "" {
				return nil, fmt.Errorf("schema.cue: %s holds %q, which is not a quoted id", name, rest)
			}
			if closed {
				break
			}
		}
		if !closed {
			return nil, fmt.Errorf("schema.cue: %s has no closing bracket", name)
		}
	}
	if !found {
		return nil, fmt.Errorf("schema.cue: %s is missing", name)
	}
	sort.Strings(ids)
	return ids, nil
}
