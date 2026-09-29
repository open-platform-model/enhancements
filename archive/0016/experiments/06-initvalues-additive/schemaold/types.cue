package core

import (
	"strings"
)

#LabelsAnnotationsType: [string]: string | int | bool | [string | int | bool]

// NameType: RFC 1123 DNS label — lowercase alphanumeric with hyphens, max 63 chars
#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

// SnakeNameType: snake_case name — lowercase alphanumeric with underscores.
// Same character budget as #NameType; differs only in the separator (`_`
// instead of `-`), making it a valid CUE identifier (and thus a usable CUE
// package name / registry-path leaf).
//
// This is #Module.metadata.name's type (enhancement 0010 D8): a module IS a
// CUE package, so its name has one spelling and that spelling is the one a
// package name admits. #Resource, #Trait and #Blueprint keep kebab-case
// #NameType — they are not packages, and their spec! keys are built from it.
#SnakeNameType: string & =~"^[a-z0-9]([a-z0-9_]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

// ModulePathType: an artifact's complete CUE module path, major suffix
// mandatory. What #Module and #Catalog declare.
// Example: "opmodel.dev/modules/postgres@v2", "opmodel.dev/catalogs/opm@v1"
//
// It is the same string cue.mod/module.cue's `module:` field, the registry
// coordinate and an `import` statement already agree on, so the registry
// address is recoverable by reading one field rather than recomposed from a
// prefix and a name (enhancement 0010 D1).
//
// Underscores are permitted in path segments because a CUE module's package
// name is inferred from its path leaf, and only #SnakeNameType leaves are
// valid CUE identifiers (see above) — and under D8 a module path *ends in*
// the module's own snake_case name, so every multi-word name carries one.
// Hyphens stay legal in non-leaf segments so an organisation such as
// github.com/open-platform-model remains expressible; only the leaf is
// constrained, and #Module.metadata constrains it rather than this regex.
//
// The suffix-free form this type carried before D1 is #PackagePathType.
#ModulePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$" & strings.MinRunes(1) & strings.MaxRunes(254)

// PackagePathType: the path a *primitive* declares — a package path inside a
// module, carrying no major suffix. #Resource, #Trait, #Blueprint and
// #ComponentTransformer carry this; #Module and #Catalog carry
// #ModulePathType. Also the type of a major-free registry path — see
// #ArtifactRef.registryPath.
// Example: "opmodel.dev/catalogs/opm/resources", "opmodel.dev/catalogs/opm/traits"
//
// This is #ModulePathType's regex from before enhancement 0010 D1, verbatim,
// so no primitive value shipped by any catalog changes. The major is inert on
// a primitive: a @vN module publishes vN.* tags, so a primitive carrying its
// catalog's build version already states its catalog's major. It is also not a
// path anyone writes — a consumer imports opmodel.dev/catalogs/opm/resources
// with no suffix and CUE resolves the major from cue.mod's deps.
#PackagePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*$" & strings.MinRunes(1) & strings.MaxRunes(254)

// MajorVersionType: the identity-bearing version component of a CUE module
// path — what #ArtifactRef.major reads off #ModulePathType.
// Example: "v1", "v0"
//
// Left deliberately untouched by enhancement 0010 D4. #APIVersionType below is
// its widened sibling, and the two are separate types because they type
// different things: this one names a MODULE major, which the registry assigns
// and an import statement carries; that one names a CONTRACT level, which a
// primitive's author assigns and no address ever carries. A module major has
// no alpha/beta rung to admit.
#MajorVersionType: string & =~"^v[0-9]+$"

// APIVersionType: a PRIMITIVE's contract level — the value its author moves
// when the primitive's shape breaks, independent of the catalog's module major
// and of the catalog's release SemVer (enhancement 0010 D4, D25).
// Example: "v1alpha1", "v1beta2", "v2"
//
// Admits the Kubernetes ladder — vNalphaM, vNbetaM, vN — and D34 keys the
// additive-only promise to the level, so the string states whether the
// contract behind it promises anything. Read that with #APIVersionGated below.
//
// #MajorVersionType is the narrower sibling; see its comment for why the two
// are not one type.
#APIVersionType: string & =~"^v[0-9]+((alpha|beta)[0-9]+)?$"

// APIVersionGated reports whether the additive-only promise binds at a given
// apiVersion (enhancement 0010 D34): false at alpha, which promises nothing
// and whose publish gate is off, true at beta and GA, which are gated in full.
// Usage: (#APIVersionGated & {apiVersion: "v1beta1"}).gated => true
//
// This is the ONLY place in `core` the ladder is interpreted rather than
// matched, and it introduces NO ordering: the level is read off one string and
// is never compared against another. Match stays exact-key equality.
//
// A catalog's RELEASE version ("1.0.0-alpha.2") and a contract's LEVEL
// ("v1beta1") are independent axes, and only the second is read here. Gating
// on the catalog's prerelease instead is the plausible bug — both mainline
// catalogs publish 1.0.0-alpha.* while carrying v1beta1 contracts, so the two
// spellings disagree on every primitive currently shipping.
#APIVersionGated: {
	apiVersion!: #APIVersionType
	gated:       !strings.Contains(apiVersion, "alpha")
}

