//go:build race

package main

// raceEnabled records whether this binary was built with the race detector, so
// a run states it rather than leaving the reader to remember which command
// produced the output. For S3 the detector is the instrument, not a precaution.
const raceEnabled = true

func raceWord() string { return "ON" }
