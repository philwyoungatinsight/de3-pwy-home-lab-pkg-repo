# Plan: fw-repo-mgr status — replace UPSTREAM with per-remote REMOTE-<name> columns

## Objective

Replace the single `UPSTREAM` column in `fw-repo-mgr --status` output with one column per
configured git remote, labeled `REMOTE-<clipped-name>` (e.g. `REMOTE-origin`, `REMOTE-gitlab`).
The clip length for the remote name is controlled by a new `status_remote_name_max_len`
parameter in `framework_repo_manager.yaml`.

## Context

### Current behaviour

`status_cmd()` at line 769 of `fw-repo-mgr` shows only the first remote's git-source URL
under a single `UPSTREAM` column:

```python
upstream   = remotes[0].get("git-source", "") if remotes else ""
upstream   = upstream.replace("https://github.com/", "github.com/")
```

Table header (line 805):
```
NAME                           LOCAL  REMOTES  GIT STATUS             UPSTREAM
```

JSON/YAML rows carry `"upstream": "<url>"`.

### Real data

Every repo in the deployment config has exactly two remotes:
```yaml
git-remotes:
  - name: origin
    git-source: https://github.com/philwyoungatinsight/<repo>.git
  - name: gitlab
    git-source: git@gitlab.com:pwyoung/<repo>.git
```

GitHub URLs after normalization: `github.com/philwyoungatinsight/<repo>.git` (~50 chars).
GitLab URLs: `git@gitlab.com:pwyoung/<repo>.git` (~35 chars).

### Files to change

Both files live in the **de3-runner** external package (not pwy-home-lab-pkg directly):

| File | Path |
|------|------|
| Script | `/home/pyoung/git/de3-ext-packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` |
| Framework default config | `/home/pyoung/git/de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` |
| Version capability | `/home/pyoung/git/de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/_framework-pkg.yaml` |
| Version history | `/home/pyoung/git/de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/version_history.md` |

Changes are automatically visible in pwy-home-lab-pkg via the symlink:
`infra/_framework-pkg → _ext_packages/de3-runner/main/infra/_framework-pkg`

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `fw-repo-mgr` — modify (de3-runner)

**1. Add `Config.status_remote_name_max_len()` accessor** (after the `ext_pkg_base` method, ~line 184):

```python
def status_remote_name_max_len(self) -> int:
    return int(self.fm.get("status_remote_name_max_len", 6))
```

**2. Replace `status_cmd()` entirely** (lines 769–814). New implementation:

```python
def status_cmd(cfg: Config, fmt: Optional[str] = None) -> None:
    repo_base = cfg.fw_repo_base_dir()
    max_len   = cfg.status_remote_name_max_len()

    def _clip(s: str) -> str:
        return s[:max_len]

    def _norm_url(url: str) -> str:
        return url.replace("https://github.com/", "github.com/")

    # Collect all unique remote names across all repos (insertion order).
    all_remote_names: list = []
    seen: set = set()
    for r in cfg.list_repos():
        for rem in (r.get("new_repo_config") or {}).get("git-remotes", []):
            n = rem.get("name", "")
            if n and n not in seen:
                all_remote_names.append(n)
                seen.add(n)

    rows = []
    for r in cfg.list_repos():
        name       = r.get("name", "")
        pkgs       = len(r.get("framework_packages", []))
        remotes    = (r.get("new_repo_config") or {}).get("git-remotes", [])
        local_only = bool(r.get("local_only"))
        repo_dir   = repo_base / name if repo_base else pathlib.Path(name)

        local_dir_exists  = (repo_dir / ".git").exists()
        all_remotes_exist = None if local_only else _check_remotes_exist(remotes)
        git_status        = _get_git_status(repo_dir) if local_dir_exists else "not cloned"
        remotes_map       = {
            rem["name"]: _norm_url(rem.get("git-source", ""))
            for rem in remotes if "name" in rem
        }

        rows.append({
            "name":             name,
            "local_path":       str(repo_dir).replace(str(pathlib.Path.home()), "~"),
            "packages":         pkgs,
            "remotes":          remotes_map,
            "local_only":       local_only,
            "local_dir_exists": local_dir_exists,
            "all_remotes_exist": all_remotes_exist,
            "git_status":       git_status,
        })

    if fmt == "json":
        print(json.dumps(rows, indent=2))
    elif fmt == "yaml":
        print(yaml.dump(rows, default_flow_style=False, sort_keys=False), end="")
    else:
        def _yn(val) -> str:
            if val is None: return "—"
            return "✓" if val else "✗"

        remote_headers = [f"REMOTE-{_clip(n)}" for n in all_remote_names]
        # Fixed width for non-last remote columns; last column is unbounded.
        COL_URL_W = 55
        col_widths = [max(len(h), COL_URL_W) for h in remote_headers]

        fixed_hdr = f"{'NAME':<30} {'LOCAL':<6} {'REMOTES':<8} {'GIT STATUS':<22}"
        fixed_sep = f"{'----':<30} {'-----':<6} {'-------':<8} {'----------':<22}"

        rem_hdr_parts = []
        rem_sep_parts = []
        for i, (h, w) in enumerate(zip(remote_headers, col_widths)):
            if i < len(remote_headers) - 1:
                rem_hdr_parts.append(f"{h:<{w}}")
                rem_sep_parts.append(f"{'-' * len(h):<{w}}")
            else:
                rem_hdr_parts.append(h)
                rem_sep_parts.append("-" * len(h))

        print(f"{fixed_hdr} {' '.join(rem_hdr_parts)}".rstrip())
        print(f"{fixed_sep} {' '.join(rem_sep_parts)}".rstrip())

        for row in rows:
            st = row["git_status"]
            if row["local_only"]:
                st += " (local-only)"
            fixed_part = (
                f"{row['name']:<30} {_yn(row['local_dir_exists']):<6} "
                f"{_yn(row['all_remotes_exist']):<8} {st:<22}"
            )
            rmap = row["remotes"]
            url_parts = []
            for i, (n, w) in enumerate(zip(all_remote_names, col_widths)):
                url = rmap.get(n, "")
                if i < len(all_remote_names) - 1:
                    url_parts.append(f"{url:<{w}}")
                else:
                    url_parts.append(url)
            print(f"{fixed_part} {' '.join(url_parts)}".rstrip())
```

