# Plan: gh + glab OAuth Login Setup

## Objective

Add `gh` (GitHub CLI) and `glab` (GitLab CLI) OAuth authentication to `pwy-home-lab-pkg`
via the `_setup` developer workflow. A new framework settings file (`framework_git_config.yaml`)
controls optional periodic auth validation — analogous to how `framework_validate_config.yaml`
controls the YAML config linter. No Terragrunt unit is created; the check runs at `_setup`
time and on every `./run --setup-packages` invocation. The code patterns are designed for
future extraction into a generic package alongside the existing `update-ssh-config` code.

## Context

**What exists:**
- `gh` is already installed at `/usr/bin/gh` and authenticated for `github.com` via OS keychain
  (scopes: `gist, read:org, repo, workflow`)
- `glab` is not installed
- `infra/pwy-home-lab-pkg/_setup/` contains only `.gitkeep` — no setup scripts yet
- `gcp-pkg/_setup/run` + `gcp-pkg/_setup/seed` are the canonical patterns to follow
  - `_setup/run` installs tools and delegates seed-style args to `./seed`
  - `_setup/seed` handles interactive auth (`--login`, `--seed`, `--test`, `--status`, `--clean`)
- `setup_packages()` in the root `run` symlink discovers `infra/*/_setup/run` and calls each
  during `./run --build` and `./run --setup-packages`
- `seed_packages()` discovers `infra/*/_setup/seed` and calls `--login`, `--seed`, `--test`
- `infra/_framework-pkg/_config/_framework_settings/framework_validate_config.yaml` is the analogue:
  ```yaml
  framework_validate_config:
    mode: every_n_minutes
    interval_minutes: 60
    show_individual_files_checked: false
  ```
- `_utilities/python/validate-config.py` is the Python-script analogue — reads the settings
  file, rate-limits via a flag file at `$_CONFIG_TMP_DIR/<script>-last-run`, prints PASS/FAIL
- `_framework-pkg` is a symlink to `_ext_packages/de3-runner/main/infra/_framework-pkg` —
  cannot write files there; all new files go in `infra/pwy-home-lab-pkg/`
- Both `set_env.sh` and the root `run` script are symlinks — cannot be modified here
- All repos in `framework_repo_manager.yaml` use `github.com` URLs — initial auth check
  only needs `gh`; `glab` is installed for future use

**`current-repos` validation strategy:**
Collect git hostnames from:
1. `git remote -v` in `$GIT_ROOT` (current repo)
2. `framework_repo_manager.yaml`: `source_repo_defaults.git-remotes.*`,
   `framework_repos[*].new_repo_config.git-remotes.*`,
   `framework_repos[*].framework_packages[*].source`,
   `framework_package_template.source`
Parse URLs with `urllib.parse.urlparse` (https) and regex (git@ SSH). Deduplicate. For each
host, look up the CLI tool via `host_type_map`; skip hosts not in the map.

## Open Questions

None — all design decisions have been encoded as config options with recommended defaults.

## Files to Create / Modify

---

### `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_git_config.yaml` — create

New consumer-package framework settings file. Follows the 3-tier lookup convention
(per-dev `config/framework_git_config.yaml` > this file > framework default, if one existed).
All options are documented inline.

```yaml
framework_git_config:
  git-auth:
    # mode:
    #   never         — auth check is never run automatically
    #   every_n_minutes — run if last-check is older than interval_minutes
    mode: every_n_minutes
    interval_minutes: 60

    # validation_type:
    #   current-repos — scan git remotes + framework_repo_manager.yaml for unique
    #                   hostnames and check auth for each known host
    validation_type: current-repos

    # on_failure:
    #   warn  — print warning but exit 0 (non-blocking)
    #   fail  — exit 1 (blocks setup/build)
    on_failure: warn

    # Maps git hostname → CLI tool to check auth with.
    # Add entries for self-hosted GitLab/GitHub instances as needed.
    host_type_map:
      github.com: gh
      gitlab.com: glab

    # Expected gh token scopes. Reported missing scopes are shown in the warning/error.
    gh_scopes:
      - repo
      - read:org
      - workflow
      - gist

    # If true, instruct gh/glab to store tokens in the OS keychain (the default).
    # Set to false in headless/CI environments where keychain is unavailable.
    prefer_keychain: true
```

---

