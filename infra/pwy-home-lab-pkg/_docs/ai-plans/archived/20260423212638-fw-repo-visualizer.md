# Plan: fw-repos-visualizer Framework Tool

## Objective

Add a new framework tool `fw-repos-visualizer` that discovers all known framework repos
by cloning them into a dedicated cache directory, scanning each clone for
`_framework_settings` directories, and recording the results as structured state files
under `config/tmp/fw-repos-visualizer/`. The tool renders that registry in one or more
output formats simultaneously (YAML, JSON, text tree, DOT graph). A configurable
auto-refresh mechanism keeps the state fresh without re-scanning on every command.

---

## Context

### Key design decisions (from user Q&A)

- **Output formats**: Multiple formats rendered simultaneously per `output_formats` list
  in config. Primary format is YAML (extensible by GUI — tool owns the `data:` key;
  GUI can add its own keys without conflict). Supported: `yaml`, `json`, `text`, `dot`.
- **Capabilities**: Visualization of `_requires_capability` / `_provides_capability` is
  optional per two independent config booleans: `show_capability_deps` and
  `show_capabilities_in_diagram`.
- **State vs. config separation**: Config lives in `_framework_settings/` (source-controlled);
  all generated state and output files live under `$GIT_ROOT/config/tmp/fw-repos-visualizer/`.
- **Refresh**: Controlled by `auto_refresh` block in config. Modes: `never`, `fixed_time`,
  `file_age` (default). Default minimum interval: 10 seconds. Separate flag for whether
  to auto-refresh before a render (`auto_refresh_on_render: true`). CLI `--refresh` always
  forces an immediate refresh.
- **Clone cache**: Independent directory from `pkg-mgr`'s `external_package_dir`.
  Default: `git/fw-repos-visualizer-cache` under `$HOME`.
- **Recursive repo discovery**: BFS expansion — each scanned repo's `_framework_settings/`
  dirs are checked for both `framework_package_repositories.yaml` (additional clone URLs)
  and `framework_repo_manager.yaml` (source_repos URLs + generated-repo lineage).
  Any new URL found is enqueued. Repos already in `seen_urls` (normalised, `.git`-stripped)
  are skipped.
- **`framework_repo_manager.yaml` integration**: provides two things:
  - `source_repos` entries (URL + ref) → added to the BFS clone queue exactly like
    `framework_package_repositories.yaml` entries.
  - `framework_repos` entries → each declares `source_repo: <name>` and its package list.
    The scanner records `created_by: <source_repo_name>` on the generated repo's state
    entry. If the generated repo has no clone URL discoverable via BFS, a stub entry is
    written using the packages declared inline in `framework_repo_manager.yaml`.
    `framework_package_template` (prepended to every generated repo) is also injected.
  Controlled by config `show_repo_lineage: true` (default: true).

### Existing patterns reused

- **3-tier config lookup**: inline `_fw_cfg_path` logic (same as `packages.py`) — no
  coupling to `config_mgr` package.
- **Python tool pattern**: bash wrapper sources `set_env.sh` + `_activate_python_locally`,
  then `exec python3 -m fw_repos_visualizer.main "$@"`.
- **Tool naming**: `fw-repos-visualizer` (descriptive, no Makefile → no `run` entry point).
- **Tool directory**: `infra/_framework-pkg/_framework/_fw-repos-visualizer/`
  Note: `infra/_framework-pkg` is a symlink to `../_ext_packages/de3-runner/main/infra/_framework-pkg`.
  All new files must be created at the real path:
  `$GIT_ROOT/../_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repos-visualizer/`
  (resolved by following the symlink from `infra/_framework-pkg`).

### State directory layout

```
$GIT_ROOT/config/tmp/fw-repos-visualizer/
├── known-fw-repos.yaml      # master scanned state (tool writes data: key only)
├── last-refresh              # empty file; mtime = timestamp of last completed scan
├── output.yaml               # rendered YAML (if yaml in output_formats)
├── output.json               # rendered JSON (if json in output_formats)
├── output.txt                # rendered text tree (if text in output_formats)
└── output.dot                # rendered DOT graph (if dot in output_formats)
```

