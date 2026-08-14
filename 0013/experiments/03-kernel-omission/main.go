// 03-kernel-omission — the OQ2 measurement.
//
// Runs the real kernel (github.com/open-platform-model/library, pinned
// published v1.0.0-alpha.12 — no local replace) against a fixture module whose
// #config carries the narrowed two-arm #Secret, and measures whether the
// resolve-in-place rewrite (0013 D11) survives the real build path:
//
//	M1  baseline    file-loaded instance with raw values baked in builds and
//	                validates — statement A lives in the validate artifact
//	M2  negative    filling resolved {ref,key} ONTO the raw-baked package
//	                conflicts (case 3 of the disjunction demo, at kernel scale)
//	                — proving the rewrite must be omission, not override
//	M3  fill-style  values omitted at load (overlay), resolved values supplied
//	                as the ProcessModuleInstance parameter — the kernel's own
//	                production fill seam — builds clean and concrete
//	M4  bake-style  resolved values baked at load time via the loader's
//	                overlay entry point (BuildInstanceOverlayAt, the same
//	                mechanism synth.Instance uses) — builds clean and concrete
//	M5  absence     the render artifact's values subtree carries {ref,key}
//	                only: no .value field exists, and the plaintext string is
//	                absent from the exported subtree
//
// Requires CUE_REGISTRY mapping opmodel.dev to GHCR (reads only).
package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/load"

	loaderfile "github.com/open-platform-model/library/opm/helper/loader/file"
	"github.com/open-platform-model/library/opm/kernel"
	"github.com/open-platform-model/library/opm/module"
)

const (
	rawSecret      = "hunter2" // statement A's plaintext; must not reach the render artifact
	resolvedValues = `
values: {
	db: password: {ref: "myapp-secrets", key: "db_password"}
	tls: cert: {ref: "wildcard-cert", key: "tls.crt"}
}
`
	// emptyValues replaces values.cue when loading the render twin fill-style:
	// same package, no values statement.
	emptyValues = "package instance\n"
)

var failures int

func check(ok bool, label, detail string) {
	status := "PASS"
	if !ok {
		status = "FAIL"
		failures++
	}
	fmt.Printf("  [%s] %s — %s\n", status, label, detail)
}

