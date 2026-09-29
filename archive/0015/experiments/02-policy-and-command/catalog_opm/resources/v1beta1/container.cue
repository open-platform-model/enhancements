package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	"strings"

	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// Container Resource
/////////////////////////////////////////////////////////////////

#ContainerResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1beta1"
		name:           "container"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/container@v1beta1"
		description:    "A container definition for workloads"
		labels: {
			"resource.opmodel.dev/category": "workload"
		}
	}

	// The matching key this catalog introduces (0010 D36). Required, so a
	// component must answer it — typically by attaching a workload blueprint.
	matchLabels: "core.opmodel.dev/workload-type"!: "stateless" | "stateful" | "daemon" | "task" | "scheduled-task"

	spec: container: #ContainerSchema
}

#Container: c.#Component & {
	metadata: labels: {
		"core.opmodel.dev/workload-type"!: "stateless" | "stateful" | "daemon" | "task" | "scheduled-task"
	}

	// WHY: Computed HERE, on the wrapper, from the component's derived matchLabels
	// rather than on #ContainerResource from the entry's own key. Measured on
	// cue v0.17.1: on the blueprint path the key is answered by the blueprint
	// and never on the container entry, so an entry-level conditional stays
	// unresolved, and an unresolved slot in the component's conjunction
	// defers EVERY validator in it (the regex bounds still fire, the
	// strings.MaxRunes calls do not): a 64-rune override on a stateful
	// workload, and on Expose beside it, was admitted silently. A `!= _|_ &&`
	// guard does not help, because `a && b` with an unresolved b does not
	// short-circuit. The derived matchLabels is concrete on every path where
	// a key is answered, so the conditional always resolves; where nothing
	// answers, the component already fails its required key.
	// List-index form is load-bearing: a
	// default arm would win over the concrete one.

	// The name constraint the container puts on the owning component's
	// metadata.resourceName (0019 D23), computed from the workload-type key:
	// a stateful workload's pods are addressed as <sts>-<n>.<svc>..., which
	// puts the name in a DNS label position, and the API server enforces the
	// label rule on both axes there (no dots, 63 runes). Top otherwise. `matchLabels`
	// is re-declared for lexical scope. See docs/name-constraints.md.
	matchLabels: _
	#resources: (#ContainerResource.metadata.fqn): #ContainerResource & {
		#nameConstraint: [
			if matchLabels["core.opmodel.dev/workload-type"] == "stateful" {c.#NameType},
			_,
		][0]
	}
}

/////////////////////////////////////////////////////////////////
//// Container Schemas
/////////////////////////////////////////////////////////////////

// Container specification
#ContainerSchema: {
	// Name of the container
	name!: string

	// Container image (e.g., "nginx:latest")
	image!: #Image

	// Ports exposed by the container
	ports?: [portName=string]: #PortSchema & {name: portName}

	// Environment variables for the container
	env?: [envName=string]: #EnvVarSchema & {name: envName}

	// Bulk injection of all keys from ConfigMaps/Secrets as env vars
	envFrom?: [...#EnvFromSource]

	// Command to run in the container
	command?: [...string]

	// Arguments to pass to the command
	args?: [...string]

	// Resource requirements for the container
	resources?: #ResourceRequirementsSchema

	// Volume mounts for the container
	volumeMounts?: [string]: #VolumeMountSchema

	// Probes for health checking. See #ProbeSchema for K8s init container constraints.
	livenessProbe?:  #ProbeSchema
	readinessProbe?: #ProbeSchema
	startupProbe?:   #ProbeSchema

	// Container-level security context. Pod-level constraints (fsGroup,
	// supplementalGroups) belong on the component spec.securityContext field.
	securityContext?: #SecurityContextSchema

	// Pre-stop lifecycle hook command (runs before SIGTERM)
	preStopCommand?: [...string]
}

// Image specification for container images. Borrowed from timoni's #Image.
#Image: {
	repository!: string
	tag!:        string & strings.MaxRunes(128)
	digest!:     string
	pullPolicy:  *"IfNotPresent" | "Always" | "Never"
	reference:   string

	if digest != "" && tag != "" {
		reference: "\(repository):\(tag)@\(digest)"
	}
	if digest != "" && tag == "" {
		reference: "\(repository)@\(digest)"
	}
	if digest == "" && tag != "" {
		reference: "\(repository):\(tag)"
	}
	if digest == "" && tag == "" {
		reference: "\(repository):latest"
	}
}