`known-fw-repos.yaml` — tool writes only the `data:` top-level key:
```yaml
data:
  repos:
    de3-runner:
      url: https://github.com/philwyoungatinsight/de3-runner.git
      # created_by absent → this is a source/root repo
      settings_dirs:
        - path: infra/_framework-pkg/_config/_framework_settings
          packages:
            - name: _framework-pkg
              package_type: embedded
              exportable: true
              provides_capability: ["_framework-pkg: 1.9.0"]
              requires_capability: []
    de3-aws-pkg:
      url: null                        # null if no clone URL discovered via BFS
      created_by: de3-runner           # from framework_repo_manager.framework_repos[].source_repo
      source: declared                 # "cloned" if from actual scan, "declared" if from fw-repo-mgr only
      settings_dirs:
        - path: infra/aws-pkg/_config/_framework_settings
          packages:
            - name: _framework-pkg    # injected from framework_package_template
              package_type: external
              exportable: true
            - name: aws-pkg
              package_type: embedded
              exportable: true
```

The GUI is free to add top-level keys (`gui:`, `layout:`, etc.) alongside `data:`.
The tool never touches keys it did not write.

### Refresh logic

**`file_age` mode (default)**: trigger refresh when ALL true:
1. `last-refresh` mtime is older than `min_interval_seconds` (rate-limit gate).
2. The newest `framework_*.yaml` found in any `_framework_settings/` dir (current repo +
   all existing cached clones) is newer than `last-refresh` mtime.

**`fixed_time` mode**: trigger when `last-refresh` mtime is older than `min_interval_seconds`.

**`never` mode**: never auto-trigger; `--refresh` flag still forces a scan.

After a successful scan, `touch last-refresh`.

`auto_refresh_on_render`: if `true` (default), run the refresh check before any render
command. CLI `--auto-refresh` / `--no-auto-refresh` override config for that invocation.

### Version bump

`_framework-pkg` is currently `1.8.0`. This adds a new tool → bump to `1.9.0`.

---

## Open Questions

None — ready to proceed.

---

## Files to Create / Modify

All paths under `infra/_framework-pkg/` refer to the symlink-resolved real path.
In practice: follow the symlink when writing files.

---

### `infra/_framework-pkg/_framework/_fw-repos-visualizer/fw-repos-visualizer` — create

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

. "$(git rev-parse --show-toplevel)/set_env.sh"
. "$_UTILITIES_DIR/bash/init.sh"

export PYTHON_VERSION='python3.12'
_activate_python_locally "$SCRIPT_DIR"

cd "${SCRIPT_DIR}" && exec python3 -m fw_repos_visualizer.main "$@"
```

Make executable (`chmod +x`).

---

### `infra/_framework-pkg/_framework/_fw-repos-visualizer/requirements.txt` — create

```
pyyaml>=6.0
ruamel.yaml>=0.17
```

---

### `infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/__init__.py` — create

Empty.

---

### `infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/config.py` — create

Handles 3-tier config lookup and state dir resolution. Inlines `_fw_cfg_path` to avoid
cross-tool import coupling.

```python
"""Config loading for fw-repos-visualizer."""
from __future__ import annotations
import os, subprocess
from pathlib import Path
import yaml

def _fw_cfg_path(repo_root: Path, filename: str) -> Path:
    """Inline 3-tier lookup (mirrors packages.py — no cross-tool import)."""
    override = repo_root / "config" / filename
    if override.exists():
        return override
    config_pkg_dir = os.environ.get("_FRAMEWORK_CONFIG_PKG_DIR")
    if config_pkg_dir:
        candidate = Path(config_pkg_dir) / "_config" / "_framework_settings" / filename
        if candidate.exists():
            return candidate
    pkg_dir = os.environ.get("_FRAMEWORK_PKG_DIR") or str(repo_root / "infra" / "_framework-pkg")
    return Path(pkg_dir) / "_config" / "_framework_settings" / filename

def repo_root() -> Path:
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True, check=True)
    return Path(r.stdout.strip())

