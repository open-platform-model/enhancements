package tasks

import (
	"sort"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/sample"
	"github.com/open-platform-model/enhancements/tools/enh/internal/stale"
)

// capReq is a requirement block of a delta with its capability.
type capReq struct {
	Capability string
	delta.Requirement
}

func (c capReq) req() sample.Req {
	return sample.Req{Capability: c.Capability, Name: delta.NormalizeName(c.Name), Text: c.Text}
}

// opReqs lists the requirements of the entry's deltas with the operation.
func opReqs(en *entry.Entry, op delta.Op) []capReq {
	var out []capReq
	for _, sp := range en.Specs {
		for _, r := range sp.By(op) {
			out = append(out, capReq{sp.Capability, r})
		}
	}
	return out
}

// block is the requirement block without its heading line: the text, the
// scenarios, and for a REMOVED one the Reason and Migration.
func block(r delta.Requirement) string {
	lines := strings.Split(strings.TrimRight(r.Raw, "\n "), "\n")
	if len(lines) > 0 && strings.HasPrefix(strings.TrimSpace(lines[0]), "###") {
		lines = lines[1:]
	}
	return strings.TrimSpace(strings.Join(lines, "\n"))
}

func (e *Env) showReq(tag string, c capReq) {
	e.printf("\n[%s] %s/%s\n", tag, c.Capability, delta.NormalizeName(c.Name))
	if b := block(c.Requirement); b != "" {
		e.printf("%s\n", b)
	}
}

// universe lists every requirement of the main specs, in capability order.
func universe(st *entry.Store) []sample.Req {
	caps := make([]string, 0, len(st.Specs))
	for c := range st.Specs {
		caps = append(caps, c)
	}
	sort.Strings(caps)
	var out []sample.Req
	for _, c := range caps {
		for _, r := range st.Specs[c].Requirements {
			out = append(out, sample.Req{Capability: c, Name: delta.NormalizeName(r.Name), Text: r.Text})
		}
	}
	return out
}

// skipTargets returns a filter that drops the requirements the entry removes
// or modifies: the collision list is about what is new.
func skipTargets(en *entry.Entry) func(sample.Req) bool {
	skip := map[string]bool{}
	for _, t := range stale.Targets(en.Specs) {
		if t.Op == stale.OpRenamed {
			continue // the design skips what the entry removes or modifies
		}
		skip[t.Capability+"/"+t.Name] = true
	}
	return func(r sample.Req) bool { return skip[r.ID()] }
}

// printNearest prints the collision list of one requirement.
func (e *Env) printNearest(target sample.Req, uni []sample.Req, skip func(sample.Req) bool, header bool) {
	if header {
		e.printf("%s\n", target.ID())
	}
	near := sample.Nearest(target, uni, skip, 3)
	if len(near) == 0 {
		e.printf("    none: specs/ holds no other requirement to compare with\n")
		return
	}
	for _, n := range near {
		e.printf("    %.2f (%d shared) | %s\n", n.Score, n.Shared, n.ID())
	}
}

// seedFor returns the seed of a draw: the fixed one or a new random one.
func (e *Env) seedFor() (uint64, error) {
	if e.Seed != nil {
		return *e.Seed, nil
	}
	return sample.NewSeed()
}
