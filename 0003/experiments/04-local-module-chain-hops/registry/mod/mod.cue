package mod

import c "testing.opmodel.dev/exp0003h/cat@v1"

Origin: "REGISTRY"

// Re-export which cat THIS module resolved against. This is the whole point:
// it reports the inner hop from inside the outer one.
CatOrigin: c.Origin
