package kernel_test

// Enhancement 0026, experiment 07: renders against the shipped library and
// core with two majors of one catalog on the platform. Not a regression test:
// it logs what happens, one compact line per fact, and never fails on a
// verdict. Copied into a checkout of library 30f08c1 by ../../../run.sh.

import (
	"context"
	"encoding/json"
	stderrors "errors"
	"testing"

	"cuelang.org/go/cue"

	"github.com/open-platform-model/library/opm/kernel"
)

// e07json marshals v and drops null and empty fields, so a log line carries
// only what the case produced.
func e07json(v any) string {
	b, _ := json.Marshal(v)
	var x any
	if json.Unmarshal(b, &x) != nil {
		return string(b)
	}
	b, _ = json.Marshal(e07prune(x))
	return string(b)
}

func e07prune(x any) any {
	switch t := x.(type) {
	case map[string]any:
		out := map[string]any{}
		for k, v := range t {
			v = e07prune(v)
			switch vv := v.(type) {
			case nil:
				continue
			case []any:
				if len(vv) == 0 {
					continue
				}
			case map[string]any:
				if len(vv) == 0 {
					continue
				}
			case string:
				if vv == "" {
					continue
				}
			}
			out[k] = v
		}
		return out
	case []any:
		for i := range t {
			t[i] = e07prune(t[i])
		}
		return t
	}
	return x
}

func TestExp07(t *testing.T) {
	cases := []struct{ plat, inst string }{
		// shared keys, one major on the platform: the baseline
		{"mplat_maj_v0", "inst_maj0"},
		// shared keys, both majors define the same keys
		{"mplat_maj_both", "inst_maj0"},
		// shared keys, only maj@v0 lists them; maj@v1 ships transformers
		{"mplat_maj_both_nodef", "inst_maj0"},
		{"mplat_maj_both_nodef", "inst_maj1"},
		// a maj@v0 module on a platform carrying only maj@v1
		{"mplat_maj_v1", "inst_maj0"},
		// shared keys, one provider per declaring major
		{"mplat_bprov_v0", "inst_bk0"},
		{"mplat_bprov_both", "inst_bk0"},
		{"mplat_bprov_v1only", "inst_bk0"},
		// shared keys, maj@v1 ships a bridge requiring maj@v0's container
		{"mplat_maj_bridge_nodef", "inst_maj0"},
		// the major as a key path segment (.../majk/v0/...), shipped core
		{"mplat_majk_both", "inst_majk0"},
		{"mplat_majk_both", "inst_majk1"},
		{"mplat_majk_v1", "inst_majk0"},
		{"mplat_majk_bridge", "inst_majk0"},
	}
	for _, c := range cases {
		t.Run(c.plat+"/"+c.inst, func(t *testing.T) {
			k := newRenderKernel(t)
			p, err := k.AcquirePlatformFromDir(context.Background(), renderFixtureDir(t, c.plat))
			if err != nil {
				t.Logf("ACQUIRE PLATFORM ERROR: %v", err)
				return
			}
			if inv, ierr := p.Contracts(); ierr != nil {
				t.Logf("CONTRACTS ERROR: %v", ierr)
			} else {
				t.Logf("inventory: %s", e07json(inv))
			}
			inst, err := k.AcquireInstanceFromDir(context.Background(), renderFixtureDir(t, c.inst))
			if err != nil {
				t.Logf("ACQUIRE INSTANCE ERROR: %v", err)
				return
			}
			built, res, rerr := k.RenderForTest(context.Background(), kernel.RenderInput{Instance: inst, Platform: p, RuntimeName: "rt", LocalReplacements: true, SkipUnprovided: true})
			if built.Exists() {
				g := built.LookupPath(cue.ParsePath("gate"))
				t.Logf("gate: %v (err %v)", g, g.Err())
			}
			if rerr != nil {
				t.Logf("RENDER REFUSED: %v", rerr)
				var re *kernel.RenderError
				if stderrors.As(rerr, &re) {
					t.Logf("refusal diagnostics: %s", e07json(re.Diagnostics))
				}
				return
			}
			t.Logf("pairs: %s", e07json(res.Diagnostics.Pairs))
			t.Logf("unify: %s", e07json(res.Diagnostics.Unify))
			t.Logf("skipped: %s", e07json(res.Diagnostics.Skipped))
			for _, o := range res.Compiled {
				b, _ := o.Value.MarshalJSON()
				t.Logf("OBJ %s", b)
			}
		})
	}
}
