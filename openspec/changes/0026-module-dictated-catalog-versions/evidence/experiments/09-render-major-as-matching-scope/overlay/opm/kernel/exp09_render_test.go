package kernel_test

// Enhancement 0026, experiment 09: renders with the catalog major as a
// matching scope. Needs library.patch applied (scoped buckets in the render
// glue, scoped inventory types) and serves core in-process: v2.0.0-alpha.12 is
// core cbe93e0 as shipped, v2.0.0-alpha.13 is core cbe93e0 plus experiment
// 05's core.patch. Not a regression test: it logs what happens and never
// fails on a verdict. Copied into a checkout of library by ../../../run.sh.

import (
	"context"
	"encoding/json"
	stderrors "errors"
	"strings"
	"testing"

	"cuelang.org/go/cue"

	"github.com/open-platform-model/library/opm/internal/registrytest"
	"github.com/open-platform-model/library/opm/internal/schematest"
	"github.com/open-platform-model/library/opm/kernel"
)

func e09json(v any) string { b, _ := json.Marshal(v); return string(b) }

func newExp09Kernel(t *testing.T) *kernel.Kernel {
	t.Helper()
	mapping := registrytest.NewRegistryFromDir(t, renderFixtureDir(t, "registry"), renderPrefix)
	host := mapping[strings.Index(mapping, "=")+1 : strings.Index(mapping, "+insecure")]
	m2 := "opmodel.dev/core=" + host + "+insecure," + mapping
	t.Setenv("CUE_REGISTRY", m2)
	t.Setenv("CUE_CACHE_DIR", schematest.IsolatedCacheDir(t))
	return kernel.New(kernel.WithRegistry(m2))
}

func TestExp09(t *testing.T) {
	cases := []struct {
		plat, inst string
		skip       bool
	}{
		{"mplat_maj_both", "inst_maj0", false},
		{"sp_maj_both", "inst_maj0", false},
		{"sp_maj_both", "inst_maj1", false},
		{"sp_maj_both", "inst_mix", false},
		{"sp_maj_v1", "inst_maj0", false},
		{"sp_bprov_both", "inst_bk0", false},
		{"sp_bprov_v1only", "inst_bk0", true},
		{"sp_bprov_v1only", "inst_bk0", false},
		{"sp_bridge", "inst_maj0", false},
		{"sp_bridge", "inst_maj1", false},
	}
	for _, c := range cases {
		name := c.plat + "/" + c.inst
		if c.skip {
			name += "/skip"
		}
		t.Run(name, func(t *testing.T) {
			k := newExp09Kernel(t)
			p, err := k.AcquirePlatformFromDir(context.Background(), renderFixtureDir(t, c.plat))
			if err != nil {
				t.Logf("ACQUIRE PLATFORM ERROR: %v", err)
				return
			}
			inv, ierr := p.Contracts()
			if ierr != nil {
				t.Logf("CONTRACTS ERROR: %v", ierr)
			} else {
				t.Logf("inventory: %s", e09json(inv))
			}
			inst, err := k.AcquireInstanceFromDir(context.Background(), renderFixtureDir(t, c.inst))
			if err != nil {
				t.Logf("ACQUIRE INSTANCE ERROR: %v", err)
				return
			}
			built, res, rerr := k.RenderForTest(context.Background(), kernel.RenderInput{Instance: inst, Platform: p, RuntimeName: "rt", LocalReplacements: true, SkipUnprovided: c.skip})
			if built.Exists() {
				g := built.LookupPath(cue.ParsePath("gate"))
				t.Logf("gate: %v / err %v", g, g.Err())
				u := built.LookupPath(cue.ParsePath("match.unresolved"))
				b, _ := u.MarshalJSON()
				t.Logf("glue unresolved rows: %s", b)
				sk := built.LookupPath(cue.ParsePath("match.skipped"))
				b, _ = sk.MarshalJSON()
				dm, _ := built.LookupPath(cue.ParsePath("match.doubleMatched")).MarshalJSON()
				t.Logf("doubleMatched: %s", dm)
				t.Logf("glue skipped rows: %s", b)
				rv := built.LookupPath(cue.ParsePath("_resolvedCore"))
				_ = rv
			}
			if rerr != nil {
				t.Logf("RENDER ERROR: %v", rerr)
				var re *kernel.RenderError
				if stderrors.As(rerr, &re) {
					t.Logf("refusal diagnostics: %s", e09json(re.Diagnostics))
				}
				return
			}
			t.Logf("pairs: %s", e09json(res.Diagnostics.Pairs))
			t.Logf("unifyFailures: %s", e09json(res.Diagnostics.Unify))
			for _, rv := range res.Diagnostics.ResolvedVersions {
				if strings.Contains(e09json(rv), "core") {
					t.Logf("resolved: %s", e09json(rv))
				}
			}
			for _, o := range res.Compiled {
				b, _ := o.Value.MarshalJSON()
				t.Logf("OBJ %s", b)
			}
		})
	}
}
