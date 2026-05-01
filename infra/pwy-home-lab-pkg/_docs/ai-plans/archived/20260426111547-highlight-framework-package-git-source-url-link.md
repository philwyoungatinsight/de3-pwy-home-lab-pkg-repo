# Plan: Hyperlinks on Package Nodes and Repo Config File in fw-repos Visualizer

## Objective

Add two clickable hyperlinks to the DOT output of `fw-repos-visualizer`:

1. **Each package node (ellipse)** becomes a clickable link to the repo's git browse URL (e.g., `https://github.com/org/repo`). When the DOT file is rendered as SVG, clicking any package node opens the repo in a browser.

2. **Each repo cluster label** becomes a clickable link directly to `framework_repo_manager.yaml` inside the repo — specifically the file at `infra/<config_package>/_config/_framework_settings/framework_repo_manager.yaml` — so the user can immediately jump to the config that generated the diagram.

The `config_package` (the package name holding the repo's `framework_repo_manager.yaml`) is read from `config/_framework.yaml` in each scanned repo (`_framework.config_package` key).

## Context

**Current state:**
- `renderer.py:_render_dot()` renders package nodes as `[label="...", shape=ellipse]` — no URL attributes.
- Repo clusters show the URL as a text subtitle in the cluster label, but it is not clickable.
- The repo data model has a `url` field (the upstream git URL, e.g., ending in `.git`) but no `config_package` field.
- `scanner.py:_scan_dir()` reads `framework_packages.yaml` and `framework_repo_manager.yaml` from each cloned/local repo, but does NOT read `config/_framework.yaml`.

**What Graphviz supports:**
- Nodes with `URL="..."` and `target="_blank"` attributes produce clickable links in SVG output (via `dot -Tsvg`).
- Clusters/subgraphs with `URL="..."` produce a clickable cluster label in SVG output.
- JSON/YAML outputs are unaffected — `config_package` would appear as a new field there as a bonus.

**URL normalization needed:**
- Git remote URLs may end in `.git` (`https://github.com/org/repo.git`) or use SSH form (`git@github.com:org/repo.git`). Both must be normalized to `https://github.com/org/repo` for a browseable link.
- GitHub supports `/blob/HEAD/` as a universal ref that redirects to the default branch, so we don't need to track per-repo branch names.

**Known edge cases:**
- Local repo (`source: local`) may have `url: null` — no links generated.
- Declared-only repos (not cloned) also may have `url: null` — no links generated.
- If `config/_framework.yaml` doesn't exist in a repo or lacks `_framework.config_package`, the cluster URL is omitted (no crash).

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/scanner.py` — modify

In `_scan_dir()`, after the `entry` dict is initialized (around line 243), add a read of `config/_framework.yaml` from the repo root:

```python
# Read config_package from config/_framework.yaml (present in generated repos)
config_fw = path / "config" / "_framework.yaml"
if config_fw.exists():
    try:
        cf_raw = yaml.safe_load(config_fw.read_text()) or {}
        config_pkg = cf_raw.get("_framework", {}).get("config_package")
        if config_pkg:
            entry["config_package"] = config_pkg
    except Exception:
        pass
```

Place this block after the `entry` setdefault/update lines and before the `_find_settings_dirs` loop.

### `_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repos-visualizer/fw_repos_visualizer/renderer.py` — modify

**Add two helper functions** before `_render_dot()`:

```python
def _to_browse_url(git_url: str) -> str | None:
    """Normalize a git remote URL to a browseable HTTPS URL. Returns None if unrecognized."""
    if not git_url:
        return None
    url = git_url.strip().rstrip("/").removesuffix(".git")
    if url.startswith("git@"):
        # git@github.com:org/repo → https://github.com/org/repo
        url = "https://" + url[len("git@"):].replace(":", "/", 1)
    if url.startswith(("https://", "http://")):
        return url
    return None


def _fw_repo_mgr_url(browse_url: str, config_package: str) -> str:
    """Construct the GitHub blob URL to framework_repo_manager.yaml in config_package."""
    return (
        f"{browse_url}/blob/HEAD"
        f"/infra/{config_package}/_config/_framework_settings/framework_repo_manager.yaml"
    )
```

**Update `_render_dot()`** — two changes:

1. After `lines.append(f"    style=filled; fillcolor={fill};")` (line 129), add cluster URL when available:

```python
browse_url = _to_browse_url(repo_data.get("url") or "")
config_package = repo_data.get("config_package")
if browse_url and config_package:
    fw_url = _fw_repo_mgr_url(browse_url, config_package)
    lines.append(f'    URL="{fw_url}";')
    lines.append('    target="_blank";')
```

2. In the package node rendering block (around line 147-149), add URL attribute when the repo has a browse URL:

```python
url_attr = f', URL="{browse_url}", target="_blank"' if browse_url else ""
lines.append(
    f'    {pkg_id} [label="{pkg["name"]}{cap_label}", shape=ellipse{url_attr}];'
)
```

Note: `browse_url` is computed once per cluster (see change 1 above) so it is already in scope.

The subtitle text on the cluster label (`subtitle = f"\\n{url}" if url else ""`) can be retained or removed. Retaining it preserves readability in non-SVG DOT viewers; it is slightly redundant when the cluster label is already clickable. Leave it in for now — the cluster label is still readable in plain text mode.

## Execution Order

1. Modify `scanner.py` — add `config_package` extraction in `_scan_dir()`.
2. Modify `renderer.py` — add `_to_browse_url` and `_fw_repo_mgr_url` helpers, then update `_render_dot()` (cluster URL, then node URL attribute).
3. Run `fw-repos-visualizer --refresh --render dot` and inspect `config/tmp/fw-repos-visualizer/output.dot` to confirm URL attributes appear on nodes and clusters.
4. Convert to SVG and verify links: `dot -Tsvg config/tmp/fw-repos-visualizer/output.dot > /tmp/fw-repos.svg` and open in a browser.
5. Bump `_provides_capability` version in `infra/_framework-pkg/_config/_framework-pkg.yaml` (patch bump) and append to `version_history.md`.
6. Write ai-log entry, then commit.

## Verification

```bash
# After running --refresh --render dot:
grep 'URL=' config/tmp/fw-repos-visualizer/output.dot

# Should show lines like:
#   URL="https://github.com/philwyoungatinsight/proxmox-pkg-repo/blob/HEAD/infra/proxmox-pkg/_config/_framework_settings/framework_repo_manager.yaml";
#   proxmox_pkg_repo__framework_pkg [label="_framework-pkg", shape=ellipse, URL="https://github.com/philwyoungatinsight/proxmox-pkg-repo", target="_blank"];

# Convert to SVG and open:
dot -Tsvg config/tmp/fw-repos-visualizer/output.dot > /tmp/fw-repos.svg
xdg-open /tmp/fw-repos.svg  # or open in browser manually
```

Expected: clicking a package node opens the repo GitHub page; clicking a cluster label opens the `framework_repo_manager.yaml` in GitHub.
