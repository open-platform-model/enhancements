//go:build race

package main

// raceEnabled records whether this binary was built with the race detector, so
// a run states it rather than leaving the reader to remember which command
// produced the output. Experiment 06 used the detector as its instrument; here
// it is a check that size does not change 06's safety answer.
const raceEnabled = true

func raceWord() string { return "ON" }
