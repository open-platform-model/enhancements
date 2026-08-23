// VARIANT A — identity supplied by @tag(). Committed and visible, which is
// the property we want; the question is whether the VALUE arrives correctly.
package cat

ModulePath: string | *"example.com/UNSET-CATALOG@v1" @tag(modulePath)
Version:    string | *"0.0.0-unset"                  @tag(version)

// What a primitive in this catalog would compute from it.
resourceFQN: ModulePath + "/resources/config-maps"
