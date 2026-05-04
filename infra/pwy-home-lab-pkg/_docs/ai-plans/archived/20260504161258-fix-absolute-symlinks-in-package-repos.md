# Plan: Fix Absolute Symlinks in Package Repos

## Objective

Remove all absolute symlinks from the de3 framework ecosystem. Absolute symlinks only work on the
machine where they were created (because they embed `/home/pyoung/git/...`). Fix three root causes:
(1) `pkg-mgr` creates absolute `_ext_packages/<slug>/<ref>` symlinks on every `sync`; (2) the `run`
script's bootstrap clones the retired `de3-runner` repo instead of `de3-framework-pkg-repo`;
(3) four package repos have committed stale symlinks pointing to `de3-runner`.

## Context

### Symlink architecture (two layers)

**Layer 1 — committed to git (infra/ symlinks)** — always relative, created by `pkg-mgr`:
```
infra/_framework-pkg  →  ../_ext_packages/de3-framework-pkg-repo/main/infra/_framework-pkg
infra/unifi-pkg       →  ../_ext_packages/de3-unifi-pkg-repo/main/infra/unifi-pkg
```
These are correct (relative). Exception: 4 repos have stale `infra/unifi-pkg` and/or
`infra/proxmox-pkg` symlinks pointing to `de3-runner` (retired).

**Layer 2 — gitignored local directory (`_ext_packages/`)** — created by `pkg-mgr sync`:
```
_ext_packages/de3-framework-pkg-repo/main  →  /home/pyoung/git/de3-ext-packages/…  ← ABSOLUTE BUG
```
These resolve layer 1. Created by `pkg-mgr`'s `_link_ext_package()` function using
`ln -sfn "$ext_clone" "$dest"` where `$ext_clone` is an absolute path.

### Bootstrap problem

`./run --bootstrap` currently clones `de3-runner` (retired, inaccessible) to bootstrap the
initial `infra/_framework-pkg` symlink before `pkg-mgr sync` can run. Any fresh clone of a
package repo that runs `./run --bootstrap` will fail because `de3-runner` is gone. Should
clone `de3-framework-pkg-repo` directly instead.

### Affected files

**`pkg-mgr` absolute symlink bug** (creates absolute `_ext_packages/` symlinks):
- `de3-framework-pkg-repo/main/infra/_framework-pkg/_framework/_pkg-mgr/pkg-mgr` line 103

**`run` bootstrap uses retired `de3-runner`**:
- `de3-framework-pkg-repo/main/infra/_framework-pkg/_framework/_git_root/run` lines 46–71

**Stale committed symlinks (point to `de3-runner` instead of correct repos)**:
- `de3-proxmox-pkg-repo/main`: `infra/unifi-pkg` → `de3-runner` (should be `de3-unifi-pkg-repo`)
- `de3-maas-pkg-repo/main`: `infra/unifi-pkg` → `de3-runner` (should be `de3-unifi-pkg-repo`)
- `de3-image-maker-pkg-repo/main`: `infra/proxmox-pkg` → `de3-runner`, `infra/unifi-pkg` → `de3-runner`
- `de3-mesh-central-pkg-repo/main`: `infra/proxmox-pkg` → `de3-runner`, `infra/unifi-pkg` → `de3-runner`

**Missing `framework_package_repositories.yaml` entries** in same 4 repos (only lists `de3-framework-pkg-repo`):
- `de3-proxmox-pkg-repo`: needs `de3-unifi-pkg-repo`
- `de3-maas-pkg-repo`: needs `de3-unifi-pkg-repo`
- `de3-image-maker-pkg-repo`: needs `de3-proxmox-pkg-repo`, `de3-unifi-pkg-repo`
- `de3-mesh-central-pkg-repo`: needs `de3-proxmox-pkg-repo`, `de3-unifi-pkg-repo`

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `de3-framework-pkg-repo/main/infra/_framework-pkg/_framework/_pkg-mgr/pkg-mgr` — modify

**Change line 103** to create a relative symlink instead of absolute.

```bash
# BEFORE (line 102-104):
  mkdir -p "$EXT_PACKAGES_DIR/$slug"
  ln -sfn "$ext_clone" "$dest"
  echo "Linked: _ext_packages/$slug/$ref_dir -> $ext_clone"

# AFTER:
  mkdir -p "$EXT_PACKAGES_DIR/$slug"
  local rel_target
  rel_target=$(python3 -c "import os.path; print(os.path.relpath('$ext_clone', os.path.dirname('$dest')))")
  ln -sfn "$rel_target" "$dest"
  echo "Linked: _ext_packages/$slug/$ref_dir -> $rel_target (relative)"
```

