// Package stale finds the stale base of an accepted entry (design part two,
// section 4.2): a requirement the entry modifies, removes or renames whose
// block in specs/ differs from the block at the accepted commit.
package stale

import (
	"fmt"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/sys"
)

// Operations a target can have in the entry.
const (
	OpModified = "MODIFIED"
	OpRemoved  = "REMOVED"
	OpRenamed  = "RENAMED"
)

// Flag is one stale target.
type Flag struct {
	Capability string
	Name       string
	// Op is MODIFIED, REMOVED or RENAMED (the FROM name).
	Op string
	// Then and Now are the requirement blocks, scenarios included; empty when
	// the matching Missing field is true.
	Then, Now               string
	ThenMissing, NowMissing bool
}

// Reason says in one phrase what differs.
func (f Flag) Reason() string {
	switch {
	case f.ThenMissing && f.NowMissing:
		return "missing at both sides"
	case f.ThenMissing:
		return "missing at the accepted commit"
	case f.NowMissing:
		return "missing in specs/ now"
	}
	return "text changed"
}

// Side reads the main spec of a capability on one side of the comparison. A
// capability with no spec yields (nil, nil).
type Side func(capability string) (*delta.Spec, error)

// Now reads specs/ from the loaded main specs.
func Now(specs map[string]*delta.Spec) Side {
	return func(c string) (*delta.Spec, error) { return specs[c], nil }
}

// Then reads specs/ at a commit through git. A capability that has no spec
// file at the commit yields nil. Each capability is read once.
func Then(g sys.Git, commit string) Side {
	cache := map[string]*delta.Spec{}
	return func(c string) (*delta.Spec, error) {
		if sp, ok := cache[c]; ok {
			return sp, nil
		}
		path := "openspec/specs/" + c + "/spec.md"
		var sp *delta.Spec
		if g.Exists(commit, path) {
			b, err := g.Show(commit, path)
			if err != nil {
				return nil, err
			}
			sp = delta.Parse(path, c, b)
		}
		cache[c] = sp
		return sp, nil
	}
}

// Target is a requirement a delta changes in specs/.
type Target struct {
	Capability string
	Name       string
	Op         string
}

// Targets lists the MODIFIED, REMOVED and RENAMED (FROM) requirements of the
// deltas, in file order, once each.
func Targets(deltas []*delta.Spec) []Target {
	var out []Target
	seen := map[string]bool{}
	add := func(c, n, op string) {
		n = delta.NormalizeName(n)
		k := c + "\x00" + n
		if seen[k] {
			return
		}
		seen[k] = true
		out = append(out, Target{c, n, op})
	}
	for _, sp := range deltas {
		for _, r := range sp.Requirements {
			switch r.Op {
			case delta.Modified:
				add(sp.Capability, r.Name, OpModified)
			case delta.Removed:
				add(sp.Capability, r.Name, OpRemoved)
			}
		}
		for _, rn := range sp.Renames {
			add(sp.Capability, rn.From, OpRenamed)
		}
	}
	return out
}

// Check compares each target on both sides. then is the side at the accepted
// commit, now the side of the working tree. An error is a failure to read,
// never a flag.
func Check(deltas []*delta.Spec, then, now Side) ([]Flag, error) {
	var flags []Flag
	for _, t := range Targets(deltas) {
		tb, tOK, err := block(then, t)
		if err != nil {
			return nil, err
		}
		nb, nOK, err := block(now, t)
		if err != nil {
			return nil, err
		}
		if tOK && nOK && Normalize(tb) == Normalize(nb) {
			continue
		}
		flags = append(flags, Flag{
			Capability: t.Capability, Name: t.Name, Op: t.Op,
			Then: tb, Now: nb, ThenMissing: !tOK, NowMissing: !nOK,
		})
	}
	return flags, nil
}

func block(side Side, t Target) (string, bool, error) {
	sp, err := side(t.Capability)
	if err != nil {
		return "", false, fmt.Errorf("stale: read %s: %w", t.Capability, err)
	}
	if sp == nil {
		return "", false, nil
	}
	for _, r := range sp.Requirements {
		if delta.NormalizeName(r.Name) == t.Name {
			return r.Raw, true, nil
		}
	}
	return "", false, nil
}

// Normalize folds line endings and trailing space, so a block compares equal
// across a checkout and a git object.
func Normalize(s string) string {
	lines := strings.Split(strings.ReplaceAll(s, "\r\n", "\n"), "\n")
	for i, l := range lines {
		lines[i] = strings.TrimRight(l, " \t")
	}
	return strings.TrimSpace(strings.Join(lines, "\n"))
}