### `infra/pwy-home-lab-pkg/_setup/check-git-auth` — create

Python script (no `run` naming since there is no sibling Makefile). Called by `_setup/run`
after tool installation. Reads `framework_git_config.yaml` via the 3-tier lookup, rate-limits
by a flag file, collects hostnames, and checks auth for each mapped tool.

```python
#!/usr/bin/env python3
"""
check-git-auth — validate gh/glab authentication against all git remotes.

Usage:
  check-git-auth [--force]

  --force   Skip the rate-limit check and always run validation.
  --help    Print this message.
"""
import argparse
import os
import re
import subprocess
import sys
import time
import yaml
from pathlib import Path
from urllib.parse import urlparse

# ── 3-tier settings lookup ────────────────────────────────────────────────────

def _load_cfg(git_root: Path) -> dict:
    """Load framework_git_config.yaml via 3-tier lookup."""
    fw_pkg_dir = git_root / "infra" / "_framework-pkg"
    fw_cfg_pkg = os.environ.get("_FRAMEWORK_CONFIG_PKG_DIR", "")

    candidates = [
        git_root / "config" / "framework_git_config.yaml",
    ]
    if fw_cfg_pkg:
        candidates.append(Path(fw_cfg_pkg) / "_config" / "_framework_settings" / "framework_git_config.yaml")
    candidates.append(fw_pkg_dir / "_config" / "_framework_settings" / "framework_git_config.yaml")

    for path in candidates:
        if path.exists():
            with open(path) as f:
                return yaml.safe_load(f) or {}
    return {}

# ── Hostname extraction ───────────────────────────────────────────────────────

def _parse_host(url: str) -> str | None:
    """Return the hostname from an https:// or git@host:... URL."""
    url = url.strip()
    if url.startswith("git@"):
        m = re.match(r"git@([^:]+):", url)
        return m.group(1) if m else None
    try:
        return urlparse(url).hostname or None
    except Exception:
        return None

def _hosts_from_git_remotes(git_root: Path) -> set[str]:
    result = subprocess.run(
        ["git", "remote", "-v"], cwd=git_root, capture_output=True, text=True
    )
    hosts: set[str] = set()
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            h = _parse_host(parts[1])
            if h:
                hosts.add(h)
    return hosts

def _hosts_from_fw_repo_mgr(git_root: Path) -> set[str]:
    """Extract hostnames from framework_repo_manager.yaml (all packages)."""
    hosts: set[str] = set()
    for yml_path in git_root.glob("infra/**/_config/_framework_settings/framework_repo_manager.yaml"):
        try:
            with open(yml_path) as f:
                data = yaml.safe_load(f) or {}
        except Exception:
            continue
        mgr = data.get("framework_repo_manager", {})

        # source_repo_defaults.git-remotes.*
        for url in mgr.get("source_repo_defaults", {}).get("git-remotes", {}).values():
            h = _parse_host(str(url)); h and hosts.add(h)

        # framework_repos[*]
        for repo in mgr.get("framework_repos", []):
            for url in repo.get("new_repo_config", {}).get("git-remotes", {}).values():
                h = _parse_host(str(url)); h and hosts.add(h)
            for pkg in repo.get("framework_packages", []):
                src = pkg.get("source", "")
                h = _parse_host(str(src)); h and hosts.add(h)

        # framework_package_template.source
        tpl_src = mgr.get("framework_package_template", {}).get("source", "")
        if tpl_src:
            h = _parse_host(str(tpl_src)); h and hosts.add(h)

    return hosts

# ── Auth checks ───────────────────────────────────────────────────────────────

def _check_gh(host: str, expected_scopes: list[str]) -> tuple[bool, str]:
    r = subprocess.run(["gh", "auth", "status", "--hostname", host],
                       capture_output=True, text=True)
    ok = r.returncode == 0
    msg = (r.stdout + r.stderr).strip()
    if ok and expected_scopes:
        missing = [s for s in expected_scopes if s not in msg]
        if missing:
            return False, f"authenticated but missing scopes: {', '.join(missing)}"
    return ok, msg

def _check_glab(host: str) -> tuple[bool, str]:
    r = subprocess.run(["glab", "auth", "status", "--hostname", host],
                       capture_output=True, text=True)
    return r.returncode == 0, (r.stdout + r.stderr).strip()

# ── Rate limiting ─────────────────────────────────────────────────────────────

def _should_run(cfg: dict, force: bool, tmp_dir: Path) -> bool:
    mode = cfg.get("mode", "never")
    if mode == "never":
        return False
    if force:
        return True
    if mode != "every_n_minutes":
        return True
    interval = int(cfg.get("interval_minutes", 60)) * 60
    flag = tmp_dir / "check-git-auth-last-run"
    if flag.exists():
        age = time.time() - flag.stat().st_mtime
        if age < interval:
            return False
    return True

def _touch_flag(tmp_dir: Path) -> None:
    flag = tmp_dir / "check-git-auth-last-run"
    flag.touch()

# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate gh/glab authentication against all git remotes."
    )
    parser.add_argument("--force", action="store_true",
                        help="Skip rate-limit check and always validate.")
    args = parser.parse_args()

    git_root_str = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
    git_root = Path(git_root_str)

    tmp_dir = Path(os.environ.get("_CONFIG_TMP_DIR", git_root / "config" / "tmp"))
    tmp_dir.mkdir(parents=True, exist_ok=True)

    full_cfg = _load_cfg(git_root)
    cfg = full_cfg.get("framework_git_config", {}).get("git-auth", {})

    if not _should_run(cfg, args.force, tmp_dir):
        return 0

    validation_type = cfg.get("validation_type", "current-repos")
    host_type_map   = cfg.get("host_type_map", {"github.com": "gh"})
    on_failure      = cfg.get("on_failure", "warn")
    gh_scopes       = cfg.get("gh_scopes", [])

    if validation_type != "current-repos":
        print(f"check-git-auth: unknown validation_type '{validation_type}', skipping.")
        return 0

    hosts = _hosts_from_git_remotes(git_root) | _hosts_from_fw_repo_mgr(git_root)
    relevant = {h: host_type_map[h] for h in hosts if h in host_type_map}

    if not relevant:
        print("check-git-auth: no known git hosts found in remotes — skipping.")
        _touch_flag(tmp_dir)
        return 0

    failures: list[str] = []
    for host, tool in sorted(relevant.items()):
        if tool == "gh":
            if not _cmd_exists("gh"):
                failures.append(f"  {host}: gh is not installed")
                continue
            ok, detail = _check_gh(host, gh_scopes)
        elif tool == "glab":
            if not _cmd_exists("glab"):
                print(f"  {host}: glab not installed — skipping (run '_setup/seed --login' after install)")
                continue
            ok, detail = _check_glab(host)
        else:
            print(f"  {host}: unknown tool '{tool}' in host_type_map — skipping")
            continue

        status = "PASS" if ok else "FAIL"
        print(f"  check-git-auth [{status}] {host} ({tool})")
        if not ok:
            failures.append(f"  {host} ({tool}): {detail.splitlines()[0] if detail else 'not authenticated'}")

    _touch_flag(tmp_dir)

    if failures:
        msg = "check-git-auth: authentication missing for:\n" + "\n".join(failures)
        msg += "\nRun: infra/pwy-home-lab-pkg/_setup/seed --login"
        if on_failure == "fail":
            print(f"ERROR: {msg}", file=sys.stderr)
            return 1
        else:
            print(f"WARNING: {msg}", file=sys.stderr)

    return 0

def _cmd_exists(name: str) -> bool:
    import shutil
    return shutil.which(name) is not None

if __name__ == "__main__":
    sys.exit(main())
```

