// 04-rewrite-performance — measures the two candidate mechanisms for
// producing the resolved values (0013 D16 leaves the choice to
// implementation; this experiment prices it).
//
//	A  decode-encode  values.Decode into map[string]any, splice the marked
//	                  paths in Go, ctx.Encode a fresh cue.Value
//	                  (experiment 02's prototype mechanism)
//	B  prune-graft    walk only branches containing marked paths, FillPath
//	                  untouched subtrees wholesale onto an empty struct,
//	                  FillPath an encoded {ref, key} at each marked path
//
// Rider: the bake-style delivery seam additionally needs the resolved value
// as CUE source bytes (fill-style needs nothing) — that serialization is
// timed separately so the seam choice can be priced too.
//
// Fully offline: the rewrite operates on concrete data, so no schema, no
// registry, no kernel — only cuelang.org/go, pinned to the library's version.
// Correctness is cross-checked once per shape (both mechanisms must produce
// JSON-identical output) before anything is timed.
package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/format"
)

// ref is what the Resolve phase writes at a marked path.
func ref(i int) map[string]string {
	return map[string]string{"ref": "myapp-secrets", "key": fmt.Sprintf("key_%d", i)}
}

// shape describes one synthetic values tree.
type shape struct {
	name    string
	src     string   // concrete CUE source of the values tree
	marked  []string // dotted paths the rewrite must replace
	fields  int      // total leaf count (for the report)
}

// genWide builds `groups` structs of 10 scalar fields each, replacing
// `secrets` of them (spread evenly) with supplied-arm literals.
func genWide(name string, groups, secrets int) shape {
	var b strings.Builder
	var marked []string
	step := groups * 10 / secrets
	n := 0
	for g := 0; g < groups; g++ {
		fmt.Fprintf(&b, "g%d: {\n", g)
		for f := 0; f < 10; f++ {
			if secrets > 0 && n%step == 0 && len(marked) < secrets {
				fmt.Fprintf(&b, "\tf%d: {value: \"sec-%d\"}\n", f, n)
				marked = append(marked, fmt.Sprintf("g%d.f%d", g, f))
			} else {
				fmt.Fprintf(&b, "\tf%d: \"val-%d\"\n", f, n)
			}
			n++
		}
		b.WriteString("}\n")
	}
	return shape{name: name, src: b.String(), marked: marked, fields: groups * 10}
}

// genDeep nests `depth` levels, three scalar siblings per level, one secret
// at the bottom.
func genDeep(depth int) shape {
	var b strings.Builder
	var path []string
	for d := 0; d < depth; d++ {
		indent := strings.Repeat("\t", d)
		fmt.Fprintf(&b, "%sl%d: {\n", indent, d)
		for s := 0; s < 3; s++ {
			fmt.Fprintf(&b, "%s\ts%d: \"sib-%d-%d\"\n", indent, s, s, d)
		}
		path = append(path, fmt.Sprintf("l%d", d))
	}
	fmt.Fprintf(&b, "%stoken: {value: \"sec-deep\"}\n", strings.Repeat("\t", depth))
	path = append(path, "token")
	for d := depth - 1; d >= 0; d-- {
		fmt.Fprintf(&b, "%s}\n", strings.Repeat("\t", d))
	}
	return shape{name: fmt.Sprintf("deep-%dlvl", depth), src: b.String(), marked: []string{strings.Join(path, ".")}, fields: depth*3 + 1}
}

// ---------------------------------------------------------------- mechanism A

func setPath(m map[string]any, path []string, v any) {
	for _, seg := range path[:len(path)-1] {
		m = m[seg].(map[string]any)
	}
	m[path[len(path)-1]] = v
}

func decodeEncode(ctx *cue.Context, values cue.Value, marked []string) cue.Value {
	var data map[string]any
	if err := values.Decode(&data); err != nil {
		panic(err)
	}
	for i, p := range marked {
		setPath(data, strings.Split(p, "."), ref(i))
	}
	return ctx.Encode(data)
}

// ---------------------------------------------------------------- mechanism B

