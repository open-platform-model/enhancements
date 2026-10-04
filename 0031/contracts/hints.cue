// The field-hint vocabulary of D4, as data.
//
// Kind of contract: a closed, versioned taxonomy. A hint is a CUE field
// attribute, `@opm(ui, key=value, ...)`, read by tooling and never unified,
// so the vocabulary is not core schema: no opmodel.dev/core definition
// carries it. This file is the source of truth for vocabulary version 1;
// the publish gate and every reader implement it.
//
// What the file states, per key: the value form, the field shapes it may
// sit on, and what the gate checks. What it cannot state: which field a
// hint sits on (that is the module's #config), and the warn-not-refuse
// scope for inherited hints (that is D4:R4, a rule on who wrote the hint).
package contracts

// The version a hint targets when it states no `v=`.
#DefaultVocabularyVersion: 1

// Meta keys: allowed on every hint at every vocabulary version, outside the
// vocabulary itself, so they are never "unknown" and never counted as one
// of a version's keys. `v` names the vocabulary version the hint targets
// (D4); a gate that does not know that version warns and judges no keys.
metaKeys: [string]: #Key
metaKeys: v: {form: "int", appliesTo: ["any"], min: 1}

// The value forms a key may take. A flag is written bare (`advanced`),
// never `advanced=true`: experiment 01 measured that the two spellings read
// differently through CUE's attribute accessors.
#ValueForm: "flag" | "string" | "int" | "enum" | "fieldName"

// The field shapes a key may sit on and a widget is allowed for, named
// after the consumer schema a served kind would carry. One list for both
// `appliesTo` and `widgetsFor`. `any` matches every shape;
// `optionalOrDefaulted` is a presence condition, not a type, and is used
// only in `appliesTo`. `quantity` is an int-or-string field.
#FieldShape: "any" | "optionalOrDefaulted" | "string" | "stringEnum" | "integer" | "number" | "boolean" | "quantity" | "object" | "map" | "preserveUnknown" | "structUnion"

#Key: {
	form!: #ValueForm
	appliesTo!: [...#FieldShape]
	// A string or an int carries a bound; an enum carries its values.
	maxRunes?: int & >0
	min?:      int
	max?:      int
	values?: [...string]
}

// Vocabulary version 1: nine keys. A key absent here and from metaKeys is
// unknown at version 1 and refused on a module's own field.
vocabulary: v1: [string]: #Key
vocabulary: v1: {
	title: {form: "string", appliesTo: ["any"], maxRunes: 64}
	group: {form: "string", appliesTo: ["any"], maxRunes: 32}
	order: {form: "int", appliesTo: ["any"], min: 0, max: 999}
	widget: {
		form: "enum"
		appliesTo: ["any"]
		values: ["text", "textarea", "number", "toggle", "select", "quantity", "duration", "url", "hostname", "image", "code", "keyvalue"]
	}
	advanced: {form: "flag", appliesTo: ["optionalOrDefaulted"]}
	hidden: {form: "flag", appliesTo: ["optionalOrDefaulted"]}
	placeholder: {form: "string", appliesTo: ["string", "integer", "number", "quantity"], maxRunes: 64}
	// Name sources only: the UI suggests names the user can list. Choices
	// that are values come from the field's own disjunction, never from
	// this key.
	options: {
		form: "enum"
		appliesTo: ["string"]
		values: ["storageClass", "ingressClass", "secret", "configMap", "serviceAccount", "priorityClass"]
	}
	discriminator: {form: "fieldName", appliesTo: ["structUnion"]}
}

// Names that are deliberately not keys, with the reason a reader gives
// when it meets one. They are refused like any unknown key.
notKeys: [string]: string
notKeys: {
	visibleWhen: "a UI-only condition is a rule CUE does not enforce; write a discriminated union"
	dependsOn:   "a UI-only condition is a rule CUE does not enforce; write a discriminated union"
	sensitive:   "a secret is core's tagged #Secret type, never a hint"
	description: "help text is the field's doc comment"
	default:     "a hint never states a constraint; CUE does"
	required:    "a hint never states a constraint; CUE does"
	readOnly:    "a concrete or computed field is already not settable"
}

// The widget a field shape allows. The gate refuses a widget outside its
// shape's list on a module's own field.
widgetsFor: close({[#FieldShape]: [...or(vocabulary.v1.widget.values)]})
widgetsFor: {
	string: ["text", "textarea", "url", "hostname", "code", "select"]
	stringEnum: ["select"]
	integer: ["number"]
	number: ["number"]
	boolean: ["toggle"]
	quantity: ["quantity", "text", "duration"]
	object: ["image"]
	map: ["keyvalue"]
	preserveUnknown: ["code"]
}

// Attribute forms the gate refuses on a module's own field, beyond unknown
// keys and malformed values. Each one was measured to parse without a CUE
// error and lose meaning silently (experiment 01, E2c).
gateRefusals: [
	"position 0 is not exactly `ui`, as in `@opm(ui title=x)`, which parses as one key named `ui title`",
	"the same key twice in one attribute; readers would see only the first",
	"two `@opm(ui, ...)` attributes on one field",
	"a flag key written with a value, as in `hidden=true` or `advanced=false`",
	"a value that is not an identifier and is not quoted",
	"`advanced` or `hidden` on a required field",
	"`select` on a field with neither an enum nor `options`",
	"`discriminator` naming a field absent from some arm or not distinct across arms",
]

// Assertions: compilation is the test.
_assertKeyCount: len(vocabulary.v1) & 9
_assertMetaDisjoint: [for k, _ in metaKeys if vocabulary.v1[k] != _|_ {k}] & []
_assertWidgetCount: len(vocabulary.v1.widget.values) & 12
_assertFlagsBare: [for k, v in vocabulary.v1 if v.form == "flag" {k}] & ["advanced", "hidden"]
