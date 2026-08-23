// The MODULE declares the same tag names — it has no way not to, since the
// tag name is part of the shared schema convention, not per-artifact.
package mod

import cat "enhancements.opmodel.dev/0003/exp06/a_tag/cat"

ModulePath: string | *"example.com/UNSET-MODULE@v2" @tag(modulePath)

// The module reports its own identity AND what it sees of the catalog's.
moduleSees:  ModulePath
catalogSees: cat.ModulePath
catalogFQN:  cat.resourceFQN
