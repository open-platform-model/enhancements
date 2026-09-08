// Command capture records the two Go-side answers this experiment compares
// against.
//
//	go run . pairs   runs the REAL kernel (match only) against the same
//	                 fixtures the library flow test uses and prints the
//	                 MatchPlan's pairs as JSON — vendored to
//	                 ../expected/pairs.json, the claim-1 oracle.
//
//	go run . probe   builds the experiment's broken/missing/gate package
//	                 through the cue Go API and reports whether `diagnostics`
//	                 stays readable via LookupPath while the in-build
//	                 `resolvedGate` is failing — the claim-3 coexistence
//	                 question the CLI answers negatively.
//
// This command deliberately imports the library (see go.mod's replace): it is
// the RECORDER of kernel behaviour, not part of the experiment's claim. The
// vendored JSON is the moment-in-time record the CUE side is compared to; if
// the library later changes, the JSON stays what the kernel answered on
// 2026-08-19.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"

	loader "github.com/open-platform-model/library/opm/helper/loader/file"
	"github.com/open-platform-model/library/opm/kernel"
	"github.com/open-platform-model/library/opm/schema"
)

func main() {
	mode := "pairs"
	if len(os.Args) > 1 {
		mode = os.Args[1]
	}
	var err error
	switch mode {
	case "pairs":
		err = capturePairs()
	case "probe":
		err = probeGate()
	default:
		err = fmt.Errorf("unknown mode %q (want pairs or probe)", mode)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "capture:", err)
		os.Exit(1)
	}
}

func registry() string {
	if v := os.Getenv("CUE_REGISTRY"); v != "" {
		return v
	}
	return schema.PublicRegistry
}

type pair struct {
	Component   string `json:"component"`
	Transformer string `json:"transformer"`
}

// capturePairs mirrors library/opm/kernel/flow_integration_test.go's setup
// exactly (same fixture dirs, same instance skeleton, same debugValues fill)
// and dumps the MatchPlan's verdict surfaces.
func capturePairs() error {
	reg := registry()
	os.Setenv("CUE_REGISTRY", reg)

	root, err := workspaceRoot()
	if err != nil {
		return err
	}
	moduleDir := filepath.Join(root, "library", "testdata", "modules", "web_app")
	platformDir := filepath.Join(root, "library", "modules", "opm_platform")

	k := kernel.New()
	ctx := context.Background()

	modVal, err := k.LoadModulePackage(ctx, moduleDir, loader.LoadOptions{Registry: reg})
	if err != nil {
		return fmt.Errorf("loading module: %w", err)
	}
	mod, err := k.NewModuleFromValue(modVal)
	if err != nil {
		return fmt.Errorf("module from value: %w", err)
	}

	platVal, err := k.LoadPlatformPackage(ctx, platformDir, loader.LoadOptions{Registry: reg})
	if err != nil {
		return fmt.Errorf("loading platform: %w", err)
	}
	plat, err := k.NewPlatformFromValue(platVal)
	if err != nil {
		return fmt.Errorf("platform from value: %w", err)
	}
	mp, err := k.Materialize(ctx, plat)
	if err != nil {
		return fmt.Errorf("materialize: %w", err)
	}

	debugValues := modVal.LookupPath(schema.DebugValues)
	instanceSkeleton := k.CueContext().CompileString(`
kind: "ModuleInstance"
metadata: {
	name:      "web-app-demo"
	namespace: "default"
	uuid:      "11111111-2222-5333-8444-555555555555"
}
`, cue.Filename("instance.cue"))
	if instanceSkeleton.Err() != nil {
		return fmt.Errorf("instance skeleton: %w", instanceSkeleton.Err())
	}

	unifiedModule := modVal.FillPath(schema.Config, debugValues)
	if unifiedModule.Err() != nil {
		return fmt.Errorf("filling values: %w", unifiedModule.Err())
	}
	moduleComponents := unifiedModule.LookupPath(cue.ParsePath("#components"))

	instanceSpec := instanceSkeleton.
		FillPath(schema.Module, modVal).
		FillPath(schema.Values, debugValues).
		FillPath(schema.Components, moduleComponents)
	if instanceSpec.Err() != nil {
		return fmt.Errorf("instance spec: %w", instanceSpec.Err())
	}

	inst, err := k.ProcessModuleInstance(ctx, instanceSpec, *mod, debugValues)
	if err != nil {
		return fmt.Errorf("processing instance: %w", err)
	}

	plan, err := k.Match(ctx, kernel.MatchInput{ModuleInstance: inst, Platform: mp})
	if err != nil {
		return fmt.Errorf("match: %w", err)
	}

	var pairs []pair
	for _, p := range plan.MatchedPairs() {
		pairs = append(pairs, pair{Component: p.ComponentName, Transformer: p.TransformerFQN})
	}
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].Component != pairs[j].Component {
			return pairs[i].Component < pairs[j].Component
		}
		return pairs[i].Transformer < pairs[j].Transformer
	})

	out := map[string]any{
		"pairs":           pairs,
		"unmatched":       plan.Unmatched,
		"unresolved":      plan.Unresolved,
		"missing":         plan.Missing,
		"unhandledTraits": plan.UnhandledTraits,
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}

// probeGate builds broken/missing/gate through cue/load and reports which
// paths stay readable while resolvedGate is failing.
func probeGate() error {
	os.Setenv("CUE_REGISTRY", registry())

	expRoot, err := filepath.Abs("..")
	if err != nil {
		return err
	}
	insts := load.Instances([]string{"./broken/missing/gate"}, &load.Config{Dir: expRoot})
	if len(insts) != 1 {
		return fmt.Errorf("expected 1 instance, got %d", len(insts))
	}
	if insts[0].Err != nil {
		return fmt.Errorf("load: %w", insts[0].Err)
	}
	v := cuecontext.New().BuildInstance(insts[0])

	report := func(label string, val cue.Value) {
		switch {
		case val.Err() != nil:
			fmt.Printf("%-22s ERROR: %v\n", label, val.Err())
		case val.Validate(cue.Concrete(true)) != nil:
			fmt.Printf("%-22s readable, NOT concrete: %v\n", label, val.Validate(cue.Concrete(true)))
		default:
			b, _ := json.Marshal(val)
			s := string(b)
			if len(s) > 120 {
				s = s[:120] + "..."
			}
			fmt.Printf("%-22s readable, concrete: %s\n", label, s)
		}
	}

	fmt.Printf("value.Err() on built instance: %v\n", v.Err())
	report("resolvedGate:", v.LookupPath(cue.ParsePath("resolvedGate")))
	report("diagnostics:", v.LookupPath(cue.ParsePath("diagnostics")))
	report("diagnostics.missing:", v.LookupPath(cue.ParsePath("diagnostics.missing")))
	report("diagnostics.pairs:", v.LookupPath(cue.ParsePath("diagnostics.pairs")))
	return nil
}

// workspaceRoot walks up from cwd until it finds the workspace root (the
// directory containing library/).
func workspaceRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "library", "go.mod")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("workspace root with library/ not found above cwd")
		}
		dir = parent
	}
}
