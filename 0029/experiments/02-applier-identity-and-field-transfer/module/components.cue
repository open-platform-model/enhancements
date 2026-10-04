package multi

import (
	bp "opmodel.dev/catalogs/opm/blueprints/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#components: {
	web: {
		bp.#StatelessWorkload
		tr.#Expose

		metadata: name: "web"

		spec: {
			statelessWorkload: {
				container: {
					name:  "podinfo"
					image: #config.image
					ports: http: {name: "http", targetPort: 9898}
					readinessProbe: httpGet: {path: "/readyz", port: 9898}
				}
				scaling: count: #config.replicas
				restartPolicy: "Always"
				updateStrategy: type: "RollingUpdate"
			}
			expose: {
				type: "ClusterIP"
				ports: http: {name: "http", targetPort: 9898}
			}
		}
	}

	"reader-sa": {
		res.#ServiceAccount
		metadata: name: "reader-sa"
		spec: serviceAccount: {name: #config.readerName, automountToken: false}
	}

	"reader-rbac": {
		res.#Role
		metadata: name: "reader-rbac"
		spec: role: {
			name:  #config.readerName
			scope: "cluster"
			rules: [{
				apiGroups: [""]
				resources: ["nodes"]
				verbs: ["get", "list"]
			}]
			subjects: [{name: #config.readerName, automountToken: false}]
		}
	}

	if #config.extra {
		extra: {
			res.#ConfigMaps
			metadata: name: "extra"
			spec: configMaps: "extra": data: {
				message: #config.message
				// note is present only when set: the field-removal probe for case 3c.
				if #config.note != "" {note: #config.note}
			}
		}
	}
}
