package identity

ModulePath: "testing.opmodel.dev/exp0003/cat_a"

// Method A: the committed tree carries the dev sentinel. A concrete version
// reaches the artifact only via a publish-time version_override.cue written
// into a temp build dir (enhancement 0001 D9/D19).
Version: string | *"0.0.0-dev"