func main() {
	ctx := context.Background()
	k := kernel.New() // schema + registry config from process CUE_REGISTRY

	fixtureRoot, err := filepath.Abs("fixture")
	must(err, "resolving fixture root")
	valuesPath := filepath.Join(fixtureRoot, "instance", "values.cue")

	// --- Load the module and the raw-baked instance package (the file door).
	modVal, err := k.LoadModulePackage(ctx, filepath.Join(fixtureRoot, "secretmod"), loaderfile.LoadOptions{})
	must(err, "loading module package")
	mod, err := k.NewModuleFromValue(modVal)
	must(err, "decoding module")

	rawSpec, err := k.LoadInstancePackage(ctx, filepath.Join(fixtureRoot, "instance"), loaderfile.LoadOptions{})
	must(err, "loading raw instance package")

	// ---------------------------------------------------------------- M1
	fmt.Println("M1 — baseline: raw-baked instance builds; Validate accepts statement A")
	instRaw, err := k.ProcessModuleInstance(ctx, rawSpec, *mod, cue.Value{})
	check(err == nil, "ProcessModuleInstance(raw baked)", errString(err))
	if instRaw != nil {
		rawVals := instRaw.Package.LookupPath(cue.ParsePath("values"))
		vErr := k.Validate(ctx, kernel.ValidateInput{Module: mod, ModuleInstance: instRaw, Values: rawVals})
		check(vErr == nil, "Kernel.Validate(raw values)", errString(vErr))
		pw, _ := instRaw.Package.LookupPath(cue.ParsePath(`values.db.password.value`)).String()
		check(pw == rawSecret, "raw artifact carries the literal arm", fmt.Sprintf("values.db.password.value=%q", pw))
	}

	// Resolved values as a cue.Value (what the Resolve phase would hand over).
	resolved := k.CueContext().CompileString(resolvedValues).LookupPath(cue.ParsePath("values"))
	must(resolved.Err(), "compiling resolved values")

	// ---------------------------------------------------------------- M2
	fmt.Println("M2 — negative control: filling resolved arm OVER the raw-baked package must conflict")
	_, err = k.ProcessModuleInstance(ctx, rawSpec, *mod, resolved)
	check(err != nil, "ProcessModuleInstance(raw baked, resolved fill)", "err="+errString(err))
	if err != nil {
		check(strings.Contains(err.Error(), "not allowed") || strings.Contains(err.Error(), "conflict") || strings.Contains(err.Error(), "disjunction"),
			"failure is the closed-arm collision", firstLine(err.Error()))
	}

	// ---------------------------------------------------------------- M3
	fmt.Println("M3 — fill-style omission: values absent at load, resolved values via the kernel's own fill seam")
	overlayEmpty := map[string]load.Source{valuesPath: load.FromString(emptyValues)}
	noValSpec, err := loaderfile.BuildInstanceOverlayAt(k.CueContext(), fixtureRoot, "./instance", overlayEmpty, loaderfile.LoadOptions{})
	check(err == nil, "BuildInstanceOverlayAt(values omitted)", errString(err))
	var instFill *module.Instance
	if err == nil {
		instFill, err = k.ProcessModuleInstance(ctx, noValSpec, *mod, resolved)
		check(err == nil, "ProcessModuleInstance(no values, resolved fill)", errString(err))
	}
	assertRenderArtifact("M3", instFill)

	// ---------------------------------------------------------------- M4
	fmt.Println("M4 — bake-style omission: resolved values baked at load time via the loader overlay")
	overlayResolved := map[string]load.Source{valuesPath: load.FromString("package instance\n" + resolvedValues)}
	bakedSpec, err := loaderfile.BuildInstanceOverlayAt(k.CueContext(), fixtureRoot, "./instance", overlayResolved, loaderfile.LoadOptions{})
	check(err == nil, "BuildInstanceOverlayAt(resolved baked)", errString(err))
	var instBake *module.Instance
	if err == nil {
		instBake, err = k.ProcessModuleInstance(ctx, bakedSpec, *mod, cue.Value{})
		check(err == nil, "ProcessModuleInstance(resolved baked)", errString(err))
	}
	assertRenderArtifact("M4", instBake)

	// ---------------------------------------------------------------- summary
	fmt.Println()
	if failures > 0 {
		fmt.Printf("RESULT: %d assertion(s) failed\n", failures)
		os.Exit(1)
	}
	fmt.Println("RESULT: all assertions passed — clean omission holds on the real kernel path (both candidates)")
}

// assertRenderArtifact runs M5's absence checks against a render-twin instance.
func assertRenderArtifact(tag string, inst *module.Instance) {
	if inst == nil {
		check(false, tag+" render artifact", "instance is nil")
		return
	}
	ref, _ := inst.Package.LookupPath(cue.ParsePath(`values.db.password.ref`)).String()
	key, _ := inst.Package.LookupPath(cue.ParsePath(`values.db.password.key`)).String()
	check(ref == "myapp-secrets" && key == "db_password", tag+": literal arm resolved to ref",
		fmt.Sprintf("values.db.password={ref:%q key:%q}", ref, key))

	tref, _ := inst.Package.LookupPath(cue.ParsePath(`values.tls.cert.ref`)).String()
	check(tref == "wildcard-cert", tag+": deployer-written ref passes through", fmt.Sprintf("values.tls.cert.ref=%q", tref))

	leak := inst.Package.LookupPath(cue.ParsePath(`values.db.password.value`))
	check(!leak.Exists(), tag+": no .value field on the resolved secret", fmt.Sprintf("exists=%v", leak.Exists()))

	subtree := fmt.Sprintf("%v", inst.Package.LookupPath(cue.ParsePath("values")))
	check(!strings.Contains(subtree, rawSecret), tag+": plaintext absent from exported values subtree",
		fmt.Sprintf("contains(%q)=%v", rawSecret, strings.Contains(subtree, rawSecret)))
}

func must(err error, what string) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %s: %v\n", what, err)
		os.Exit(2)
	}
}

func errString(err error) string {
	if err == nil {
		return "no error"
	}
	return firstLine(err.Error())
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i] + " …"
	}
	return s
}