Make executable: `chmod +x`.

---

### `infra/pwy-home-lab-pkg/_setup/run` — create

Installs `gh` and `glab`, runs `check-git-auth`, then delegates seed-style args to `./seed`.
Follows the `gcp-pkg/_setup/run` pattern exactly.

```bash
#!/bin/bash
# pwy-home-lab-pkg _setup/run — installs gh and glab; delegates seed args to ./seed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=/dev/null
. "$GIT_ROOT/set_env.sh"

_usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [--login | --seed | --test | --status | --clean | --clean-all | --help]

No arguments: install tools only.
All other flags are delegated to ./seed.
EOF
    exit 1
}

_is_debian() { [ -f /etc/debian_version ]; }
_has_brew()   { command -v brew >/dev/null 2>&1; }

_setup_gh() {
    if command -v gh >/dev/null 2>&1; then
        echo "  gh: $(gh --version | head -1)"; return
    fi
    echo "==> Installing gh..."
    if _has_brew; then
        brew install gh
    elif _is_debian; then
        sudo mkdir -p -m 755 /etc/apt/keyrings
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update -y && sudo apt-get install -y gh
    else
        echo "ERROR: unsupported platform for automatic gh install." >&2
        echo "       Install manually: https://cli.github.com" >&2
        exit 1
    fi
    echo "  gh installed: $(gh --version | head -1)"
}

_setup_glab() {
    if command -v glab >/dev/null 2>&1; then
        echo "  glab: $(glab --version | head -1)"; return
    fi
    echo "==> Installing glab..."
    if _has_brew; then
        brew install glab
    elif _is_debian; then
        # Fetch latest release tag from the GitHub API (not gitlab.com to avoid auth chicken-and-egg)
        GLAB_VERSION=$(curl -fsSL "https://api.github.com/repos/gitlab-org/cli/releases/latest" \
            | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
        GLAB_VER_NUM="${GLAB_VERSION#v}"
        curl -fsSLo /tmp/glab.deb \
            "https://github.com/gitlab-org/cli/releases/download/${GLAB_VERSION}/glab_${GLAB_VER_NUM}_linux_amd64.deb"
        sudo dpkg -i /tmp/glab.deb && rm /tmp/glab.deb
    else
        echo "ERROR: unsupported platform for automatic glab install." >&2
        echo "       Install manually: https://gitlab.com/gitlab-org/cli" >&2
        exit 1
    fi
    echo "  glab installed: $(glab --version | head -1)"
}

_check_auth() {
    python3 "$SCRIPT_DIR/check-git-auth"
}

_install_tools() {
    echo "=== pwy-home-lab-pkg setup ==="
    _setup_gh
    _setup_glab
    _check_auth
    echo "=== pwy-home-lab-pkg setup complete ==="
}

case "${1:-}" in
    -h|--help) _usage ;;
    "")        _install_tools ;;
    *)         exec "$SCRIPT_DIR/seed" "$@" ;;
esac
```

