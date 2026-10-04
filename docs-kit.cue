// The enhancements section bundle (docs-kit docs/contracts.md C6, C21):
// every entry, live and archived, plus INDEX.md and GRAPH.md, published at
// opmodel.dev/enhancements/. A section is built from main only, as edge: it
// has no release and no docs revision. opm-docs builds it (task docs:bundle,
// task docs:bundle:check); docs.yml publishes it to
// ghcr.io/open-platform-model/docs/enhancements.
bundles: enhancements: {
	placement: {kind: "section", root: "/enhancements/"}
	sources: [{kind: "enhancements", description: "OPM's design record: every proposal, its decisions and its status."}]
}