// ArtifactRef splits a complete module path into the OCI repository its tags
// live under and the major it declares. This is the one place in the schema a
// module path is decomposed: every "compose an address from a prefix and a
// name" site collapses into reading registryPath (enhancement 0010 D1).
//
// A module path carries at most one "@", always terminal, so SplitN(2) is
// exact. CUE has no string slicing, so a LastIndex-plus-slice form is
// unavailable.
#ArtifactRef: {
	modulePath!: #ModulePathType

	_p: strings.SplitN(modulePath, "@", 2)

	// registryPath: the OCI repository. Tags hang off this, and it is the
	// major-free identity of the artifact's lineage. Typed #PackagePathType so
	// a value still carrying a major is refused by the type rather than
	// silently yielding a second address.
	registryPath: #PackagePathType & _p[0]

	// major: the identity-bearing version component, read rather than parsed.
	major: #MajorVersionType & _p[1]

	// importPath: what an `import` statement and a cue.mod dependency key
	// carry. modulePath verbatim — nothing is recombined.
	importPath: modulePath
}

// BundleFQNType: FQN for #Bundle — path/name:vN (major version)
// Example: "opmodel.dev/bundles/game-stack:v1"
#BundleFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?:v[0-9]+$"

// Semver 2.0
#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// ContractFQNType: what a module DEMANDS — path/name@vN, where vN is the
// primitive's own #APIVersionType (enhancement 0010 D4). The key a #Resource,
// #Trait and #Blueprint carries.
// Example: "opmodel.dev/catalogs/opm/traits/scaling@v1beta1"
// Example: "opmodel.dev/catalogs/opm/blueprints/stateless-workload@v1"
//
// A catalog release does not move this key; only a breaking change to the
// primitive's own shape does. That is what lets a contract declared in one
// catalog be fulfilled by a transformer in another on an independent release
// cadence — the failure D4 exists to fix, where `catalog_opm`'s transformerless
// `backup` contract could only be matched by a provider that happened to have
// compiled against the identical `catalog_opm` BUILD.
//
// The kind segment (/resources, /traits, /blueprints) is part of the authored
// value and is retained deliberately: a flat FQN would make primitive names
// globally unique across all four kinds within a catalog, and `catalog_opm`
// already ships a resource named `secrets`.
#ContractFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+((alpha|beta)[0-9]+)?$"

// ImplFQNType: what a platform EXECUTES — path/name@semver, the full SemVer of
// the build the definition shipped in (enhancement 0010 D4). The key a
// #ComponentTransformer carries. Unchanged from the form this type had under
// the name #FQNType before D4 split it, so no transformer value moves.
// Example: "opmodel.dev/catalogs/opm/transformers/deployment-transformer@1.0.0"
// Example: "github.com/myorg/transformers/network/expose@2.1.0-rc.1"
//
// The build stays in this key for the reason enhancement 0001 D5 first lifted
// it here: two builds of the same transformer at adjacent versions must occupy
// distinct keys so divergent definitions surface as structured errors at match
// time rather than silently colliding on a MAJOR bucket. It is also the
// provenance an operator upgrading a catalog needs — which bytes are running.
#ImplFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// FQNType: either form, for a consumer holding both. Exported for that, and
// deliberately unused inside `core`: every field and map key here names ONE
// role and takes that role's type, which is what keeps a wrong-form key
// inexpressible rather than merely unmatched.
//
//	#Resource / #Trait / #Blueprint  metadata.fqn         #ContractFQNType
//	#ComponentTransformer            metadata.fqn         #ImplFQNType
//	                                 required/optional*   #ContractFQNType  (it demands contracts)
//	#TransformerMap, #Catalog        map keys             #ImplFQNType
//	#Platform.#matchers              bucket keys          #ContractFQNType
//
// Before D4 split the type, all of those were one regex and the narrowing was
// free. It is stated here because the disjunction is the only thing in the
// file that would silently re-admit the other form.
//
// NOTE the deliberate visual collision with #ModulePathType, which also ends
// "@v1". It is safe because the two namespaces never meet in one field: a
// module path carries "@v1" as an ADDRESS a registry resolves, a contract FQN
// carries it as a KEY a matcher compares. What must stay distinguishable is a
// contract key from an implementation key, and "@v1" versus "@1.2.0" does that
// at a glance and in the type.
#FQNType: #ContractFQNType | #ImplFQNType

// UUIDType: RFC 4122 UUID in standard format (lowercase hex)
#UUIDType: string & =~"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

// OPM namespace UUID for uuid computations via uuid.SHA1 (UUID v5).
// This UUID MUST remain immutable across all versions — it is the root namespace
// for all OPM uuid generation. The CLI uses the same constant.
OPMNamespace: "11bc6112-a6e8-4021-bec9-b3ad246f9466"

// KebabToPascal converts a kebab-case string to PascalCase.
// Usage: (#KebabToPascal & {"in": "stateless-workload"}).out => "StatelessWorkload"
#KebabToPascal: {
	X="in": string
	let _parts = strings.Split(X, "-")
	out: strings.Join([for p in _parts {
		let _runes = strings.Runes(p)
		strings.ToUpper(strings.SliceRunes(p, 0, 1)) + strings.SliceRunes(p, 1, len(_runes))
	}], "")
}

// KebabToCamel converts a kebab-case string to camelCase.
// Usage: (#KebabToCamel & {"in": "k8up-backup"}).out => "k8upBackup"
// The first segment stays lowercase; every subsequent segment is capitalized.
#KebabToCamel: {
	X="in": string
	let _parts = strings.Split(X, "-")
	out: strings.Join([for i, p in _parts {
		if i == 0 {p}
		if i > 0 {
			let _runes = strings.Runes(p)
			strings.ToUpper(strings.SliceRunes(p, 0, 1)) + strings.SliceRunes(p, 1, len(_runes))
		}
	}], "")
}