### `de3-framework-pkg-repo/main/infra/_framework-pkg/_framework/_git_root/run` — modify

**Change lines 46–71** to bootstrap from `de3-framework-pkg-repo` instead of `de3-runner`.

```python
# BEFORE (lines 46-71):
_DE3_RUNNER_URL = 'https://github.com/philwyoungatinsight/de3-runner.git'
_DE3_RUNNER_REF = 'main'

def _bootstrap():
    """Clone/update de3-runner and create the infra/_framework-pkg symlink."""
    clone_dir = _GIT_ROOT / '_ext_packages' / 'de3-runner' / _DE3_RUNNER_REF
    link      = _GIT_ROOT / 'infra' / '_framework-pkg'
    ...
    target = Path('../..') / '_ext_packages' / 'de3-runner' / _DE3_RUNNER_REF / 'infra' / '_framework-pkg'
    ...

# AFTER:
_FRAMEWORK_PKG_REPO_URL = 'https://github.com/philwyoungatinsight/de3-framework-pkg-repo.git'
_FRAMEWORK_PKG_REPO_REF = 'main'
_FRAMEWORK_PKG_REPO_SLUG = 'de3-framework-pkg-repo'

def _bootstrap():
    """Clone/update de3-framework-pkg-repo and create the infra/_framework-pkg symlink."""
    clone_dir = _GIT_ROOT / '_ext_packages' / _FRAMEWORK_PKG_REPO_SLUG / _FRAMEWORK_PKG_REPO_REF
    link      = _GIT_ROOT / 'infra' / '_framework-pkg'
    clone_dir.parent.mkdir(parents=True, exist_ok=True)
    if not clone_dir.exists():
        # Check if it's already cloned in the external_package_dir (~/git/de3-ext-packages)
        import os
        home = pathlib.Path.home()
        ext_clone = home / 'git' / 'de3-ext-packages' / _FRAMEWORK_PKG_REPO_SLUG / _FRAMEWORK_PKG_REPO_REF
        if ext_clone.exists():
            # Create relative symlink from _ext_packages/de3-framework-pkg-repo/ to ext_clone
            rel = os.path.relpath(str(ext_clone), str(clone_dir.parent))
            clone_dir.parent.mkdir(parents=True, exist_ok=True)
            if clone_dir.is_symlink():
                clone_dir.unlink()
            clone_dir.symlink_to(rel)
        else:
            print('==> Bootstrapping _framework-pkg from de3-framework-pkg-repo...')
            subprocess.run(
                ['git', 'clone', '--branch', _FRAMEWORK_PKG_REPO_REF,
                 _FRAMEWORK_PKG_REPO_URL, str(clone_dir)],
                check=True,
            )
    else:
        if not clone_dir.is_symlink():
            subprocess.run(['git', '-C', str(clone_dir), 'pull', '--ff-only'], check=False)
    # Relative symlink: infra/_framework-pkg → ../_ext_packages/de3-framework-pkg-repo/main/infra/_framework-pkg
    target = Path('..') / '_ext_packages' / _FRAMEWORK_PKG_REPO_SLUG / _FRAMEWORK_PKG_REPO_REF / 'infra' / '_framework-pkg'
    if link.is_symlink():
        link.unlink()
    elif link.exists():
        raise RuntimeError(f'{link} exists and is not a symlink — cannot bootstrap')
    link.parent.mkdir(parents=True, exist_ok=True)
    link.symlink_to(target)
    print('==> Bootstrap complete.')
```

Note: Also add `import pathlib` and `import os` at the top if not already present. The path is ONE level up (`../_ext_packages/...`) not two — the original `../../` was a bug.

### `de3-proxmox-pkg-repo/main` — modify 2 files

**File 1**: `infra/proxmox-pkg/_config/_framework_settings/framework_package_repositories.yaml`

```yaml
# BEFORE:
framework_package_repositories:
  - name: de3-framework-pkg-repo
    url: https://github.com/philwyoungatinsight/de3-framework-pkg-repo.git

# AFTER:
framework_package_repositories:
  - name: de3-framework-pkg-repo
    url: https://github.com/philwyoungatinsight/de3-framework-pkg-repo.git
  - name: de3-unifi-pkg-repo
    url: https://github.com/philwyoungatinsight/de3-unifi-pkg-repo.git
```