def load_config() -> dict:
    root = repo_root()
    path = _fw_cfg_path(root, "framework_repos_visualizer.yaml")
    if not path.exists():
        return {}
    raw = yaml.safe_load(path.read_text()) or {}
    return raw.get("framework_repos_visualizer", {})

def state_dir() -> Path:
    return repo_root() / "config" / "tmp" / "fw-repos-visualizer"
```

---

### `infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/scanner.py` — create

**`needs_refresh(cfg, sdir) -> bool`**

```python
import time
from pathlib import Path

def needs_refresh(cfg: dict, sdir: Path) -> bool:
    ar = cfg.get("auto_refresh", {})
    mode = ar.get("mode", "file_age")
    if mode == "never":
        return False
    min_interval = ar.get("min_interval_seconds", 10)
    marker = sdir / "last-refresh"
    last_ts = marker.stat().st_mtime if marker.exists() else 0.0
    age = time.time() - last_ts
    if age < min_interval:
        return False  # rate-limit gate
    if mode == "fixed_time":
        return True
    # file_age: check if any framework_*.yaml in known settings dirs is newer than last-refresh
    from .config import repo_root
    root = repo_root()
    cache_base = Path.home() / cfg.get("repos_cache_dir", "git/fw-repos-visualizer-cache")
    search_roots = [root]
    if cache_base.exists():
        search_roots += [p for p in cache_base.iterdir() if p.is_dir()]
    for sr in search_roots:
        for settings_dir in sr.rglob("_framework_settings"):
            for f in settings_dir.glob("framework_*.yaml"):
                if f.stat().st_mtime > last_ts:
                    return True
    return False
```

**`run_scan(cfg, sdir)`**

BFS repo discovery:

```python
from collections import deque
import subprocess
from pathlib import Path
import yaml

def run_scan(cfg: dict, sdir: Path):
    from .config import repo_root, _fw_cfg_path
    root = repo_root()
    cache_base = Path.home() / cfg.get("repos_cache_dir", "git/fw-repos-visualizer-cache")
    cache_base.mkdir(parents=True, exist_ok=True)
    show_caps = cfg.get("show_capability_deps", False) or cfg.get("show_capabilities_in_diagram", False)

    seen_urls: set[str] = set()
    queue: deque[dict] = deque()
    result: dict = {}

    def _norm(url: str) -> str:
        return url.rstrip("/").removesuffix(".git")

    def _enqueue_repos(repo_list: list[dict]):
        for r in repo_list:
            n = _norm(r["url"])
            if n not in seen_urls:
                seen_urls.add(n)
                queue.append(r)

    # Seed from framework_package_repositories.yaml (3-tier)
    repos_yaml = _fw_cfg_path(root, "framework_package_repositories.yaml")
    if repos_yaml.exists():
        raw = yaml.safe_load(repos_yaml.read_text()) or {}
        _enqueue_repos(raw.get("framework_package_repositories", []))

    # Seed additional source_repos from framework_repo_manager.yaml (3-tier)
    fw_mgr_yaml = _fw_cfg_path(root, "framework_repo_manager.yaml")
    lineage: dict[str, str] = {}          # generated_repo_name → source_repo_name
    declared_repos: dict[str, dict] = {}  # generated_repo_name → stub entry from fw-repo-mgr
    if fw_mgr_yaml.exists():
        raw = yaml.safe_load(fw_mgr_yaml.read_text()) or {}
        mgr = raw.get("framework_repo_manager", {})
        _enqueue_repos([
            {"name": r["name"], "url": r["url"]}
            for r in mgr.get("source_repos", [])
            if "url" in r
        ])
        pkg_template = mgr.get("framework_package_template")
        for fr in mgr.get("framework_repos", []):
            rname = fr["name"]
            src = fr.get("source_repo", "")
            lineage[rname] = src
            # Build a stub package list from the declared packages + template
            pkgs = []
            if pkg_template:
                pkgs.append({
                    "name": pkg_template["name"],
                    "package_type": pkg_template.get("package_type", "external"),
                    "exportable": pkg_template.get("exportable", True),
                })
            for p in fr.get("framework_packages", []):
                pkgs.append({
                    "name": p["name"],
                    "package_type": p.get("package_type", ""),
                    "exportable": p.get("exportable", False),
                })
            declared_repos[rname] = {
                "url": None,
                "created_by": src,
                "source": "declared",
                "settings_dirs": [{"path": f"infra/{rname}", "packages": pkgs}],
            }

    # Always scan current repo (implicit, not cloned)
    _scan_dir(root, "<current-repo>", None, result, _enqueue_repos, show_caps,
              lineage, declared_repos)

    while queue:
        repo_info = queue.popleft()
        name = repo_info["name"]
        url = repo_info["url"]
        clone_path = cache_base / name
        _clone_or_pull(url, clone_path)
        _scan_dir(clone_path, name, url, result, _enqueue_repos, show_caps,
                  lineage, declared_repos)

    # Merge any declared-only repos not reached by BFS
    for rname, stub in declared_repos.items():
        if rname not in result:
            result[rname] = stub

    _write_state(sdir, result)
    (sdir / "last-refresh").touch()


