// Command main computes the publish DECISION for one artifact: derive the
// coordinates from what the artifact declares, run the gates, and either print
// a plan or refuse naming the offender. It never pushes anything.
//
// This is schemas/target.cue's #PublishPlan as executable code — the same
// fields, the same gates, the same "a plan that does not unify is a push that
// does not happen".
//
// It is a DEMONSTRATION, not production code. In particular it reads identity
// from the artifact's identity FILE rather than decoding the whole artifact
// through core; that is enough for every gate here, and the production command
// would decode the artifact as well.
//
// Identity fields are located by their SCHEMA-FIXED path — 0010 D22 dropped the
// @opm() marker and 0011 D8 fixes the lookup at the names #IdentityPackage and
// #Module define. There is nothing to search for.
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
)

func main() {
	kind := flag.String("kind", "catalog", `artifact kind: "catalog" or "module"`)
	version := flag.String("version", "", "supply or assert the version")
	allowLocal := flag.Bool("allow-local-override", false, "publish despite cue.mod/local-module.cue (modules only)")
	flag.Parse()
	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: publish [--kind=catalog|module] [--version=X.Y.Z] [--allow-local-override] <dir>")
		os.Exit(2)
	}
	dir := flag.Arg(0)

	p, refusals := plan(dir, *kind, *version, *allowLocal)
	printPlan(p, refusals)
	if len(refusals) > 0 {
		os.Exit(1)
	}
}

// ─── The plan ───────────────────────────────────────────────────────────────

type publishPlan struct {
	Kind         string
	DeclaredPath string // the artifact's own metadata.modulePath (D2: read, not composed)
	CueModPath   string // the module: line in cue.mod/module.cue
	RegistryRepo string // DeclaredPath before the "@"
	Major        string // DeclaredPath after the "@"
	Tag          string // what is pushed
	TagSource    string // where the tag came from
	Identity     []identityField
	LocalPresent bool
}

type identityField struct {
	Name  string
	Role  string
	State string // "concrete" | "open" | "absent"
	Value string
	Pos   string
}

func plan(dir, kind, versionFlag string, allowLocal bool) (publishPlan, []string) {
	var refusals []string
	refuse := func(format string, a ...any) { refusals = append(refusals, fmt.Sprintf(format, a...)) }

	p := publishPlan{Kind: kind}

	// The identity package differs by kind — a module writes metadata directly
	// in its root package, a catalog keeps identity/ as a subpackage its leaves
	// import (0010 D5, forced by package topology).
	idDir := "."
	if kind == "catalog" {
		idDir = "./identity"
	}
	identity, loadErr := readIdentity(dir, idDir, kind)
	p.Identity = identity
	if loadErr != "" {
		// Surfaced rather than swallowed: an artifact that will not load has no
		// readable identity, and reporting that as "absent" would blame the
		// wrong thing.
		refuse("the artifact does not load, so its identity cannot be read: %s", loadErr)
	}

	// ── coordinate derivation: read, never compose ──
	for _, f := range p.Identity {
		if f.Role == "modulePath" && f.State == "concrete" {
			p.DeclaredPath = f.Value
		}
	}
	if p.DeclaredPath == "" {
		refuse("the artifact declares no concrete module path; there is nothing to derive a coordinate from")
	} else if before, after, ok := strings.Cut(p.DeclaredPath, "@"); ok {
		p.RegistryRepo, p.Major = before, after
	}

	// ── gate: the artifact and its cue.mod must agree ──
	p.CueModPath = cueModPath(dir)
	if p.DeclaredPath != "" && p.CueModPath != p.DeclaredPath {
		refuse("cue.mod/module.cue declares %q but the artifact's identity declares %q", p.CueModPath, p.DeclaredPath)
	}

	// ── gate: identity completeness (D4) ──
	versionUnfilled := false
	for _, f := range p.Identity {
		switch f.State {
		case "absent":
			// D8: the schema names the field, so a field that is not at its
			// schema-fixed path is a malformed artifact rather than a field to
			// go looking for under another name.
			refuse("identity field %s is not declared at its schema-fixed path — malformed artifact", f.Name)
			if f.Role == "version" {
				versionUnfilled = true // the tag rule would only say it again
			}
		case "open":
			if f.Role == "version" {
				if versionFlag != "" {
					continue // --version fills it (D3)
				}
				versionUnfilled = true
			}
			refuse("identity field %s is declared but unfilled (%s) — publish does not invent a value", f.Name, f.Pos)
		}
	}

	// ── the tag: from the artifact, or from --version, never invented ──
	var declaredVersion string
	for _, f := range p.Identity {
		if f.Role == "version" && f.State == "concrete" {
			declaredVersion = f.Value
		}
	}
	switch {
	case declaredVersion != "" && versionFlag != "" && declaredVersion != versionFlag:
		refuse("--version %s disagrees with the version the artifact declares (%s); publish asserts, it does not overwrite", versionFlag, declaredVersion)
	case declaredVersion != "":
		p.Tag, p.TagSource = "v"+declaredVersion, "the artifact's own Version"
	case versionFlag != "":
		p.Tag, p.TagSource = "v"+versionFlag, "--version"
	case versionUnfilled:
		// already refused above; do not say it twice
	default:
		if kind == "module" {
			refuse("a module declares no version in source (0010 D2), so --version is required")
		} else {
			refuse("no version available from the artifact or from --version")
		}
	}

	// ── gate: the tag's major must match the path's (CUE enforces this too) ──
	if p.Tag != "" && p.Major != "" {
		tagMajor := "v" + strings.SplitN(strings.TrimPrefix(p.Tag, "v"), ".", 2)[0]
		if tagMajor != p.Major {
			refuse("tag %s is %s but the artifact path declares %s", p.Tag, tagMajor, p.Major)
		}
	}

	// ── gate: local-module.cue (D6) ──
	p.LocalPresent = fileExists(filepath.Join(dir, "cue.mod", "local-module.cue"))
	if p.LocalPresent {
		switch {
		case kind == "catalog":
			refuse("cue.mod/local-module.cue is present; a catalog cannot be published from a tree configured for local development, and no flag overrides this")
		case !allowLocal:
			refuse("cue.mod/local-module.cue is present; pass --allow-local-override to publish anyway")
		}
	}

	return p, refusals
}