// markedSet holds every marked path and every strict prefix of one, so the
// walk knows whether to descend into a subtree or graft it wholesale.
type markedSet struct {
	exact  map[string]int  // dotted path -> secret index
	prefix map[string]bool // dotted strict prefixes
}

func newMarkedSet(marked []string) markedSet {
	s := markedSet{exact: map[string]int{}, prefix: map[string]bool{}}
	for i, p := range marked {
		s.exact[p] = i
		segs := strings.Split(p, ".")
		for j := 1; j < len(segs); j++ {
			s.prefix[strings.Join(segs[:j], ".")] = true
		}
	}
	return s
}

func pruneGraft(ctx *cue.Context, values cue.Value, set markedSet) cue.Value {
	dst := ctx.CompileString("{}")
	var walk func(v cue.Value, dotted string)
	walk = func(v cue.Value, dotted string) {
		it, err := v.Fields()
		if err != nil {
			panic(err)
		}
		for it.Next() {
			p := it.Selector().String()
			if dotted != "" {
				p = dotted + "." + p
			}
			switch {
			case hasExact(set, p):
				dst = dst.FillPath(cue.ParsePath(p), ctx.Encode(ref(set.exact[p])))
			case set.prefix[p]:
				walk(it.Value(), p) // a marked path lives below — descend
			default:
				dst = dst.FillPath(cue.ParsePath(p), it.Value()) // graft wholesale
			}
		}
	}
	walk(values, "")
	return dst
}

func hasExact(s markedSet, p string) bool { _, ok := s.exact[p]; return ok }

// ---------------------------------------------------------------- harness

// bench runs fn until 250ms have accumulated (min 10 iters), returns µs/op.
func bench(fn func()) float64 {
	fn() // warmup + laziness flush
	var iters int
	start := time.Now()
	for time.Since(start) < 250*time.Millisecond || iters < 10 {
		fn()
		iters++
	}
	return float64(time.Since(start).Microseconds()) / float64(iters)
}

func mustJSON(v cue.Value) string {
	b, err := v.MarshalJSON()
	if err != nil {
		panic(err)
	}
	return string(b)
}

func main() {
	ctx := cuecontext.New()

	shapes := []shape{
		genWide("small-20f-2s", 2, 2),
		genWide("medium-200f-5s", 20, 5),
		genWide("large-2000f-10s", 200, 10),
		genWide("large-2000f-1s", 200, 1),
		genDeep(12),
	}

	fmt.Printf("%-18s %7s %4s   %12s %12s %7s   %12s\n",
		"shape", "fields", "sec", "A decode µs", "B graft µs", "B/A", "serialize µs")

	for _, s := range shapes {
		values := ctx.CompileString(s.src)
		if err := values.Err(); err != nil {
			panic(fmt.Sprintf("%s: %v", s.name, err))
		}
		set := newMarkedSet(s.marked)

		// Correctness gate before timing: both mechanisms must agree.
		a := decodeEncode(ctx, values, s.marked)
		b := pruneGraft(ctx, values, set)
		if ja, jb := mustJSON(a), mustJSON(b); ja != jb {
			fmt.Fprintf(os.Stderr, "MECHANISM DISAGREEMENT on %s:\nA=%s\nB=%s\n", s.name, ja, jb)
			os.Exit(1)
		}
		if strings.Contains(mustJSON(b), "sec-") {
			fmt.Fprintf(os.Stderr, "PLAINTEXT SURVIVED on %s\n", s.name)
			os.Exit(1)
		}

		usA := bench(func() { _ = decodeEncode(ctx, values, s.marked) })
		usB := bench(func() { _ = pruneGraft(ctx, values, set) })

		// Rider: bake-style delivery cost — resolved value -> CUE source bytes.
		usSer := bench(func() {
			n := b.Syntax(cue.Final(), cue.Concrete(true))
			if _, err := format.Node(n); err != nil {
				panic(err)
			}
		})

		fmt.Printf("%-18s %7d %4d   %12.1f %12.1f %6.2fx   %12.1f\n",
			s.name, s.fields, len(s.marked), usA, usB, usB/usA, usSer)
	}
	fmt.Println("\ncorrectness: A and B JSON-identical on every shape; no plaintext in any output")
}
