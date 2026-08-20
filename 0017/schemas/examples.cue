// Concrete example instances for the target.cue delta — the test.
//
// Exercises the CHANGED definition (#Component's D5 optionality-aware
// projection) against the MIRROR #Trait replica: unset → absent, set →
// enforced and author wins, `optional: false` → present/required, plus the
// D1/D3 layering step a blueprint-style field-level default adds on top of
// the projection (default resolves when the author is silent, author's
// concrete value eliminates the marked arm). Hidden `_assert*` fields pin
// each derivable outcome so a behavior change breaks `cue vet ./...`.
// Must-fail cases are commented out with the observed error text.
package schema

// An optional trait (advisory posture, 0010 D46): bounds-only union spec,
// no defaults (contracts/#LayerContract L1).
_updateStrategyTrait: #Trait & {
	metadata: #definitionName: "UpdateStrategy"
	optional: true
	spec: updateStrategy: {
		type: "RollingUpdate" | "Recreate" | "OnDelete"
		rollingUpdate?: {
			maxUnavailable?: uint | string
			maxSurge?:       uint | string
			partition?:      uint
		}
	}
}

// A demanded trait (`optional: false`): its field stays required on the
// component, exactly as today's unconditional embedding behaves.
_restartPolicyTrait: #Trait & {
	metadata: #definitionName: "RestartPolicy"
	optional: false
	spec: restartPolicy: "Always" | "OnFailure" | "Never"
}

/////////////////////////////////////////////////////////////////
// Case 1 — optional trait, author silent: the field is projected `?`,
// so it is genuinely absent (this is what arms transformer fallbacks).
/////////////////////////////////////////////////////////////////

exampleSilent: #Component & {
	#traits: updateStrategy: _updateStrategyTrait
}

// Absent means zero regular fields in the composed spec — under today's
// unconditional embedding this would be 1.
_assertSilentAbsent: len(exampleSilent.spec) & 0

/////////////////////////////////////////////////////////////////
// Case 2 — optional trait, author sets a value: the schema is enforced
// and the field becomes present.
/////////////////////////////////////////////////////////////////

exampleSet: #Component & {
	#traits: updateStrategy: _updateStrategyTrait
	spec: updateStrategy: type: "Recreate"
}

_assertSetPresent: len(exampleSet.spec) & 1
_assertSetValue:   exampleSet.spec.updateStrategy.type & "Recreate"

/////////////////////////////////////////////////////////////////
// Case 3 — the layering on top of the projection (D1/D3): a
// blueprint-style field-level default conjoined onto the composed field.
// Author silent → the marked default resolves; author concrete → wins.
/////////////////////////////////////////////////////////////////

exampleBlueprintDefault: #Component & {
	#traits: updateStrategy: _updateStrategyTrait
	// What a stateless blueprint conjoins (contracts/
	// #StatelessUpdateStrategyNarrowing): Deployment submenu + one
	// field-level `*`.
	spec: updateStrategy: type: ("RollingUpdate" | "Recreate") & (*"RollingUpdate" | string)
}

// Interpolation forces default selection — pins that the blueprint's
// marked arm resolves when nobody else speaks for the field.
_assertBlueprintDefault: "\(exampleBlueprintDefault.spec.updateStrategy.type)" & "RollingUpdate"

exampleAuthorOverride: #Component & {
	#traits: updateStrategy: _updateStrategyTrait
	spec: updateStrategy: type: ("RollingUpdate" | "Recreate") & (*"RollingUpdate" | string)
	// The author's concrete value eliminates the marked arm (D1: instance
	// values / concrete data beat blueprint defaults).
	spec: updateStrategy: type: "Recreate"
}

_assertAuthorWins: "\(exampleAuthorOverride.spec.updateStrategy.type)" & "Recreate"

/////////////////////////////////////////////////////////////////
// Case 4 — demanded trait (`optional: false`): the field embeds as-is,
// so it is present (required) and the author must make it concrete.
/////////////////////////////////////////////////////////////////

exampleDemanded: #Component & {
	#traits: restartPolicy: _restartPolicyTrait
	spec: restartPolicy: "Always"
}

_assertDemandedPresent: len(exampleDemanded.spec) & 1
_assertDemandedValue:   exampleDemanded.spec.restartPolicy & "Always"

/////////////////////////////////////////////////////////////////
// Must-fail cases (commented; re-run by hand to reproduce).
/////////////////////////////////////////////////////////////////

// Typo still rejected by closedness — the optionalizing projection keeps
// `spec: close({_allFields})` closed:
//
//	exampleTypo: #Component & {
//		#traits: updateStrategy: _updateStrategyTrait
//		spec: updateStrategi: type: "Recreate"
//	}
//
// error (cue vet ./..., cue v0.17.1):
//	exampleTypo.spec.updateStrategi: field not allowed

// Kind-invalid value rejected by the blueprint-style narrowing:
//
//	exampleInvalid: #Component & {
//		#traits: updateStrategy: _updateStrategyTrait
//		spec: updateStrategy: type: ("RollingUpdate" | "Recreate") & (*"RollingUpdate" | string)
//		spec: updateStrategy: type: "OnDelete"
//	}
//
// error (cue vet ./..., cue v0.17.1):
//	exampleInvalid.spec.updateStrategy.type: 2 errors in empty disjunction:
//	exampleInvalid.spec.updateStrategy.type: conflicting values "Recreate" and "OnDelete"
//	exampleInvalid.spec.updateStrategy.type: conflicting values "RollingUpdate" and "OnDelete"

// Unstated posture fails loudly at the consumer (D5: today it would be
// silently required) — a trait that never states `optional`:
//
//	_silentPostureTrait: #Trait & {
//		metadata: #definitionName: "GracefulShutdown"
//		spec: gracefulShutdown: {seconds: uint}
//	}
//	examplePostureless: #Component & {
//		#traits: gracefulShutdown: _silentPostureTrait
//	}
//
// error (cue vet -c ./..., cue v0.17.1 — plain `cue vet ./...` reports only
// "some instances are incomplete; use the -c flag"):
//	incomplete bool: bool (target.cue, the `optional: bool` posture)
//	operand trait.optional of '!' not concrete (was bool) (target.cue, the projection's `!trait.optional` guard)
