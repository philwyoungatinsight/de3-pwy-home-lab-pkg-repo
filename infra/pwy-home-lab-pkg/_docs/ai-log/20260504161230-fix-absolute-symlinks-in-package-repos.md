# Fix Absolute Symlinks in Package Repos

## Summary

Eliminated all absolute symlinks from the framework ecosystem. Three root causes were fixed:
`pkg-mgr` now creates relative `_ext_packages/` symlinks instead of absolute ones; `run --bootstrap`
now bootstraps from `de3-framework-pkg-repo` instead of the retired `de3-runner`; and six stale
committed symlinks in four package repos that still pointed to `de3-runner` were replaced with
correct targets. All package repos can now source `set_env.sh` successfully.

## Changes

- **`de3-framework-pkg-repo: infra/_framework-pkg/_framework/_pkg-mgr/pkg-mgr`** — changed `ln -sfn "$ext_clone" "$dest"` to use `os.path.relpath()` so `_ext_packages/<slug>/<ref>` symlinks are always relative
- **`de3-framework-pkg-repo: infra/_framework-pkg/_framework/_git_root/run`** — replaced `de3-runner` bootstrap with `de3-framework-pkg-repo`; also fixed symlink target path from `../../` (wrong) to `../` (correct); added logic to reuse an existing clone from `~/git/de3-ext-packages/` as a relative symlink
- **`de3-proxmox-pkg-repo`: `infra/unifi-pkg`** — replaced `de3-runner` symlink with `../_ext_packages/de3-unifi-pkg-repo/main/infra/unifi-pkg`; added `de3-unifi-pkg-repo` to `framework_package_repositories.yaml`
- **`de3-maas-pkg-repo`: `infra/unifi-pkg`** — same fix as proxmox
- **`de3-image-maker-pkg-repo`: `infra/proxmox-pkg`, `infra/unifi-pkg`** — both replaced; added `de3-proxmox-pkg-repo` and `de3-unifi-pkg-repo` to `framework_package_repositories.yaml`
- **`de3-mesh-central-pkg-repo`: `infra/proxmox-pkg`, `infra/unifi-pkg`** — same fix as image-maker
- **All 9 package repos**: ran `pkg-mgr sync` to regenerate `_ext_packages/` with relative symlinks; manually seeded `_ext_packages/de3-framework-pkg-repo/main` first to resolve the bootstrap chicken-and-egg problem

## Root Cause

`pkg-mgr`'s `_link_ext_package()` called `ln -sfn "$ext_clone" "$dest"` where `$ext_clone` was
the absolute path returned by `_external_package_dir()` (e.g. `/home/pyoung/git/de3-ext-packages/...`).
Absolute symlinks break on any machine with a different username or directory layout. The stale
`de3-runner` symlinks were a separate issue from when `de3-runner` was the combined framework repo —
they were never updated after the framework was split into separate package repos.

## Notes

Bootstrap chicken-and-egg: on a fresh clone of a package repo, `_ext_packages/` is gitignored and
doesn't exist, so `set_env.sh` (a symlink through `infra/_framework-pkg`) can't resolve. The
updated `run --bootstrap` handles this by checking for `~/git/de3-ext-packages/de3-framework-pkg-repo/main`
first and creating a relative symlink to it. New clones should run `./run --bootstrap` before
anything else to seed `_ext_packages/`.