### `framework_repo_manager.yaml` (tier 3, de3-runner) — modify

Add after the `framework_repo_dir` line (~line 9), before `source_repo_defaults`:

```yaml
  # Maximum characters of a remote name shown as the status table column header.
  # "REMOTE-<name>" — the <name> part is clipped to this length.
  # e.g. 6 → "origin" stays "origin"; 4 → "origin" clips to "orig"
  status_remote_name_max_len: 6
```

### `_framework-pkg.yaml` (de3-runner) — modify

Bump `_framework-pkg` from `1.21.0` to `1.22.0`:

```yaml
_framework-pkg:
  _provides_capability:
  - _framework-pkg: 1.22.0
```

### `version_history.md` (de3-runner) — modify

Prepend new entry (use `git rev-parse --short HEAD` taken **after** the commit):

```markdown
## 1.22.0  (2026-04-30, git: <sha>)
- fw-repo-mgr status: replace UPSTREAM column with per-remote REMOTE-<name> columns; clip length controlled by status_remote_name_max_len in framework_repo_manager.yaml
```

## Execution Order

1. Edit `fw-repo-mgr` — add accessor + replace `status_cmd()`
2. Edit `framework_repo_manager.yaml` (tier 3) — add `status_remote_name_max_len: 6`
3. Edit `_framework-pkg.yaml` — bump version to `1.22.0`
4. Commit to de3-runner (`git -C /home/pyoung/git/de3-ext-packages/de3-runner/main commit`)
5. Edit `version_history.md` — prepend entry with post-commit sha
6. Commit version_history amendment to de3-runner
7. Commit plan file to pwy-home-lab-pkg

## Verification

```bash
# Source env, then run status:
source /home/pyoung/git/pwy-home-lab-pkg/set_env.sh
fw-repo-mgr --status

# Expected output columns:
# NAME  LOCAL  REMOTES  GIT STATUS  REMOTE-origin  REMOTE-gitlab
# Each repo row shows both GitHub and GitLab URLs instead of one UPSTREAM URL.

# JSON output — confirm remotes dict, not upstream string:
fw-repo-mgr --status --format json | python3 -c "import json,sys; r=json.load(sys.stdin); print(list(r[0].keys()))"
# Expected: [..., 'remotes', ...]  (no 'upstream' key)

# Verify clip at non-default length by temporarily setting status_remote_name_max_len: 4
# in config/framework_repo_manager.yaml (ad-hoc tier 1) — headers should show REMOTE-orig, REMOTE-gitl
```