// ─── Reading identity ───────────────────────────────────────────────────────

// identitySpecs is where each field the publisher writes lives, per artifact
// kind. This IS the lookup: 0010 D22 drops the @opm() marker, so there is no
// attribute to scan for and no `role` to read off one — the role is what the
// schema calls the field, and the path is where the schema puts it. A tree
// whose identity file disagrees with this table is a schema failure (D8),
// which is why `absent` is a refusal rather than a search widened.
func identitySpecs(kind string) []struct{ Role, Path string } {
	if kind == "module" {
		// 0010 D7: a module's identity file writes metadata directly, and D2
		// leaves it no version in source at all.
		return []struct{ Role, Path string }{{"modulePath", "metadata.modulePath"}}
	}
	// 0010 #IdentityPackage: two exported constants the catalog's leaves import.
	return []struct{ Role, Path string }{
		{"modulePath", "ModulePath"},
		{"version", "Version"},
	}
}

// readIdentity looks each expected field up by path and classifies it as
// concrete, open, or absent.
func readIdentity(dir, pkg, kind string) ([]identityField, string) {
	specs := identitySpecs(kind)

	ctx := cuecontext.New()
	insts := load.Instances([]string{pkg}, &load.Config{Dir: dir})
	var root cue.Value
	loadErr := ""
	switch {
	case len(insts) == 0:
		loadErr = "no CUE instance found"
	case insts[0].Err != nil:
		loadErr = insts[0].Err.Error()
	default:
		root = ctx.BuildInstance(insts[0])
		if root.Err() != nil {
			loadErr = root.Err().Error()
		}
	}

	out := make([]identityField, 0, len(specs))
	for _, sp := range specs {
		f := identityField{Name: sp.Path, Role: sp.Role, State: "absent"}
		if loadErr == "" {
			x := root.LookupPath(cue.ParsePath(sp.Path))
			if x.Exists() {
				f.State, f.Pos = "open", shorten(x.Pos().String())
				if s, err := x.String(); err == nil {
					f.State, f.Value = "concrete", s
				}
			}
		}
		out = append(out, f)
	}
	return out, loadErr
}

// cueModPath reads the `module:` line the way CUE itself would.
func cueModPath(dir string) string {
	b, err := os.ReadFile(filepath.Join(dir, "cue.mod", "module.cue"))
	if err != nil {
		return "<unreadable>"
	}
	v := cuecontext.New().CompileBytes(b)
	s, err := v.LookupPath(cue.ParsePath("module")).String()
	if err != nil {
		return "<unreadable>"
	}
	return s
}

// ─── Output ─────────────────────────────────────────────────────────────────

func printPlan(p publishPlan, refusals []string) {
	fmt.Printf("  kind            %s\n", p.Kind)
	fmt.Printf("  declaredPath    %s\n", or(p.DeclaredPath, "—"))
	fmt.Printf("  cueModPath      %s\n", p.CueModPath)
	fmt.Printf("  registryRepo    %s\n", or(p.RegistryRepo, "—"))
	fmt.Printf("  major           %s\n", or(p.Major, "—"))
	fmt.Printf("  tag             %s\n", or(p.Tag, "—"))
	if p.TagSource != "" {
		fmt.Printf("  tag from        %s\n", p.TagSource)
	}
	for _, f := range p.Identity {
		v := f.Value
		if v != "" {
			v = " = " + v
		}
		fmt.Printf("  identity        %-14s %-8s role=%s%s\n", f.Name, f.State, f.Role, v)
	}
	fmt.Printf("  local override  %v\n", p.LocalPresent)

	if len(refusals) == 0 {
		fmt.Printf("\n  \033[1mGO\033[0m — would push %s:%s\n", p.RegistryRepo, p.Tag)
		return
	}
	fmt.Printf("\n  \033[1mREFUSED\033[0m\n")
	for _, r := range refusals {
		fmt.Printf("    - %s\n", r)
	}
}

func or(s, alt string) string {
	if s == "" {
		return alt
	}
	return s
}

func fileExists(p string) bool { _, err := os.Stat(p); return err == nil }

func shorten(s string) string {
	if i := strings.Index(s, "variants/"); i >= 0 {
		return s[i:]
	}
	return s
}
