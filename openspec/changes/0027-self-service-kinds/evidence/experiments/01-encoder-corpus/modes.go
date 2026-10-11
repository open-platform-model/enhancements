package main

import "cuelang.org/go/encoding/jsonschema"

func jsModes() []jsMode { return []jsMode{{"js2020", &jsonschema.GenerateConfig{}}} }
