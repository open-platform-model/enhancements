//go:build !race

package main

const raceEnabled = false

func raceWord() string { return "off (run ./run.sh -race for the safety half)" }
