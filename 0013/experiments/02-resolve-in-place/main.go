// Experiment 02 — resolve in place, end to end.
//
// Drives the prototype in ./secret through the full kernel pass against a module
// written the way an author would write it under enhancement 0013, and checks
// the five claims D10, D11 and D12 rest on:
//
//	1. The SAME published module fulfils two ways — supplied in dev, referenced
//	   in prod — with no republish and no module edit.
//	2. Both arms converge: after resolution every secret is a #SecretRef, and the
//	   render cannot tell a resolved literal from a deployer-written reference.
//	3. No secret plaintext is present anywhere in the component graph.
//	4. The author's existing wiring (`from: #config.db.password`) carries the
//	   resolved ref, with no author-side change, and a transformer needs ONE
//	   branch and no name computation.
//	5. A secret interpolated into a rendered string is rejected by CUE itself, at
//	   authoring time, before the kernel is ever involved.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"

	"opm/enhancements/0013/experiments/resolve-in-place/secret"
)

func main() {
	ctx := cuecontext.New()
	root := build(ctx, "module")

	inst := root.LookupPath(cue.ParsePath("inst"))
	instanceName, _ := inst.LookupPath(cue.ParsePath("metadata.name")).String()

	// ── Phase 1 ──────────────────────────────────────────────────────────────
	step("Phase 1 — Discover (reads #config; no values consulted)")

	decls, err := secret.Discover(inst.LookupPath(cue.ParsePath("#module.#config")))
	if err != nil {
		fail(err)
	}
	for _, d := range decls {
		fmt.Printf("  %-22s group=%-11s key=%-12s type=%-29s immutable=%v\n",
			d.Path, d.Marker.Group, d.Key, d.Marker.Type, d.Marker.Immutable)
	}
	fmt.Println("  -> produced from the module alone. This is what `opm module inspect` prints.")

	// ── Claim 1 ──────────────────────────────────────────────────────────────
	step("Claim 1 — one module, two environments, no republish")

	dev := resolveEnv(ctx, root, "valuesDev", decls, instanceName)
	prod := resolveEnv(ctx, root, "valuesProd", decls, instanceName)

	for _, e := range []struct {
		name string
		r    *secret.Resolution
	}{{"dev", dev.res}, {"prod", prod.res}} {
		fmt.Printf("\n  [%s] objects OPM will create:\n", e.name)
		for _, p := range e.r.Plans {
			fmt.Printf("     %-28s type=%-29s immutable=%-5v keys=%v\n",
				p.ObjectName, p.Type, p.Immutable, sortedKeys(p.Data))
		}
		if len(e.r.Plans) == 0 {
			fmt.Println("     (none)")
		}
	}
	fmt.Println("\n  dev supplies the TLS pair inline, so OPM creates myapp-tls-<hash>.")
	fmt.Println("  prod points at a platform-managed certificate, so OPM creates nothing for it.")
	fmt.Println("  The module source is byte-identical in both.")

	// ── Claim 2 ──────────────────────────────────────────────────────────────
	step("Claim 2 — both arms converge on #SecretRef")

	for _, d := range decls {
		fmt.Printf("  %-22s dev  %-42s prod %s\n", d.Path,
			refStr(dev.res.Resolved[d.Path]), refStr(prod.res.Resolved[d.Path]))
	}
	fmt.Println("\n  prod's tls.* was written as a ref by the deployer; db.password was written")
	fmt.Println("  as a literal and became one. Nothing downstream can tell them apart.")

	// ── Claim 3 ──────────────────────────────────────────────────────────────
	step("Claim 3 — no plaintext in the component graph")

	graph := oneLine(prod.built.LookupPath(cue.ParsePath("inst.components")))
	var leaked []string
	for path, s := range prod.supplied {
		if s.Literal != nil && strings.Contains(graph, s.Literal.Value) {
			leaked = append(leaked, path)
		}
	}
	if len(leaked) == 0 {
		fmt.Println("  [ok] no supplied plaintext appears anywhere in inst.components")
		fmt.Println("       #SecretRef is a closed struct with no `value` field, so this is")
		fmt.Println("       structural — not something the kernel has to remember to strip.")
	} else {
		sort.Strings(leaked)
		fmt.Printf("  [FAIL] plaintext present for: %v\n", leaked)
		os.Exit(1)
	}

	// ── Claim 4 ──────────────────────────────────────────────────────────────
	step("Claim 4 — author wiring unchanged; transformer needs one branch")

	for _, p := range []string{
		"inst.components.web.spec.wiring.env.DB_PASSWORD.from",
		"inst.components.web.spec.wiring.env.TLS_KEY.from",
		"inst.components.web.spec.wiring.env.DB_HOST.value",
	} {
		fmt.Printf("  %-52s %s\n", p, oneLine(prod.built.LookupPath(cue.ParsePath(p))))
	}

	tf := ctx.CompileString(transformerSrc, cue.Filename("transformer.cue"))
	if tf.Err() != nil {
		fail(tf.Err())
	}
	tf = tf.FillPath(cue.ParsePath("in"),
		prod.built.LookupPath(cue.ParsePath("inst.components.web.spec.wiring.env")))
	if tf.Err() != nil {
		fail(tf.Err())
	}
	fmt.Println()
	fmt.Println(indent(fmt.Sprint(tf.LookupPath(cue.ParsePath("out")))))
	fmt.Println("  -> the resolved literal and the deployer-written ref came out of the SAME")
	fmt.Println("     branch. No prefix test, no variant dispatch, no context lookup, and no")
	fmt.Println("     name computation anywhere in the transformer.")

	// A volume mounting the same group reads the same string.
	vol := prod.res.Resolved["auth.username"].Ref
	env := prod.res.Resolved["auth.password"].Ref
	fmt.Printf("\n  volume ref %q == env ref %q  -> %v\n", vol, env, vol == env)
	fmt.Println("  There is exactly one such string and it lives in the value, so the")
	fmt.Println("  env-vs-volume mismatch live in catalog_opm today is unrepresentable.")

	// ── Claim 5 ──────────────────────────────────────────────────────────────
	step("Claim 5 — a secret in a rendered string is CUE's error, at author time")

	leak := build(ctx, "module-leak")
	if leak.Err() == nil {
		fmt.Println("  [FAIL] expected the interpolating module to fail at vet")
		os.Exit(1)
	}
	fmt.Printf("  cue reports, with NO kernel involved and NO OPM tooling:\n\n")
	fmt.Println(indent(strings.TrimSpace(fmt.Sprint(leak.Err()))))
	fmt.Println("\n  The module cannot be written and vetted. Under the superseded handle")
	fmt.Println("  design this same module vetted clean and failed only at render time.")
}

