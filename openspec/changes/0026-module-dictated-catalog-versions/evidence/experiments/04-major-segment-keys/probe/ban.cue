@if(!noban)

package core

// PATCH (design 1): no registry path may end in a major-shaped element, so a
// flat-keyed catalog at ".../opm/v5" can never produce opm@v5's keys. In the
// scratch core this was one extra conjunct on #ArtifactRef.registryPath in
// types.cue; it lives in its own file here so -t noban drops it.
#ArtifactRef: registryPath: !~"/v[0-9]+$"
