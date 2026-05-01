# fw-repos viewer: verbose mode, show-backend, notes support

## What changed

### `scanner.py` (`_framework-pkg` 1.11.0)
- `_scan_dir`: reads `framework_backend.yaml` from `infra/<config_pkg>/_config/_framework_settings/` and stores `framework_backend` dict in the result entry
- `_scan_dir`: back-fills `notes` list from `declared_repos` stub (set by `_load_repo_manager`)
- `_load_repo_manager`: stores `notes: [str(n) for n in fr.get("notes", [])]` in each declared_repos stub — add a `notes:` list under any `framework_repos` entry in `framework_repo_manager.yaml` to populate this

### `fw_repos_mermaid_viewer.html` (`de3-gui-pkg` 0.6.0)
Two new URL params read by JavaScript (`verbose`, `showBackend`):

**Verbose mode** changes:
- `git-url: <url>` / `config-package: <pkg>` labels on first two attributes
- `─── Packages ───────────────────` named separator
- `◆ pkg-name` for embedded, `◇ pkg-name` for external (instead of `+`/`-`)
- `notes()` stub method + `• note text()` per note in the methods compartment

**Show backend**:
- Shows `framework_backend.type · bucket` as an attribute; prefixed `backend:` in verbose mode

### `homelab_gui.py` (`de3-gui-pkg` 0.6.0)
- New state fields: `fw_repos_verbose`, `fw_repos_show_backend`
- Both persisted in save/restore config
- `fw_repos_iframe_src` computed var passes `&verbose=` and `&showBackend=` to iframe URL
- Toggle/flip handlers for both
- Two new checkboxes in the Framework Repos appearance section: **Verbose** and **Show backend**

## How to add notes to a repo

In `framework_repo_manager.yaml`, add a `notes:` list to any `framework_repos` entry:

```yaml
framework_repos:
  - name: proxmox-pkg-repo
    source_repo: de3-runner
    upstream_url: https://github.com/philwyoungatinsight/proxmox-pkg-repo.git
    notes:
      - "Deployment-specific split from de3-runner"
      - "Config package handles Proxmox + UniFi"
```

Then run `fw-repos-visualizer --refresh` and enable Verbose in the appearance menu.

## Package symbol choices (◆/◇ used)

Alternatives if you want something different:
- `■ / □` — filled/empty square
- `[E] / [X]` — text abbreviations
- `● / ○` — filled/empty circle
- `▶ / ▷` — filled/hollow triangle
