#!/usr/bin/env python3
"""06-module-file-card-roundtrip: copy the 20-module fleet, author a 0022 block with a listing card
(comments, free key order), add a generated SVG icon under assets/."""
import os, re, shutil, random, json, hashlib

W = os.environ["WS"]  # workspace checkout holding opm-modules/ and modules/
X = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(X, ".work", "fleet")

CAT = {
    "fileflows": ("media", ["transcoding", "automation", "ffmpeg"]),
    "intel_gpu_device_plugin": ("gpu", ["intel", "device-plugin", "i915"]),
    "intel_gpu_exporter": ("observability", ["intel", "gpu", "prometheus"]),
    "jellyfin": ("media", ["streaming", "media-server"]),
    "jellystat": ("media", ["statistics", "jellyfin", "postgresql"]),
    "jellyswarrm": ("media", ["jellyfin", "proxy"]),
    "nvidia_device_plugin": ("gpu", ["nvidia", "device-plugin", "cuda"]),
    "nvidia_gpu_exporter": ("observability", ["nvidia", "gpu", "prometheus"]),
    "radarr": ("media", ["pvr", "movies", "usenet", "bittorrent"]),
    "sabnzbd": ("media", ["usenet", "downloader"]),
    "seerr": ("media", ["requests", "jellyfin", "plex"]),
    "sonarr": ("media", ["pvr", "tv", "usenet", "bittorrent"]),
    "apprise": ("notifications", ["notifications", "webhooks"]),
    "cert_manager": ("security", ["tls", "certificates", "acme"]),
    "gotify": ("notifications", ["push", "websocket"]),
    "istio_ambient": ("networking", ["service-mesh", "mtls", "istio"]),
    "k8up": ("backup", ["restic", "backup", "operator"]),
    "metallb": ("networking", ["load-balancer", "bare-metal", "bgp"]),
    "ntfy": ("notifications", ["push", "pubsub"]),
    "web_app": ("examples", ["deployment", "starter"]),
}


def icon(name: str) -> str:
    """A distinct ~1.5-3 KB SVG per module; random paths so it compresses
    like a real icon rather than like repeated test data."""
    rnd = random.Random(hashlib.sha256(name.encode()).digest())
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">',
             f'<rect width="64" height="64" rx="12" fill="#{rnd.randrange(0x1000000):06x}"/>']
    for _ in range(rnd.randint(3, 6)):
        pts = " ".join(f"{'M' if i == 0 else 'L'}{rnd.uniform(4, 60):.2f} {rnd.uniform(4, 60):.2f}" for i in range(rnd.randint(6, 14)))
        parts.append(f'<path d="{pts}Z" fill="#{rnd.randrange(0x1000000):06x}" fill-opacity="0.{rnd.randint(4, 9)}"/>')
    parts.append("</svg>\n")
    return "\n".join(parts)


def title_of(desc: str, name: str) -> str:
    m = re.match(r"^([^—\-]+?)\s+(—|-)\s", desc)
    t = (m.group(1) if m else name.replace("_", " ").title()).strip()
    return t[:64]


def summary_of(desc: str) -> str:
    s = re.split(r"\s+(?:—|-)\s+", desc, maxsplit=1)
    s = s[1] if len(s) == 2 else desc
    s = s[0].upper() + s[1:]
    return s if len(s) <= 160 else s[:157].rstrip() + "..."


def block(name, path, version, desc, deps, repo):
    cat, kws = CAT[name]
    core_v = deps["opmodel.dev/core@v2"].lstrip("v")
    cats = {k: v.lstrip("v") for k, v in deps.items() if k.startswith("opmodel.dev/catalogs/")}
    vendor = "emil-jacero" if repo == "opm-modules" else "Open Platform Model"
    src = "https://github.com/emil-jacero/opm-modules" if repo == "opm-modules" else "https://github.com/open-platform-model/modules"
    catlines = "\n".join(f'\t\t\t"{k}": "{v}"' for k, v in cats.items())
    # Authored deliberately out of canonical order, with comments, to watch tidy.
    return f'''custom: "opmodel.dev@v0": {{
	// The author card (experiment 06). Comments and key order do not survive tidy.
	listing: {{
		title:         {json.dumps(title_of(desc, name))}
		schemaVersion: 1
		summary:       {json.dumps(summary_of(desc))}
		category:      "{cat}"
		keywords: {json.dumps(kws)}
		icon:     "assets/icon.svg"
		links: [{{kind: "source", url: "{src}/tree/main/{name}"}}, {{kind: "issues", url: "{src}/issues"}}]
		maintainers: [{{name: "Emil Larsson", url: "https://github.com/emil-jacero"}}]
		vendor:  "{vendor}"
		license: "Apache-2.0"
	}}
	kind: "module" // trailing comment
	identity: {{ModulePath: "{path}", Version: "{version}"}}
	core: {{major: "v2", version: "{core_v}"}}
	catalogs: {{
{catlines}
	}}
}}
'''


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    rows = []
    for repo in ("opm-modules", "modules"):
        for name in sorted(os.listdir(os.path.join(W, repo))):
            src = os.path.join(W, repo, name)
            mf = os.path.join(src, "cue.mod", "module.cue")
            if not os.path.isfile(mf):
                continue
            dst = os.path.join(OUT, name)
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns("CHANGELOG.md"))
            text = open(mf).read()
            path = re.search(r'^module: "([^"]+)"', text, re.M).group(1)
            deps = dict(re.findall(r'"([^"]+)": \{\s*v: "([^"]+)"', text))
            version = re.search(r'^Version: "([^"]+)"', open(os.path.join(src, "identity", "identity.cue")).read(), re.M).group(1)
            desc = json.loads(re.search(r'description:\s*(".*")', open(os.path.join(src, "module.cue")).read()).group(1))
            os.makedirs(os.path.join(dst, "assets"), exist_ok=True)
            open(os.path.join(dst, "assets", "icon.svg"), "w").write(icon(name))
            b = block(name, path, version, desc, deps, repo)
            open(os.path.join(dst, "cue.mod", "module.cue"), "a").write(b)
            shutil.copy(os.path.join(dst, "cue.mod", "module.cue"), os.path.join(dst, "module.orig.cue.txt"))
            rows.append({"name": name, "path": path, "version": version})
    json.dump(rows, open(os.path.join(X, ".work", "fleet.json"), "w"), indent=1)
    print(len(rows), "modules")


main()