def _clone_or_pull(url: str, path: Path):
    if (path / ".git").exists():
        subprocess.run(["git", "-C", str(path), "pull", "--ff-only", "--quiet"],
                       check=True)
    else:
        subprocess.run(["git", "clone", "--quiet", url, str(path)], check=True)


def _scan_dir(path: Path, name: str, url, result: dict,
              enqueue_fn, show_caps: bool,
              lineage: dict, declared_repos: dict):
    # If we cloned this repo, mark it as "cloned" and set real URL; preserve created_by
    existing = result.get(name, {})
    entry = result.setdefault(name, {
        "url": url,
        "created_by": lineage.get(name),
        "source": "cloned",
        "settings_dirs": [],
    })
    if url:
        entry["url"] = url
        entry["source"] = "cloned"
    if lineage.get(name):
        entry["created_by"] = lineage[name]

    for sd in sorted(path.rglob("_framework_settings")):
        rel = str(sd.relative_to(path))
        pkgs_yaml = sd / "framework_packages.yaml"
        packages = []
        if pkgs_yaml.exists():
            raw = yaml.safe_load(pkgs_yaml.read_text()) or {}
            for p in raw.get("framework_packages", []):
                pkg_entry = {
                    "name": p["name"],
                    "package_type": p.get("package_type", ""),
                    "exportable": p.get("exportable", False),
                }
                if show_caps:
                    pkg_cfg = path / "infra" / p["name"] / "_config" / f"{p['name']}.yaml"
                    if pkg_cfg.exists():
                        pc = yaml.safe_load(pkg_cfg.read_text()) or {}
                        ps = pc.get(p["name"], {})
                        pkg_entry["provides_capability"] = ps.get("_provides_capability", [])
                        pkg_entry["requires_capability"] = ps.get("_requires_capability", [])
                packages.append(pkg_entry)

        # Discover new repos from framework_package_repositories.yaml in this settings dir
        repos_yaml = sd / "framework_package_repositories.yaml"
        if repos_yaml.exists():
            raw = yaml.safe_load(repos_yaml.read_text()) or {}
            enqueue_fn(raw.get("framework_package_repositories", []))

        # Discover additional source_repos and lineage from framework_repo_manager.yaml
        mgr_yaml = sd / "framework_repo_manager.yaml"
        if mgr_yaml.exists():
            raw = yaml.safe_load(mgr_yaml.read_text()) or {}
            mgr = raw.get("framework_repo_manager", {})
            enqueue_fn([
                {"name": r["name"], "url": r["url"]}
                for r in mgr.get("source_repos", [])
                if "url" in r
            ])
            pkg_template = mgr.get("framework_package_template")
            for fr in mgr.get("framework_repos", []):
                rname = fr["name"]
                src = fr.get("source_repo", "")
                if rname not in lineage:
                    lineage[rname] = src
                if rname not in declared_repos:
                    pkgs = []
                    if pkg_template:
                        pkgs.append({
                            "name": pkg_template["name"],
                            "package_type": pkg_template.get("package_type", "external"),
                            "exportable": pkg_template.get("exportable", True),
                        })
                    for p in fr.get("framework_packages", []):
                        pkgs.append({
                            "name": p["name"],
                            "package_type": p.get("package_type", ""),
                            "exportable": p.get("exportable", False),
                        })
                    declared_repos[rname] = {
                        "url": None,
                        "created_by": src,
                        "source": "declared",
                        "settings_dirs": [{"path": f"infra/{rname}", "packages": pkgs}],
                    }

        entry["settings_dirs"].append({"path": rel, "packages": packages})


