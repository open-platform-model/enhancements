package mod

import cat "enhancements.opmodel.dev/0003/exp06/b_committed/cat"

ModulePath: "example.com/real-module@v2" @opm(identity, owner=publish)

moduleSees:  ModulePath
catalogSees: cat.ModulePath
catalogFQN:  cat.resourceFQN
