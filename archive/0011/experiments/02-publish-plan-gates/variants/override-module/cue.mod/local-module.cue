// A development-time override: this tree evaluates against a local checkout
// rather than the published module. CUE strips this file when publishing, so
// what a consumer resolves is NOT what the author validated against.
deps: "example.com/core@v1": replaceWith: "../../local/core"
