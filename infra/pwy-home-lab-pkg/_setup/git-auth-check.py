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
import shutil
import subprocess
import sys
import time
import yaml
from pathlib import Path
from urllib.parse import urlparse


# ── 3-tier settings lookup ────────────────────────────────────────────────────

def _load_cfg(git_root: Path) -> dict:
    """Load framework_git_config.yaml via 3-tier lookup."""
    fw_cfg_pkg = os.environ.get("_FRAMEWORK_CONFIG_PKG_DIR", "")

    candidates = [
        git_root / "config" / "framework_git_config.yaml",
    ]
    if fw_cfg_pkg:
        candidates.append(
            Path(fw_cfg_pkg) / "_config" / "_framework_settings" / "framework_git_config.yaml"
        )
    candidates.append(
        git_root / "infra" / "_framework-pkg" / "_config" / "_framework_settings" / "framework_git_config.yaml"
    )

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
    """Extract hostnames from framework_repo_manager.yaml (all packages).

    Structure:
      source_repo_defaults: list of {name, url, ref}
      framework_repos[*].new_repo_config.git-remotes: list of {name, git-source, git-ref}
      framework_repos[*].framework_packages[*].source: str URL (optional)
      framework_package_template.source: str URL
    """
    hosts: set[str] = set()
    pattern = "infra/**/_config/_framework_settings/framework_repo_manager.yaml"
    for yml_path in git_root.glob(pattern):
        try:
            with open(yml_path) as f:
                data = yaml.safe_load(f) or {}
        except Exception:
            continue
        mgr = data.get("framework_repo_manager", {})

        # source_repo_defaults: list of {name, url, ref}
        for item in mgr.get("source_repo_defaults", []):
            if isinstance(item, dict):
                h = _parse_host(str(item.get("url", "")))
                if h:
                    hosts.add(h)

        # framework_repos[*]
        for repo in mgr.get("framework_repos", []):
            # new_repo_config.git-remotes: list of {name, git-source, git-ref}
            # Skip for local_only repos — those remotes don't exist yet.
            if not repo.get("local_only"):
                for remote in repo.get("new_repo_config", {}).get("git-remotes", []):
                    if isinstance(remote, dict):
                        h = _parse_host(str(remote.get("git-source", "")))
                        if h:
                            hosts.add(h)
            # framework_packages[*].source: str URL (optional) — always needed for pkg-mgr sync
            for pkg in repo.get("framework_packages", []):
                src = pkg.get("source", "") if isinstance(pkg, dict) else ""
                if src:
                    h = _parse_host(str(src))
                    if h:
                        hosts.add(h)

        # framework_package_template.source: str URL
        tpl_src = mgr.get("framework_package_template", {}).get("source", "")
        if tpl_src:
            h = _parse_host(str(tpl_src))
            if h:
                hosts.add(h)

    return hosts


# ── Auth checks ───────────────────────────────────────────────────────────────

def _check_gh(host: str, expected_scopes: list[str]) -> tuple[bool, str]:
    r = subprocess.run(
        ["gh", "auth", "status", "--hostname", host],
        capture_output=True, text=True
    )
    ok = r.returncode == 0
    msg = (r.stdout + r.stderr).strip()
    if ok and expected_scopes:
        missing = [s for s in expected_scopes if s not in msg]
        if missing:
            return False, f"authenticated but missing scopes: {', '.join(missing)}"
    return ok, msg


def _check_glab(host: str) -> tuple[bool, str]:
    r = subprocess.run(
        ["glab", "auth", "status", "--hostname", host],
        capture_output=True, text=True
    )
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
    (tmp_dir / "check-git-auth-last-run").touch()


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate gh/glab authentication against all git remotes."
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Skip rate-limit check and always validate."
    )
    args = parser.parse_args()

    git_root_str = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
    git_root = Path(git_root_str)

    tmp_dir = Path(os.environ.get("_CONFIG_TMP_DIR", str(git_root / "config" / "tmp")))
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
            if not shutil.which("gh"):
                failures.append(f"  {host}: gh is not installed")
                continue
            ok, detail = _check_gh(host, gh_scopes)
        elif tool == "glab":
            if not shutil.which("glab"):
                print(f"  {host}: glab not installed — skipping (run '_setup/seed --login' after install)")
                continue
            ok, detail = _check_glab(host)
        else:
            print(f"  {host}: unknown tool '{tool}' in host_type_map — skipping")
            continue

        status = "PASS" if ok else "FAIL"
        print(f"  check-git-auth [{status}] {host} ({tool})")
        if not ok:
            first_line = detail.splitlines()[0] if detail else "not authenticated"
            failures.append(f"  {host} ({tool}): {first_line}")

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


if __name__ == "__main__":
    sys.exit(main())