def _write_state(sdir: Path, repos: dict):
    from ruamel.yaml import YAML
    state_file = sdir / "known-fw-repos.yaml"
    ry = YAML()
    ry.preserve_quotes = True
    if state_file.exists():
        with open(state_file) as f:
            existing = ry.load(f) or {}
    else:
        existing = {}
    if "data" not in existing or not isinstance(existing.get("data"), dict):
        existing["data"] = {}
    existing["data"]["repos"] = repos
    with open(state_file, "w") as f:
        ry.dump(existing, f)
```

---

### `infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/renderer.py` — create

```python
"""Render known-fw-repos.yaml into output files."""
from __future__ import annotations
import json
from pathlib import Path
import yaml

def render_all(cfg: dict, sdir: Path, formats: list[str]) -> list[Path]:
    state_file = sdir / "known-fw-repos.yaml"
    if not state_file.exists():
        import sys
        print("fw-repos-visualizer: no state found — run --refresh first", file=sys.stderr)
        return []
    raw = yaml.safe_load(state_file.read_text()) or {}
    data = raw.get("data", {})
    repos = data.get("repos", {})
    show_cap_deps = cfg.get("show_capability_deps", False)
    show_cap_labels = cfg.get("show_capabilities_in_diagram", False)
    show_lineage = cfg.get("show_repo_lineage", True)

    written = []
    ext_map = {"yaml": "yaml", "json": "json", "text": "txt", "dot": "dot"}
    for fmt in formats:
        if fmt not in ext_map:
            import sys
            print(f"fw-repos-visualizer: unknown format '{fmt}', skipping", file=sys.stderr)
            continue
        out_path = sdir / f"output.{ext_map[fmt]}"
        content = _render(fmt, repos, show_cap_deps, show_cap_labels, show_lineage)
        out_path.write_text(content)
        written.append(out_path)
    return written


def _render(fmt: str, repos: dict, show_cap_deps: bool, show_cap_labels: bool,
            show_lineage: bool) -> str:
    if fmt == "yaml":
        return yaml.dump({"repos": repos}, default_flow_style=False, allow_unicode=True)
    if fmt == "json":
        return json.dumps({"repos": repos}, indent=2)
    if fmt == "text":
        return _render_text(repos, show_cap_deps, show_cap_labels, show_lineage)
    if fmt == "dot":
        return _render_dot(repos, show_cap_deps, show_cap_labels, show_lineage)
    return ""


def _render_text(repos: dict, show_cap_deps: bool, show_cap_labels: bool,
                 show_lineage: bool) -> str:
    lines = []
    for repo_name, repo_data in repos.items():
        url = repo_data.get("url") or "local"
        created_by = repo_data.get("created_by")
        src_tag = repo_data.get("source", "cloned")
        lineage_str = ""
        if show_lineage and created_by:
            lineage_str = f"  [created by: {created_by}]"
        declared_str = "  [declared only]" if src_tag == "declared" else ""
        lines.append(f"{repo_name}  ({url}){lineage_str}{declared_str}")
        sdirs = repo_data.get("settings_dirs", [])
        for i, sd in enumerate(sdirs):
            is_last_sd = (i == len(sdirs) - 1)
            sd_prefix = "└── " if is_last_sd else "├── "
            pkg_prefix = "    " if is_last_sd else "│   "
            lines.append(f"{sd_prefix}{sd['path']}")
            pkgs = sd.get("packages", [])
            for j, pkg in enumerate(pkgs):
                is_last_pkg = (j == len(pkgs) - 1)
                p_prefix = pkg_prefix + ("└── " if is_last_pkg else "├── ")
                flags = []
                if pkg.get("package_type"):
                    flags.append(pkg["package_type"])
                if pkg.get("exportable"):
                    flags.append("exportable")
                flag_str = f"  [{', '.join(flags)}]" if flags else ""
                cap_parts = []
                if show_cap_labels:
                    for c in pkg.get("provides_capability", []):
                        cap_parts.append(f"provides: {c}")
                if show_cap_deps:
                    for c in pkg.get("requires_capability", []):
                        cap_parts.append(f"requires: {c}")
                cap_str = "  " + ", ".join(cap_parts) if cap_parts else ""
                lines.append(f"{p_prefix}{pkg['name']}{flag_str}{cap_str}")
        lines.append("")
    return "\n".join(lines)


