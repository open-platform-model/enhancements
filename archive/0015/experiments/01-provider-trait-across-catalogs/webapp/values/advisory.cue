// Case D: the module narrows the backup trait to optional. -f replaces
// debugValues wholesale, so every #config field is restated.
image: {repository: "docker.io/library/nginx", tag: "1.27", digest: ""}
backupAdvisory: true