Make executable: `chmod +x`.

---

### `infra/pwy-home-lab-pkg/_setup/seed` — create

Handles interactive OAuth login for `gh` and `glab`. Auth checks delegate to `check-git-auth`.
Follows the `seed_packages()` interface: `--login`, `--seed`, `--test`, `--status`, `--clean`.

```bash
#!/bin/bash
# pwy-home-lab-pkg _setup/seed — interactive OAuth login for gh and glab.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=/dev/null
. "$GIT_ROOT/set_env.sh"

_usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") <flag>

  -l|--login      Interactive OAuth login for gh and glab
  -b|--seed       Idempotent seed (skips if already authenticated)
  -t|--test       Verify authentication (non-interactive)
  -S|--status     Show auth status
  -c|--clean      Log out of gh and glab
  -C|--clean-all  Same as --clean
  -h|--help       Print this message
EOF
    exit "${1:-1}"
}

_load_host_map() {
    # Read host_type_map from framework_git_config.yaml via Python.
    # Outputs "hostname tool" pairs, one per line.
    python3 - <<'EOF'
import os, sys, yaml
from pathlib import Path

git_root = Path(os.environ["_GIT_ROOT"])
fw_cfg_pkg = os.environ.get("_FRAMEWORK_CONFIG_PKG_DIR", "")
candidates = [git_root / "config" / "framework_git_config.yaml"]
if fw_cfg_pkg:
    candidates.append(Path(fw_cfg_pkg) / "_config" / "_framework_settings" / "framework_git_config.yaml")
candidates.append(git_root / "infra" / "_framework-pkg" / "_config" / "_framework_settings" / "framework_git_config.yaml")
for p in candidates:
    if p.exists():
        data = yaml.safe_load(open(p)) or {}
        hmap = data.get("framework_git_config", {}).get("git-auth", {}).get("host_type_map", {})
        for host, tool in hmap.items():
            print(f"{host} {tool}")
        sys.exit(0)
EOF
}

_login() {
    echo "=== pwy-home-lab-pkg: git auth login ==="
    while IFS=" " read -r host tool; do
        case "$tool" in
        gh)
            if gh auth status --hostname "$host" >/dev/null 2>&1; then
                echo "  gh ($host): already authenticated — skipping"
            else
                echo "  gh ($host): logging in..."
                gh auth login --hostname "$host" --web --git-protocol https
            fi
            ;;
        glab)
            if ! command -v glab >/dev/null 2>&1; then
                echo "  glab ($host): not installed — run '_setup/run' first" >&2; continue
            fi
            if glab auth status --hostname "$host" >/dev/null 2>&1; then
                echo "  glab ($host): already authenticated — skipping"
            else
                echo "  glab ($host): logging in..."
                glab auth login --hostname "$host"
            fi
            ;;
        esac
    done < <(_load_host_map)
    echo "=== login complete ==="
}

_seed() {
    # Idempotent: only login if not already authenticated.
    _login
}

_test() {
    python3 "$SCRIPT_DIR/check-git-auth" --force
}

_status() {
    while IFS=" " read -r host tool; do
        case "$tool" in
        gh)   command -v gh   >/dev/null 2>&1 && gh   auth status --hostname "$host" || echo "  gh ($host): not installed" ;;
        glab) command -v glab >/dev/null 2>&1 && glab auth status --hostname "$host" || echo "  glab ($host): not installed" ;;
        esac
    done < <(_load_host_map)
}

_clean() {
    while IFS=" " read -r host tool; do
        case "$tool" in
        gh)   command -v gh   >/dev/null 2>&1 && gh   auth logout --hostname "$host" || true ;;
        glab) command -v glab >/dev/null 2>&1 && glab auth logout --hostname "$host" || true ;;
        esac
    done < <(_load_host_map)
}

[[ $# -eq 0 ]] && _usage 0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--login)     _login;  shift ;;
        -b|--seed)      _seed;   shift ;;
        -t|--test)      _test;   shift ;;
        -S|--status)    _status; shift ;;
        -c|--clean)     _clean;  shift ;;
        -C|--clean-all) _clean;  shift ;;
        -h|--help)      _usage 0 ;;
        *) echo "Unknown flag: $1" >&2; _usage ;;
    esac
done
```