def _render_dot(repos: dict, show_cap_deps: bool, show_cap_labels: bool,
                show_lineage: bool) -> str:
    lines = ["digraph fw_repos {", "  rankdir=LR;", "  node [fontname=Helvetica];", ""]
    cap_providers: dict[str, str] = {}    # capability-name → package-node-id
    repo_anchor: dict[str, str] = {}     # repo-name → a node-id inside that repo's cluster

    cluster_idx = 0
    for repo_name, repo_data in repos.items():
        is_declared = repo_data.get("source") == "declared"
        fill = "lightyellow" if not is_declared else "lightgrey"
        lines.append(f"  subgraph cluster_{cluster_idx} {{")
        url = repo_data.get("url") or ""
        created_by = repo_data.get("created_by") or ""
        subtitle = f"\\n{url}" if url else ""
        if show_lineage and created_by:
            subtitle += f"\\ncreated by: {created_by}"
        if is_declared:
            subtitle += "\\n[declared only]"
        lines.append(f'    label="{repo_name}{subtitle}";')
        lines.append(f'    style=filled; fillcolor={fill};')

        first_node = None
        for sd in repo_data.get("settings_dirs", []):
            sd_id = _dot_id(f"{repo_name}_{sd['path']}")
            if first_node is None:
                first_node = sd_id
            lines.append(f'    {sd_id} [label="{sd["path"]}", shape=box, '
                         f'style=filled, fillcolor=lightblue];')
            for pkg in sd.get("packages", []):
                pkg_id = _dot_id(f"{repo_name}_{pkg['name']}")
                cap_label = ""
                if show_cap_labels:
                    provides = pkg.get("provides_capability", [])
                    if provides:
                        cap_label = "\\n" + "\\n".join(str(c) for c in provides)
                lines.append(f'    {pkg_id} [label="{pkg["name"]}{cap_label}", shape=ellipse];')
                lines.append(f"    {sd_id} -> {pkg_id};")
                if show_cap_labels or show_cap_deps:
                    for cap in pkg.get("provides_capability", []):
                        cap_name = str(cap).split(":")[0].strip() if ":" in str(cap) else str(cap)
                        cap_providers[cap_name] = pkg_id
        if first_node:
            repo_anchor[repo_name] = first_node
        cluster_idx += 1
        lines.append("  }")
        lines.append("")

    if show_lineage:
        lines.append("  // repo lineage edges (source repo → generated repo)")
        for repo_name, repo_data in repos.items():
            created_by = repo_data.get("created_by")
            if created_by and created_by in repo_anchor and repo_name in repo_anchor:
                src_node = repo_anchor[created_by]
                dst_node = repo_anchor[repo_name]
                lines.append(f'  {src_node} -> {dst_node} '
                             f'[ltail=cluster_{list(repo_anchor).index(created_by)}, '
                             f'lhead=cluster_{list(repo_anchor).index(repo_name)}, '
                             f'style=bold, color=darkgreen, label="creates"];')
        lines.append("")

    if show_cap_deps:
        lines.append("  // capability dependency edges")
        for repo_name, repo_data in repos.items():
            for sd in repo_data.get("settings_dirs", []):
                for pkg in sd.get("packages", []):
                    pkg_id = _dot_id(f"{repo_name}_{pkg['name']}")
                    for req in pkg.get("requires_capability", []):
                        req_name = str(req).split(":")[0].strip() if ":" in str(req) else str(req)
                        if req_name in cap_providers:
                            lines.append(f"  {pkg_id} -> {cap_providers[req_name]} "
                                         f'[style=dashed, label="requires"];')
        lines.append("")

    # compound=true required for lhead/ltail cluster edges
    lines.insert(1, "  compound=true;")
    lines.append("}")
    return "\n".join(lines)


