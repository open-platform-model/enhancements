package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// Volumes Resource
/////////////////////////////////////////////////////////////////

#VolumesResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1beta1"
		name:           "volumes"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/volumes@v1beta1"
		description:    "A volume definition for workloads"
		labels: {
			"resource.opmodel.dev/category": "storage"
		}
	}

	spec: volumes: [volumeName=string]: #VolumeSchema & {name: string | *volumeName}
}

#Volumes: c.#Component & {
	#resources: (#VolumesResource.metadata.fqn): #VolumesResource
}

/////////////////////////////////////////////////////////////////
//// Volume Schemas
/////////////////////////////////////////////////////////////////

// Volume mount spec — defines container mount point. Referenced by #ContainerSchema.
#VolumeMountSchema: {
	#VolumeSchema

	mountPath!: string
	subPath?:   string
	readOnly:   bool

	// WHY: "HostToContainer" is required whenever a controller populates a hostPath
	// lazily: Istio's CNI agent mounts /host/var/run/netns to enter pod network
	// namespaces, and the container runtime bind-mounts those entries as pods
	// are created — i.e. after the agent is already running. Without
	// propagation the agent silently never sees pods created after it started,
	// which presents as a network fault rather than a config error.

	// How mounts created on the host after this container starts become
	// visible inside it. Kubernetes defaults to "None", which gives the
	// container a snapshot of the mount tree taken at start-up — anything the
	// host bind-mounts underneath the path later is invisible forever.
	// "Bidirectional" additionally propagates the container's own mounts back
	// to the host and requires a privileged container.
	mountPropagation?: "None" | "HostToContainer" | "Bidirectional"
}

#FileMode: int & >=0 & <=511

#SecretVolumeItemSchema: {
	key!:  string
	path!: string
	mode?: #FileMode
}

#SecretVolumeSourceSchema: {
	from!: #SecretSchema
	items?: [...#SecretVolumeItemSchema]
	defaultMode?: #FileMode
	optional?:    bool
}

/////////////////////////////////////////////////////////////////
//// External Object Volume Sources
////
//// `configMap`/`secret` above mount objects THIS module declares —
//// their rendered names are instance-scoped, and the volume ref
//// recomputes that name. The sources below mount objects the module
//// does NOT create, addressed by their exact cluster name: created at
//// runtime by a controller (e.g. istiod writes the `istio-ca-root-cert`
//// ConfigMap), or provisioned out-of-band (SOPS/bootstrap secrets).
/////////////////////////////////////////////////////////////////

// Reference to a cluster object this module does not own, mounted by its
// exact name (never instance-prefixed). `optional: true` lets the pod start
// before the object exists — required when a controller creates it lazily.
#ExternalObjectVolumeSourceSchema: {
	name!: string
	items?: [...#SecretVolumeItemSchema]
	defaultMode?: #FileMode
	optional?:    bool
}

/////////////////////////////////////////////////////////////////
//// Projected Volume Sources
/////////////////////////////////////////////////////////////////

// A short-lived, audience-bound ServiceAccount token. Distinct from the
// legacy auto-mounted SA token: the audience scopes the token to one
// verifier (e.g. "istio-ca") and the kubelet rotates it in place.
#ServiceAccountTokenProjectionSchema: {
	audience!: string
	// Kubernetes enforces a 10-minute floor.
	expirationSeconds?: int & >=600
	path!:              string
}

// One entry in a projected volume. Exactly one source kind must be set.
// Object references here are external/exact-name (same rationale as
// #ExternalObjectVolumeSourceSchema); per-source defaultMode is not a
// Kubernetes projection field — set it on the projected volume instead.
#ProjectedSourceSchema: {
	serviceAccountToken?: #ServiceAccountTokenProjectionSchema
	configMap?:           #ObjectProjectionSchema
	secret?:              #ObjectProjectionSchema

	matchN(1, [
		{serviceAccountToken!: _},
		{configMap!: _},
		{secret!: _},
	])
}

#ObjectProjectionSchema: {
	name!: string
	items?: [...#SecretVolumeItemSchema]
	optional?: bool
}

// Combines several sources into a single mounted directory.
// downwardAPI and clusterTrustBundle projections are deliberately omitted —
// no consumer needs them yet; add when one does.
#ProjectedVolumeSourceSchema: {
	sources!: [_, ...] & [...#ProjectedSourceSchema]
	defaultMode?: #FileMode
}

// Volume specification — defines storage source. Exactly one source must be set.
#VolumeSchema: {
	name!: string

	emptyDir?:        #EmptyDirSchema
	persistentClaim?: #PersistentClaimSchema
	configMap?:       #ConfigMapSchema
	secret?:          #SecretVolumeSourceSchema
	hostPath?:        #HostPathSchema
	nfs?:             #NFSVolumeSourceSchema

	// External (module doesn't own it) — mounted by exact name.
	configMapRef?: #ExternalObjectVolumeSourceSchema
	secretRef?:    #ExternalObjectVolumeSourceSchema

	projected?: #ProjectedVolumeSourceSchema

	matchN(1, [
		{emptyDir!: _},
		{persistentClaim!: _},
		{configMap!: _},
		{secret!: _},
		{hostPath!: _},
		{nfs!: _},
		{configMapRef!: _},
		{secretRef!: _},
		{projected!: _},
	])

	mountPath?: string
	subPath?:   string
	readOnly:   bool
}

#EmptyDirSchema: {
	medium?:    "node" | "memory"
	sizeLimit?: string
}

// Mounts a file or directory from the host node.
#HostPathSchema: {
	path!: string
	type?: "" | "DirectoryOrCreate" | "Directory" | "FileOrCreate" | "File" | "Socket" | "CharDevice" | "BlockDevice"
}

// Mounts a directory from an NFS server.
#NFSVolumeSourceSchema: {
	server!:   string
	path!:     string
	readOnly?: bool
}

// To mount a CIFS/SMB share use a storageClass that matches a pre-installed
// SMB StorageClass (e.g. "smb") with accessMode: "ReadWriteMany". The
// StorageClass and credentials Secret must be pre-provisioned (see the
// smb.csi.k8s.io CSI driver).
#PersistentClaimSchema: {
	size:         string
	accessMode:   "ReadWriteOnce" | "ReadOnlyMany" | "ReadWriteMany"
	storageClass: string
}