Make executable: `chmod +x`.

---

### `infra/pwy-home-lab-pkg/_setup/.gitkeep` — delete

No longer needed once `run`, `seed`, and `check-git-auth` are created.

---

## Execution Order

1. Create `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_git_config.yaml`
2. Create `infra/pwy-home-lab-pkg/_setup/check-git-auth` (chmod +x)
3. Create `infra/pwy-home-lab-pkg/_setup/run` (chmod +x)
4. Create `infra/pwy-home-lab-pkg/_setup/seed` (chmod +x)
5. Delete `infra/pwy-home-lab-pkg/_setup/.gitkeep`
6. Commit all files
7. Verify:
   - Run `infra/pwy-home-lab-pkg/_setup/run` — should report `gh` already present,
     install `glab`, then run the auth check
   - Run `infra/pwy-home-lab-pkg/_setup/seed --test` — should call `check-git-auth --force`
   - Run `infra/pwy-home-lab-pkg/_setup/seed --status` — should show gh authenticated

## Verification

```bash
# 1. Tool install (gh already present; glab gets installed)
infra/pwy-home-lab-pkg/_setup/run
# Expected:
#   gh: gh version 2.x.x (2024-...)
#   ==> Installing glab...
#   glab installed: glab version 1.x.x
#   check-git-auth [PASS] github.com (gh)

# 2. Forced auth check (bypasses rate limit)
infra/pwy-home-lab-pkg/_setup/check-git-auth --force
# Expected: PASS for github.com; glab hosts skipped (not authenticated yet)

# 3. Status
infra/pwy-home-lab-pkg/_setup/seed --status
# Expected: gh auth status for github.com ✓; glab not authenticated (until --login)

# 4. Interactive login (run only if glab auth is needed)
infra/pwy-home-lab-pkg/_setup/seed --login
# Expected: gh skips (already authenticated); glab opens browser for OAuth

# 5. Test after login
infra/pwy-home-lab-pkg/_setup/seed --test
# Expected: PASS for all configured hosts

# 6. Rate-limiting: run check-git-auth twice; second call should be a no-op
infra/pwy-home-lab-pkg/_setup/check-git-auth
infra/pwy-home-lab-pkg/_setup/check-git-auth
# Expected: first run checks + touches flag file; second run exits immediately (within interval)
```