def _dot_id(s: str) -> str:
    import re
    return re.sub(r"[^a-zA-Z0-9_]", "_", s)
```

---

### `infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/main.py` — create

```python
"""fw-repos-visualizer CLI."""
from __future__ import annotations
import argparse, shutil, sys
from pathlib import Path
from .config import load_config, state_dir
from .scanner import needs_refresh, run_scan
from .renderer import render_all

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="fw-repos-visualizer",
        description="Discover and visualize framework repos and their packages.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  fw-repos-visualizer --refresh\n"
            "  fw-repos-visualizer --list\n"
            "  fw-repos-visualizer --list --format text,dot\n"
            "  fw-repos-visualizer --refresh --list\n"
            "  fw-repos-visualizer --list --no-auto-refresh\n"
        ),
    )
    p.add_argument("-r", "--refresh", action="store_true",
                   help="Force immediate scan; update known-fw-repos.yaml and last-refresh")
    p.add_argument("-l", "--list", action="store_true",
                   help="Render all configured output formats to state dir")
    p.add_argument("-f", "--format", metavar="FORMATS",
                   help="Comma-separated formats for this run (yaml,json,text,dot); overrides config")
    p.add_argument("--auto-refresh", dest="auto_refresh", action="store_true", default=None,
                   help="Auto-refresh before render if stale (overrides auto_refresh_on_render)")
    p.add_argument("--no-auto-refresh", dest="auto_refresh", action="store_false",
                   help="Skip auto-refresh check before render")
    p.add_argument("-o", "--output", metavar="FILE",
                   help="Copy first rendered output to FILE (stdout if FILE is -)")
    return p

def main(argv=None):
    p = _build_parser()
    effective = argv if argv is not None else sys.argv[1:]
    if not effective:
        p.print_help(sys.stderr); sys.exit(2)
    args = p.parse_args(effective)

    cfg = load_config()
    sdir = state_dir()
    sdir.mkdir(parents=True, exist_ok=True)

    formats = (
        [f.strip() for f in args.format.split(",")]
        if args.format
        else cfg.get("output_formats", ["yaml", "text"])
    )

    will_render = args.list or bool(args.format)
    on_render = cfg.get("auto_refresh", {}).get("auto_refresh_on_render", True)
    effective_auto = args.auto_refresh if args.auto_refresh is not None else on_render

    do_refresh = args.refresh or (will_render and effective_auto and needs_refresh(cfg, sdir))
    if do_refresh:
        run_scan(cfg, sdir)

    if will_render:
        paths = render_all(cfg, sdir, formats)
        if args.output:
            if args.output == "-" and paths:
                sys.stdout.write(Path(paths[0]).read_text())
            elif paths:
                shutil.copy(paths[0], args.output)
        else:
            for out in paths:
                print(out)

if __name__ == "__main__":
    main()
