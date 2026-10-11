// Demonstrates the module compatibility gate: compare #config of a
// candidate release against its predecessor, classify the change, derive
// the bump the policy demands, and compare it with the bump the author
// claimed. compat/ is a byte copy of library/opm/compat/compat.go.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"

	"enhancements.opmodel.dev/0021/experiments/config-compat-gate/compat"
)

type class int

const (
	fix class = iota
	additive
	breaking
)

func (c class) String() string { return [...]string{"fix", "additive", "breaking"}[c] }

type level int

const (
	patch level = iota
	minor
	major
)

func (l level) String() string { return [...]string{"patch", "minor", "major"}[l] }

// stable table (0021 U2 / 02-design.md)
func required(c class, prestableZeroMajor bool) level {
	switch c {
	case breaking:
		if prestableZeroMajor { // 0.x: SemVer's escape hatch, breaking allowed in a minor
			return minor
		}
		return major
	case additive:
		return minor
	}
	return patch
}

func loadConfig(ctx *cue.Context, dir string) cue.Value {
	inst := load.Instances([]string{"."}, &load.Config{Dir: dir})[0]
	if inst.Err != nil {
		panic(inst.Err)
	}
	v := ctx.BuildInstance(inst)
	if v.Err() != nil {
		panic(v.Err())
	}
	return v.LookupPath(cue.ParsePath("#config"))
}

func classify(prev, next cue.Value) (class, []compat.Violation) {
	viol := compat.Check(prev, next) // 0010 D27's walk: removed, added-required, default, narrowed
	switch {
	case len(viol) > 0:
		return breaking, viol
	case prev.Subsume(next, cue.Schema(), cue.Raw()) != nil: // next accepts what prev did not
		return additive, nil
	}
	return fix, nil
}

func parseVer(s string) (maj, min, pat int) {
	base := strings.SplitN(s, "-", 2)[0]
	p := strings.Split(base, ".")
	maj, _ = strconv.Atoi(p[0])
	min, _ = strconv.Atoi(p[1])
	pat, _ = strconv.Atoi(p[2])
	return
}

// claimed is the SemVer distance from predecessor to the authored version.
func claimed(pred, next string) level {
	pM, pm, _ := parseVer(pred)
	nM, nm, _ := parseVer(next)
	switch {
	case nM != pM:
		return major
	case nm != pm:
		return minor
	}
	return patch
}

func main() {
	ctx := cuecontext.New()
	pred := "1.3.0"
	prev := loadConfig(ctx, filepath.Join("fixtures", pred))
	cands := []string{"1.3.1-fix", "1.4.0-additive", "1.4.0-rename", "1.4.0-required", "1.4.0-tighten", "1.4.0-default", "2.0.0-rename"}

	fmt.Printf("predecessor %s (0011 D23: newest published below the authored tag, same major)\n\n", pred)
	fmt.Printf("%-16s %-9s %-9s %-9s %s\n", "candidate", "class", "required", "claimed", "verdict")
	for _, c := range cands {
		next := loadConfig(ctx, filepath.Join("fixtures", c))
		cls, viol := classify(prev, next)
		ver := strings.SplitN(c, "-", 2)[0]
		req, got := required(cls, false), claimed(pred, ver)
		verdict := "GO"
		if got < req {
			verdict = "REFUSED"
		}
		fmt.Printf("%-16s %-9s %-9s %-9s %s\n", c, cls, req, got, verdict)
		for _, v := range viol {
			fmt.Printf("    %s: %s\n", v.Path, v.Kind)
		}
	}

	fmt.Println("\npre-stable (0.x) branch of the same rename, predecessor 0.3.0:")
	cls, _ := classify(prev, loadConfig(ctx, filepath.Join("fixtures", "1.4.0-rename")))
	fmt.Printf("%-16s %-9s %-9s %-9s %s\n", "0.4.0-rename", cls, required(cls, true), claimed("0.3.0", "0.4.0"), "GO")
	_ = os.Stdout
}