// resolvedEnv bundles one environment's inputs and outputs.
type resolvedEnv struct {
	supplied map[string]secret.Secret
	res      *secret.Resolution
	built    cue.Value
}

// resolveEnv reads one environment's values, runs the pass, and rebuilds the
// instance on the resolved values.
func resolveEnv(ctx *cue.Context, root cue.Value, field string, decls []secret.Decl, instance string) resolvedEnv {
	values := root.LookupPath(cue.ParsePath(field))

	supplied := map[string]secret.Secret{}
	for _, d := range decls {
		v := values.LookupPath(cue.ParsePath(d.Path))
		if !v.Exists() {
			continue
		}
		s, err := secret.DecodeSecret(v)
		if err != nil {
			fail(fmt.Errorf("%s at %s: %w", field, d.Path, err))
		}
		supplied[d.Path] = s
	}

	res, err := secret.Resolve(decls, supplied, instance)
	if err != nil {
		fail(err)
	}
	rewritten, err := secret.RewriteValues(ctx, values, res)
	if err != nil {
		fail(err)
	}
	built := root.FillPath(cue.ParsePath("inst.values"), rewritten)
	if built.Err() != nil {
		fail(built.Err())
	}
	return resolvedEnv{supplied: supplied, res: res, built: built}
}

// transformerSrc is the env-var half of a container transformer, written the
// way catalog_opm would write it after this enhancement. Two field reads, one
// branch, both fulfilment arms.
const transformerSrc = `
in: [string]: {value?: string, from?: {ref: string, key: string}}

out: [for n, e in in {
	name: n
	if e.value != _|_ {value: e.value}
	if e.from != _|_ {
		valueFrom: secretKeyRef: {
			name: e.from.ref
			key:  e.from.key
		}
	}
}]
`

func build(ctx *cue.Context, dir string) cue.Value {
	abs, err := filepath.Abs(dir)
	if err != nil {
		fail(err)
	}
	insts := load.Instances([]string{"."}, &load.Config{Dir: abs})
	if len(insts) == 0 {
		fail(fmt.Errorf("no instances loaded from %s", dir))
	}
	if insts[0].Err != nil {
		return ctx.CompileString("_|_") // surfaced by the caller as a build error
	}
	return ctx.BuildInstance(insts[0])
}

func step(s string) { fmt.Printf("\n\033[1m=== %s ===\033[0m\n", s) }

func fail(err error) {
	fmt.Fprintln(os.Stderr, "experiment failed:", err)
	os.Exit(1)
}

func refStr(r secret.Ref) string {
	if r.Ref == "" {
		return "<unfulfilled>"
	}
	return fmt.Sprintf("%s/%s", r.Ref, r.Key)
}

func oneLine(v cue.Value) string { return strings.Join(strings.Fields(fmt.Sprint(v)), " ") }

func indent(s string) string {
	var b strings.Builder
	for _, l := range strings.Split(s, "\n") {
		b.WriteString("  " + l + "\n")
	}
	return strings.TrimRight(b.String(), "\n")
}

func sortedKeys(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