// Environment variable. Exactly one of value/fieldRef/resourceFieldRef must be set.
#EnvVarSchema: {
	name!: string

	value?:            string
	fieldRef?:         #FieldRefSchema
	resourceFieldRef?: #ResourceFieldRefSchema
}

// Downward API field reference.
#FieldRefSchema: {
	fieldPath!:  string
	apiVersion?: string
}

// Container resource field reference.
#ResourceFieldRefSchema: {
	resource!:      string
	containerName?: string
	divisor?:       string
}

// Bulk injection source — inject all keys from a ConfigMap or Secret as env vars.
#EnvFromSource: {
	secretRef?: {name!: string}
	configMapRef?: {name!: string}
	prefix?: string
}

// GPU extended resource claim.
#GpuResourceSchema: {
	resource: string
	count:    int & >=1
}

#ResourceRequirementsSchema: {
	requests?: {
		cpu?:    number | string & =~#"^([0-9]+(\.[0-9]+)?|[0-9]+m)$"#
		memory?: number | string & =~"^[0-9]+[MG]i$"
	}
	limits?: {
		cpu?:    number | string & =~#"^([0-9]+(\.[0-9]+)?|[0-9]+m)$"#
		memory?: number | string & =~"^[0-9]+[MG]i$"
	}

	// A single GPU claim. Kept exactly as-is: modules published against earlier
	// catalog versions set it (jellyfin v2.4.0), and a module's resource FQNs
	// embed the catalog version under exact-FQN transformer matching, so this
	// field cannot be renamed or folded into `gpus` without stranding them.
	gpu?: #GpuResourceSchema

	// WHY: Needed whenever one container must hold devices from two different device
	// plugins at once — a transcoder offered both `nvidia.com/gpu` and
	// `gpu.intel.com/i915`, picking per job which to drive. `gpu` cannot express
	// that (it is one struct), and neither can `limits`: this is a closed
	// definition, so an extended-resource key written there is rejected.

	// Several GPU claims, keyed by an arbitrary local name.
	// Both fields may be set together; every claim is emitted independently. Two
	// claims naming the same `resource` unify — equal counts collapse harmlessly,
	// unequal counts fail the build instead of silently resolving last-one-wins.
	gpus?: [Name=string]: #GpuResourceSchema
}

// Probe specification used by liveness/readiness/startup probes.
#ProbeSchema: {
	httpGet?: {
		path!: string
		port!: uint & >0 & <65536
	}
	exec?: {
		command!: [...string]
	}
	tcpSocket?: {
		port!: uint & >0 & <65536
	}
	initialDelaySeconds?: uint | *0
	periodSeconds?:       uint | *10
	timeoutSeconds?:      uint | *1
	successThreshold?:    uint | *1
	failureThreshold?:    uint | *3
}

/////////////////////////////////////////////////////////////////
//// Port Schemas (used by #ContainerSchema and #ExposeSchema)
/////////////////////////////////////////////////////////////////

// RFC 1123 IANA service name validator.
#IANA_SVC_NAME: string & strings.MinRunes(1) & strings.MaxRunes(15) & =~"^[a-z]([-a-z0-9]{0,13}[a-z0-9])?$"

#PortSchema: {
	name!:        #IANA_SVC_NAME
	targetPort!:  uint & >=1 & <=65535
	protocol:     *"TCP" | "UDP" | "SCTP"
	hostIP?:      string
	hostPort?:    uint & >=1 & <=65535
	exposedPort?: uint & >=1 & <=65535
}

/////////////////////////////////////////////////////////////////
//// Security Context Schema
//// Lives here because #ContainerSchema embeds it (per-container
//// securityContext). Pod-level securityContext via #SecurityContextTrait
//// in traits/security_context.cue references this schema.
/////////////////////////////////////////////////////////////////

#SecurityContextSchema: {
	privileged?:   bool
	runAsNonRoot?: bool
	runAsUser?:    int
	runAsGroup?:   int
	fsGroup?:      int
	supplementalGroups?: [...int]
	readOnlyRootFilesystem?:   bool
	allowPrivilegeEscalation?: bool
	capabilities?: {
		add?: [...string]
		drop?: [...string] | ["ALL"]
	}
}
