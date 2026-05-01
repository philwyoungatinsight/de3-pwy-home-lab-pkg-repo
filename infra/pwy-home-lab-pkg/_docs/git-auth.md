# Git Auth Setup — gh and glab

## What this does

`_setup/run` installs the GitHub CLI (`gh`) and GitLab CLI (`glab`) on the developer
machine, then checks that authentication is current for every git host used by this
repo. `_setup/git-auth` handles the interactive OAuth login step.

`_setup/git-auth-check.py` is a Python helper that runs the auth check. It reads
`framework_git_config.yaml` (see [Framework Settings](framework-settings.md)), discovers
all git hostnames from the current repo's remotes and from `framework_repo_manager.yaml`,
then calls `gh auth status` or `glab auth status` for each known host.

`_setup/seed` is a one-line shim required by the framework (`seed_packages()` discovers
`infra/*/_setup/seed` by name). It delegates all calls to `git-auth`.

## First-time setup

```bash
make setup   # installs gh and glab (calls _setup/run for every package)
make seed    # interactive OAuth login (calls _setup/git-auth --login, then --seed, then --test)
```

Both are idempotent — already-installed tools and already-authenticated hosts are skipped.

`make seed` calls `_setup/git-auth --login` automatically via the `seed` shim, so there
is no need to run it by hand after `make seed`.

## Daily use

`make build` (and `make`) calls `make setup` internally, so `_setup/run` — including
the auth check — runs on every build. The auth check is rate-limited by default
(`interval_minutes: 60`), so it only runs once per hour even if `make` is run repeatedly.

To force an immediate check outside of a build:

```bash
infra/pwy-home-lab-pkg/_setup/git-auth-check.py --force
```

## Checking status

```bash
infra/pwy-home-lab-pkg/_setup/git-auth --status
```

## Logging out

```bash
infra/pwy-home-lab-pkg/_setup/git-auth --clean
```

## Configuration

`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_git_config.yaml`
controls all behaviour. The relevant options:

| Key | Default | Effect |
|-----|---------|--------|
| `mode` | `every_n_minutes` | `never` disables automatic checks entirely |
| `interval_minutes` | `60` | How often the check runs (rate-limit window) |
| `validation_type` | `current-repos` | Scans repo remotes + `framework_repo_manager.yaml` for hostnames |
| `on_failure` | `warn` | `fail` makes the check block `./run --build` on auth failure |
| `host_type_map` | `github.com: gh` / `gitlab.com: glab` | Maps hostname → CLI tool |
| `gh_scopes` | `repo, read:org, workflow, gist` | Expected token scopes; missing ones are reported |

To add a self-hosted instance, add an entry to `host_type_map`:

```yaml
host_type_map:
  github.com: gh
  gitlab.example.com: glab
```

To override just for your machine without committing, create
`config/framework_git_config.yaml` at the git root (gitignored) with the same structure.

## How hosts are discovered

`git-auth-check.py` collects hostnames from:

1. `git remote -v` in the repo root
2. All `framework_repo_manager.yaml` files found under `infra/`:
   - `source_repo_defaults[*].url`
   - `framework_repos[*].new_repo_config.git-remotes[*].git-source`
   - `framework_repos[*].framework_packages[*].source`
   - `framework_package_template.source`

Only hosts present in `host_type_map` are checked. Unknown hosts are silently skipped.

## Tool installation details

| Tool | macOS | Debian/Ubuntu | EL (RHEL/Rocky/Alma/Fedora) |
|------|-------|---------------|------------------------------|
| `gh` | `brew install gh` | official GitHub apt repo | official GitHub dnf repo |
| `glab` | `brew install glab` | `.deb` from GitHub Releases | `.rpm` from GitHub Releases |

Both scripts detect the platform via `/etc/debian_version` (Debian family) and
`/etc/redhat-release` (EL family). `gh api` is used to fetch the latest `glab` version
tag — this avoids unauthenticated rate limits since `gh` is installed first.
