package kernel_test

// Enhancement 0026, experiment 08: renders through the shipped library 30f08c1
// with module-qualified contract keys. With patchedCore set, the test serves
// core cbe93e0 plus experiment 03's core.patch (the directory LINEAGE_CORE
// names) as opmodel.dev/core v2.0.0-alpha.12. Not a regression test: it logs
// what happens and never fails on a verdict. Copied into a checkout of library
// by ../../../run.sh.

import (
	"context"
	"encoding/json"
	stderrors "errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"testing/fstest"

	"cuelang.org/go/cue"
	"cuelang.org/go/mod/modregistrytest"
	"github.com/stretchr/testify/require"

	"github.com/open-platform-model/library/opm/internal/schematest"
	"github.com/open-platform-model/library/opm/kernel"
)

func lineageDump(t *testing.T, label string, v any) {
	b, _ := json.Marshal(v)
	t.Logf("%s: %s", label, b)
}

func addTree(t *testing.T, m fstest.MapFS, dir, prefix string, skip func(string) bool) {
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, _ := filepath.Rel(dir, p)
		if skip != nil && skip(rel) {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		m[prefix+filepath.ToSlash(rel)] = &fstest.MapFile{Data: b}
		return nil
	})
	require.NoError(t, err)
}

// lineageKernel serves testdata/lineage/registry in-process. With patchedCore
// set, it also serves the scratch core (LINEAGE_CORE) as
// opmodel.dev/core v2.0.0-alpha.12 and routes opmodel.dev to it.
func lineageKernel(t *testing.T, patchedCore bool) *kernel.Kernel {
	m := fstest.MapFS{}
	addTree(t, m, filepath.Join(schematest.LibraryRoot(t), "testdata", "lineage", "registry"), "", nil)
	prefix := "testing.opmodel.dev/library-render"
	if patchedCore {
		coreDir := os.Getenv("LINEAGE_CORE")
		require.NotEmpty(t, coreDir)
		addTree(t, m, coreDir, "opmodel.dev_core_v2.0.0-alpha.12/", func(rel string) bool {
			return strings.HasSuffix(rel, "_pins.cue") || strings.HasPrefix(rel, "zz_") || strings.HasSuffix(rel, ".md")
		})
		reg, err := modregistrytest.New(m, "")
		require.NoError(t, err)
		t.Cleanup(reg.Close)
		mapping := "opmodel.dev=" + reg.Host() + "+insecure," + prefix + "=" + reg.Host() + "+insecure"
		t.Setenv("CUE_REGISTRY", mapping)
		t.Setenv("CUE_CACHE_DIR", schematest.IsolatedCacheDir(t))
		return kernel.New(kernel.WithRegistry(mapping))
	}
	reg, err := modregistrytest.New(m, "")
	require.NoError(t, err)
	t.Cleanup(reg.Close)
	mapping := prefix + "=" + reg.Host() + "+insecure,registry.cue.works"
	t.Setenv("CUE_REGISTRY", "opmodel.dev=ghcr.io/open-platform-model,"+mapping)
	t.Setenv("CUE_CACHE_DIR", schematest.PrivateCacheDir(t))
	return kernel.New(kernel.WithRegistry("opmodel.dev=ghcr.io/open-platform-model," + mapping))
}

func TestExp08(t *testing.T) {
	cases := []struct {
		core       bool
		plat, inst string
	}{
		{false, "lplat_both", "inst_app_lin0"},
		{true, "lplat_both", "inst_app_lin0"},
		{true, "lplat_both", "inst_app_lin1"},
		{true, "lplat_v1only", "inst_app_lin0"},
		{true, "lplat_both", "inst_app_lin_split"},
		{true, "lplat_both", "inst_app_lin_mixed"},
	}
	for _, c := range cases {
		name := "stockcore"
		if c.core {
			name = "patchedcore"
		}
		t.Run(name+"/"+c.plat+"/"+c.inst, func(t *testing.T) {
			k := lineageKernel(t, c.core)
			dir := filepath.Join(schematest.LibraryRoot(t), "testdata", "lineage")
			p, err := k.AcquirePlatformFromDir(context.Background(), filepath.Join(dir, c.plat))
			if err != nil {
				t.Logf("ACQUIRE PLATFORM ERROR: %v", err)
				return
			}
			inv, ierr := p.Contracts()
			if ierr != nil {
				t.Logf("CONTRACTS ERROR: %v", ierr)
			} else {
				lineageDump(t, "inventory", inv)
			}
			inst, err := k.AcquireInstanceFromDir(context.Background(), filepath.Join(dir, c.inst))
			if err != nil {
				t.Logf("ACQUIRE INSTANCE ERROR: %v", err)
				return
			}
			built, res, rerr := k.RenderForTest(context.Background(), kernel.RenderInput{Instance: inst, Platform: p, RuntimeName: "rt"})
			if built.Exists() {
				g := built.LookupPath(cue.ParsePath("gate"))
				t.Logf("gate: %v / err %v", g, g.Err())
			}
			if rerr != nil {
				t.Logf("RENDER ERROR: %v", rerr)
				var re *kernel.RenderError
				if stderrors.As(rerr, &re) {
					lineageDump(t, "refusal diagnostics", re.Diagnostics)
				}
				return
			}
			lineageDump(t, "pairs", res.Diagnostics.Pairs)
			lineageDump(t, "unify", res.Diagnostics.Unify)
			for _, o := range res.Compiled {
				b, _ := o.Value.MarshalJSON()
				t.Logf("OBJ %s", b)
			}
		})
	}
}
