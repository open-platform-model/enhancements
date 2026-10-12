// Both deps resolve to the frozen snapshots copied INSIDE this experiment
// (paths are relative to the module root, i.e. to module/). Nothing outside
// the experiment directory is read.
deps: {
	"opmodel.dev/core@v1": replaceWith: "../cue-deps/core"
	"example.com/frag@v1": replaceWith: "../cue-deps/frag"
}