**File 2**: Fix committed symlink `infra/unifi-pkg`:
```bash
git -C <repo> rm infra/unifi-pkg
ln -s ../_ext_packages/de3-unifi-pkg-repo/main/infra/unifi-pkg de3-proxmox-pkg-repo/main/infra/unifi-pkg
git -C <repo> add infra/unifi-pkg
```

### `de3-maas-pkg-repo/main` — modify 2 files

Same pattern as proxmox:

**File 1**: `infra/maas-pkg/_config/_framework_settings/framework_package_repositories.yaml` — add `de3-unifi-pkg-repo`.

**File 2**: Fix `infra/unifi-pkg` symlink from `de3-runner` to `de3-unifi-pkg-repo/main`.

### `de3-image-maker-pkg-repo/main` — modify 2 files

**File 1**: `infra/image-maker-pkg/_config/_framework_settings/framework_package_repositories.yaml` — add `de3-proxmox-pkg-repo` and `de3-unifi-pkg-repo`.

**File 2**: Fix both `infra/proxmox-pkg` and `infra/unifi-pkg` symlinks.

### `de3-mesh-central-pkg-repo/main` — modify 2 files

**File 1**: `infra/mesh-central-pkg/_config/_framework_settings/framework_package_repositories.yaml` — add `de3-proxmox-pkg-repo` and `de3-unifi-pkg-repo`.

**File 2**: Fix both `infra/proxmox-pkg` and `infra/unifi-pkg` symlinks.

### `de3-pwy-home-lab-pkg-repo` — update CLAUDE.md

Add a rule to the Conventions section:

```markdown
- **No absolute symlinks**: All symlinks in the repo — committed or otherwise — must use
  relative paths. Absolute symlinks (`/home/user/...`) break on any machine that isn't the
  original creator's. When creating symlinks in scripts or manually: compute a relative path
  with `os.path.relpath(target, symlink_dir)` (Python) or `realpath --relative-to` (bash).
  `pkg-mgr` enforces this for `_ext_packages/` — never override it with a hardcoded absolute path.
```

Also add this rule to `de3-framework-pkg-repo/main/infra/_framework-pkg/_framework/_git_root/CLAUDE.md`
and the ai-screw-ups log.

## Execution Order

1. **Fix `pkg-mgr`** (line 103, relative symlink creation) in `de3-framework-pkg-repo` — commit.
2. **Fix `run --bootstrap`** (de3-runner → de3-framework-pkg-repo) in `de3-framework-pkg-repo` — commit.
3. **Fix `framework_package_repositories.yaml`** in 4 repos — commit each.
4. **Fix stale committed symlinks** in 4 repos via `git rm` + `ln -s` + `git add` — commit each.
5. **Regenerate `_ext_packages/`** in all package repos: run `pkg-mgr sync` from each repo's git root (after fixing pkg-mgr, the new symlinks will be relative).
6. **Update CLAUDE.md** in `pwy-home-lab-pkg-repo` and the ai-screw-ups log — commit.
7. **Push** all repos via `gpa` (run from each repo dir).

## Verification

After execution, verify from each package repo:

```bash
# 1. _ext_packages symlinks should be relative
readlink /home/pyoung/git/de3-ext-packages/de3-aws-pkg-repo/main/_ext_packages/de3-framework-pkg-repo/main
# Expected: ../../../../de3-framework-pkg-repo/main  (relative, no /home/...)

# 2. No absolute symlinks anywhere under _ext_packages
find /home/pyoung/git/de3-ext-packages/*/main/_ext_packages -type l | while read f; do
  t=$(readlink "$f"); [[ "$t" = /* ]] && echo "ABSOLUTE: $f -> $t"
done
# Expected: no output

# 3. infra/unifi-pkg and infra/proxmox-pkg in affected repos point to correct repos
readlink /home/pyoung/git/de3-ext-packages/de3-maas-pkg-repo/main/infra/unifi-pkg
# Expected: ../_ext_packages/de3-unifi-pkg-repo/main/infra/unifi-pkg

# 4. set_env.sh resolves from each package repo
bash -c 'cd /home/pyoung/git/de3-ext-packages/de3-aws-pkg-repo/main && source set_env.sh && echo OK'
# Expected: OK (no "not found" errors)

# 5. pwy-home-lab-pkg-repo _ext_packages are also relative after re-running pkg-mgr sync
readlink /home/pyoung/git/de3-pwy-home-lab-pkg-repo/_ext_packages/de3-framework-pkg-repo/main
# Expected: ../../../de3-ext-packages/de3-framework-pkg-repo/main  (relative)
```