```

---

### `infra/_framework-pkg/_config/_framework_settings/framework_repos_visualizer.yaml` — create

Config only; no state. Top-level key `framework_repos_visualizer`.

```yaml
framework_repos_visualizer:
  # Directory under $HOME where repos are cloned for scanning.
  # Completely independent of framework_package_management.external_package_dir.
  repos_cache_dir: 'git/fw-repos-visualizer-cache'

  # Formats to render on --list. All rendered simultaneously.
  # Valid values: yaml, json, text, dot
  output_formats:
    - yaml
    - text

  # Repo lineage visualization (from framework_repo_manager.yaml).
  # show_repo_lineage: annotate generated repos with "created by: <source>" and draw
  #   bold green "creates" edges from source repo to generated repo in DOT output.
  show_repo_lineage: true

  # Capability visualization.
  # show_capability_deps: draw edges between packages based on _requires_capability.
  # show_capabilities_in_diagram: include capability strings as labels on package nodes/lines.
  show_capability_deps: false
  show_capabilities_in_diagram: false

  # Auto-refresh behaviour.
  auto_refresh:
    # mode:
    #   never      — only --refresh flag triggers a scan
    #   fixed_time — scan if last-refresh is older than min_interval_seconds
    #   file_age   — scan if any _framework_settings/*.yaml is newer than last-refresh
    #                AND last-refresh age > min_interval_seconds (rate-limit gate)
    mode: file_age
    min_interval_seconds: 10
    # If true, check-and-possibly-refresh before any --list render.
    # Override per-invocation with --auto-refresh / --no-auto-refresh.
    auto_refresh_on_render: true
```

---

### `infra/_framework-pkg/_config/_framework-pkg.yaml` — modify

```yaml
_framework-pkg:
  _provides_capability:
  - _framework-pkg: 1.9.0
```

---

### `infra/_framework-pkg/_config/version_history.md` — modify

Prepend after `# _framework-pkg version history` heading:

```markdown
## 1.9.0  (2026-04-23, git: <sha-after-commit>)
- Add `fw-repos-visualizer` framework tool: BFS-discovers all reachable framework repos,
  scans `_framework_settings` dirs, renders as yaml/json/text/dot simultaneously
- State files (known-fw-repos.yaml, output.*) in `config/tmp/fw-repos-visualizer/`; config
  in `_framework_settings/framework_repos_visualizer.yaml`
- Configurable auto-refresh: modes never/fixed_time/file_age; default file_age, 10s gate
- Optional capability visualization: show_capability_deps, show_capabilities_in_diagram
- Repo lineage from framework_repo_manager.yaml: source_repos seeded into BFS; generated
  repos annotated with created_by and rendered as bold green "creates" edges in DOT
```

---

### `infra/_framework-pkg/_framework/README.md` — modify

Add `fw-repos-visualizer` entry in the tool catalog. Match existing entry format.

---

## Execution Order

1. Resolve symlink: `readlink -f infra/_framework-pkg` to get real path.
2. Create `_fw-repos-visualizer/` at real path.
3. Write and `chmod +x` bash wrapper `fw-repos-visualizer`.
4. Write `requirements.txt`.
5. Create `fw_repos_visualizer/` Python package:
   `__init__.py` → `config.py` → `scanner.py` → `renderer.py` → `main.py`.
6. Write `framework_repos_visualizer.yaml` default config to `_framework_settings/`.
7. Update `_framework-pkg.yaml` (version bump).
8. Update `version_history.md`.
9. Update `_framework/README.md`.
10. Install venv (`_activate_python_locally`) and smoke-test: `fw-repos-visualizer --help`.
11. Run `fw-repos-visualizer --refresh --list` and verify state dir populated.
12. Commit changes in de3-runner working copy; fill `<sha-after-commit>` in version_history.md.
13. Write ai-log entry.

---

## Verification

```bash
source set_env.sh

# 1. Help works
fw-repos-visualizer --help

# 2. Force scan
fw-repos-visualizer --refresh
ls config/tmp/fw-repos-visualizer/
# → known-fw-repos.yaml  last-refresh

# 3. Render defaults (yaml + text)
fw-repos-visualizer --list
# → prints two output file paths

cat config/tmp/fw-repos-visualizer/output.txt
cat config/tmp/fw-repos-visualizer/output.yaml

# 4. DOT output
fw-repos-visualizer --list --format dot
cat config/tmp/fw-repos-visualizer/output.dot

# 5. All formats at once
fw-repos-visualizer --list --format yaml,json,text,dot

# 6. Rate-limit: second --list within 10s must NOT re-scan
fw-repos-visualizer --list   # triggers scan (stale)
fw-repos-visualizer --list   # skips scan (< 10s)

# 7. Version
grep '_provides_capability' infra/_framework-pkg/_config/_framework-pkg.yaml
# → _framework-pkg: 1.9.0
```
