# Plan: Extract wave-mgr + Simplify Top-Level Makefile and run Script

## Objective

Refactor the top-level `run` script and `Makefile` so that concern separation is clear:
- **`wave-mgr`**: new framework tool in `_framework/_wave-mgr/wave-mgr` — owns all wave execution logic
- **`run`**: thin framework orchestrator — handles bootstrap (de3-runner clone), package management, and delegates wave operations to `wave-mgr`
- **Top-level `Makefile`**: simplified to just call `./run` — no longer delegates through the framework Makefile, no longer contains bootstrap logic

## Context

**Current architecture:**
- Top-level `Makefile` contains bootstrap logic (clone de3-runner, create `infra/_framework-pkg` symlink) and delegates `build/clean/setup/seed/test` to `infra/_framework-pkg/_framework/_git_root/Makefile`
- Framework Makefile calls `./run --<flag>` (where `./run` is the consumer-repo top-level script)
- Top-level `run` (~1160 line Python script) handles everything: wave running, package management, config loading, logging
- `_git_root/run` and `_git_root/set_env.sh` are identical to their top-level counterparts — they are templates that `fw-repo-mgr` uses when bootstrapping new consumer repos
- `set_env.sh` exports `_PKG_MGR`, `_UNIT_MGR`, `_EPHEMERAL`, `_CLEAN_ALL`, `_FW_REPO_MGR`, `_CONFIG_MGR` — no `_WAVE_MGR` yet

**Division of responsibilities:**

| Concern | Current home | New home |
|---------|-------------|----------|
| Clone de3-runner, create `infra/_framework-pkg` symlink | `Makefile` `bootstrap` target | `run --bootstrap` (auto-runs inside `--build`) |
| `--apply`, `--test`, `--clean`, `--clean-all` | `run` | `wave-mgr` |
| `--unlock-gcs`, `--list-waves`, `--list-waves-status` | `run` | `wave-mgr` |
| `--app` (find `_application/<name>` and `make`) | `run` | `wave-mgr` |
| Wave filters: `-w`, `-n`, `-N`, `-M`, `-s`, `-i`, `-f` | `run` | `wave-mgr` |
| `--sync-packages`, `--setup-packages`, `--seed-packages`, `--ensure-backend` | `run` | `run` (unchanged) |
| `--build` (full orchestration) | `run` (setup+backend+waves) | `run` (bootstrap+sync+setup+backend+calls `wave-mgr --apply`) |

**`_git_root` templates:** The `_git_root/run` template does NOT get bootstrap logic (new repos have `_framework-pkg` set up by `fw-repo-mgr` already). It gets a new thin-wrapper `run` that delegates to `wave-mgr`. The `_git_root/Makefile` is already correct (calls `./run --X`) so it stays unchanged.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/_framework-pkg/_framework/_wave-mgr/wave-mgr` — create

New executable Python script. Contains all wave-execution logic extracted from the current `run` script.

**CLI flags to include (wave-specific only):**
- `-a`/`--apply`: apply all waves + tests
- `-t`/`--test`: test all waves (no apply)
- `-c`/`--clean`: destroy waves (reverse order)
- `-C`/`--clean-all`: nuclear cleanup via `clean-all` script
- `-u`/`--unlock-gcs`: delete all stale GCS locks
- `-l`/`--list-waves`: print wave table
- `-L`/`--list-waves-status`: print wave table with run status
- `-A`/`--app NAME`: find `_application/<NAME>` and run `make`
- `-w PATTERN`, `-n N`, `-N N`, `-M N`: wave selection filters
- `-s`/`--skip-test`, `-i`/`--ignore-errors`, `-f FORMAT`: modifiers

**NOT in wave-mgr:**
- `--bootstrap` (run only)
- `-b`/`--build` (run only — it orchestrates more than just waves)
- `-Y`/`--sync-packages`, `-S`/`--setup-packages`, `-P`/`--seed-packages`, `-e`/`--ensure-backend` (run only)

**Functions to include (copy from `run` verbatim):**
- `_source_env()`, `_run_validate_config()`
- `_Tee`, `setup_logging()`
- `_stream()`
- `load_all_configs()`, `load_waves()`, `validate_packages()`, `get_gcs_bucket()`, `get_wave_unit_prefixes()`
- `unlock_all_gcs_locks()`, `unlock_wave_locks()`
- `run_tg()`, `run_ansible_playbook()`, `update_inventory()`
- `ensure_backend()` — keep in wave-mgr so `--build` can call it if wave-mgr is invoked standalone... **wait**: actually `ensure_backend` moves to `run`. wave-mgr does NOT call `ensure_backend` — that is `run`'s job.
- `seed_packages()`, `sync_packages()`, `setup_packages()` — NOT in wave-mgr
- `_fmt_duration()`, `_scan_wave_statuses()`, `list_waves()`
- `find_application()`
- `parse_args()`, `main()` — updated to only handle wave flags
- `__main__` guard

**`GENERATE_INVENTORY` path** in wave-mgr:
```python
GENERATE_INVENTORY = FRAMEWORK_PKG_DIR / '_framework/_generate-inventory/run'
NUKE_ALL           = Path(ENV['_CLEAN_ALL'])
_VALIDATE_CONFIG_PY = FRAMEWORK_PKG_DIR / '_framework/_utilities/python/validate-config.py'
_EPHEMERAL_RUN      = Path(ENV['_EPHEMERAL'])
```
(`PKG_MGR` and `INIT_SH` are no longer needed in wave-mgr since `sync_packages`, `setup_packages`, `ensure_backend` live in `run`.)

**`parse_args()` in wave-mgr** — remove `-b/--build`, `-Y/--sync-packages`, `-S/--setup-packages`, `-P/--seed-packages`, `-e/--ensure-backend`. Keep all wave flags.

**No-arg behavior**: print help and exit 0 (same as current `run`).

---

### `set_env.sh` (top-level) — modify

Add `_WAVE_MGR` export immediately after `_CLEAN_ALL`:

```bash
export _CLEAN_ALL="$_FRAMEWORK_DIR/_clean_all/clean-all"           # nuclear destroy + state wipe
export _WAVE_MGR="$_FRAMEWORK_DIR/_wave-mgr/wave-mgr"             # wave runner (apply/test/clean/list)
export _FW_REPO_MGR="$_FRAMEWORK_DIR/_fw-repo-mgr/fw-repo-mgr"   # initialize/manage consumer repos
```

---

### `infra/_framework-pkg/_framework/_git_root/set_env.sh` — modify

Same change as `set_env.sh` above (this is the template copy).

---

### `run` (top-level) — replace

Becomes a thin orchestration wrapper. Bootstrap logic moves here from the Makefile.

```python
#!/usr/bin/env python3
"""
Lab Stack entry point — orchestrates bootstrap, package management, and waves.

USAGE
  ./run --bootstrap                       ensure infra/_framework-pkg symlink is in place
  ./run -b|--build [wave-mgr opts]        bootstrap + sync-packages + setup-packages +
                                          ensure-backend + wave-mgr --apply [wave-mgr opts]
  ./run -Y|--sync-packages               clone/link external package repos (idempotent)
  ./run -S|--setup-packages              run per-package setup scripts (idempotent)
  ./run -P|--seed-packages               login + seed + test all cloud packages
  ./run -e|--ensure-backend              bootstrap backend if not present

  All other flags are passed through to wave-mgr:
  ./run -a|--apply [wave-mgr opts]
  ./run -c|--clean [wave-mgr opts]
  ./run -C|--clean-all
  ./run -t|--test [wave-mgr opts]
  ./run -l|--list-waves [wave-mgr opts]
  ./run -L|--list-waves-status
  ./run -u|--unlock-gcs
  ./run -w PATTERN / -n N / -N N / -M N
  ./run -A|--app NAME
  ./run -s / -i / -f FORMAT
"""
```

**Bootstrap constants** (at top of file, after imports):
```python
_DE3_RUNNER_URL  = 'https://github.com/philwyoungatinsight/de3-runner.git'
_DE3_RUNNER_REF  = 'main'
```

**Bootstrap function** (runs before `_source_env()` is called, so no `ENV` dependency):
```python
def _bootstrap():
    clone_dir = _GIT_ROOT / '_ext_packages' / 'de3-runner' / _DE3_RUNNER_REF
    link      = _GIT_ROOT / 'infra' / '_framework-pkg'
    clone_dir.parent.mkdir(parents=True, exist_ok=True)
    if not clone_dir.exists():
        print(f'==> Bootstrapping _framework-pkg from de3-runner...')
        subprocess.run(
            ['git', 'clone', '--branch', _DE3_RUNNER_REF, _DE3_RUNNER_URL, str(clone_dir)],
            check=True,
        )
    else:
        subprocess.run(['git', '-C', str(clone_dir), 'pull', '--ff-only'], check=False)
    # Relative symlink: infra/_framework-pkg → ../../_ext_packages/de3-runner/main/infra/_framework-pkg
    target = Path('../..') / '_ext_packages' / 'de3-runner' / _DE3_RUNNER_REF / 'infra' / '_framework-pkg'
    if link.is_symlink():
        link.unlink()
    elif link.exists():
        raise RuntimeError(f'{link} exists and is not a symlink — cannot bootstrap')
    link.parent.mkdir(parents=True, exist_ok=True)
    link.symlink_to(target)
    print('==> Bootstrap complete.')
```

**Auto-bootstrap before `_source_env()`** (at module level, before `ENV = _source_env()`):
```python
_FRAMEWORK_PKG_LINK = _GIT_ROOT / 'infra' / '_framework-pkg'
if not _FRAMEWORK_PKG_LINK.exists():
    _bootstrap()
```

**`_source_env()` and `ENV`** — keep identical to current `run`.

**`_run_validate_config()`** — keep identical to current `run`.

**Module-level setup functions** — keep `sync_packages()`, `setup_packages()`, `seed_packages()`, `ensure_backend()` verbatim from current `run`. These use `PKG_MGR`, `INIT_SH`, `INFRA_DIR` — all available after `ENV = _source_env()`.

**Wave delegation helper:**
```python
WAVE_MGR = Path(ENV['_WAVE_MGR'])

def _delegate_to_wave_mgr(argv: list):
    """Run wave-mgr with the given argv and exit with its return code."""
    result = subprocess.run([str(WAVE_MGR)] + argv, env=ENV)
    sys.exit(result.returncode)
```

**`parse_args()` in `run`** — minimal parser: only handles flags `run` owns. Anything else is passed through to wave-mgr.

```python
def parse_args():
    p = argparse.ArgumentParser(prog='./run', add_help=True)
    p.add_argument('--bootstrap',         action='store_true', help='ensure infra/_framework-pkg symlink is in place')
    p.add_argument('-b', '--build',       action='store_true', help='bootstrap + sync + setup + backend + apply waves')
    p.add_argument('-Y', '--sync-packages',  action='store_true', dest='sync_packages')
    p.add_argument('-S', '--setup-packages', action='store_true', dest='setup_packages')
    p.add_argument('-P', '--seed-packages',  action='store_true', dest='seed_packages')
    p.add_argument('-e', '--ensure-backend', action='store_true', dest='ensure_backend')
    p.add_argument('-i', '--ignore-errors',  action='store_true', dest='ignore_errors')
    # All other args are captured and passed to wave-mgr
    args, wave_args = p.parse_known_args()
    return args, wave_args
```

**`main()` in `run`:**
```python
def main():
    args, wave_args = parse_args()

    if args.bootstrap:
        _bootstrap()
        return

    if args.sync_packages and not args.build:
        sync_packages(); return
    if args.setup_packages and not args.build:
        setup_packages(); return
    if args.seed_packages:
        seed_packages(); return
    if args.ensure_backend and not args.build:
        ensure_backend(); return

    if args.build:
        # Full orchestration: bootstrap check already happened at import time
        if args.sync_packages or not wave_args:  # --build alone implies sync
            sync_packages()
        setup_packages()
        ensure_backend()
        # Delegate wave apply to wave-mgr (pass any wave-selection flags)
        _delegate_to_wave_mgr(['--apply'] + wave_args)
        return

    # Everything else: pass through to wave-mgr unchanged
    if wave_args or any(vars(args).values()):
        raw = sys.argv[1:]  # re-pass original argv
        # strip run-owned flags before delegating
        filtered = [a for a in raw if a not in ('--bootstrap',)]
        _delegate_to_wave_mgr(filtered)
    else:
        subprocess.run([str(WAVE_MGR), '--help'])
```

**Note on `--build` and wave-args**: when `./run --build -w on_prem.maas.*` is called, `run` does sync+setup+ensure-backend, then calls `wave-mgr --apply -w on_prem.maas.*`. This preserves the existing behavior of `./run --build -w <filter>`.

**Note on `--build -s`/`--build -N 5` etc.**: `wave_args` captures everything not parsed by `run`'s parser, so these pass through correctly.

---

### `infra/_framework-pkg/_framework/_git_root/run` — replace

Template for new consumer repos. Contains the same thin-wrapper `run` but **without bootstrap logic** (new repos created by `fw-repo-mgr` already have `_framework-pkg` set up).

Remove: `_DE3_RUNNER_URL`, `_DE3_RUNNER_REF`, `_bootstrap()`, auto-bootstrap check.

Keep: `_source_env()`, `_run_validate_config()`, `sync_packages()`, `setup_packages()`, `seed_packages()`, `ensure_backend()`, `parse_args()` (framework flags only), `main()`, wave-delegation to `_WAVE_MGR`.

The template `run` is otherwise structurally identical to the consumer `run`, just missing the de3-runner bootstrap.

---

### `Makefile` (top-level) — replace

Remove: bootstrap target, `FRAMEWORK_MAKEFILE` variable, `_require_framework` guard, `DE3_RUNNER_URL/REF/CLONE/FRAMEWORK_PKG_LINK` variables, delegation to framework Makefile.

New content:
```makefile
.PHONY: all bootstrap build clean clean-all setup seed test

# Full first-time setup + full build. Bootstrap is automatic inside './run --build'.
all: build

# Explicit bootstrap (idempotent): clone/update de3-runner and create infra/_framework-pkg symlink.
bootstrap:
	@./run --bootstrap

build:
	@./run --sync-packages
	@./run --build

clean:
	@./run --clean

clean-all:
	@./run --clean-all

setup:
	@./run --setup-packages

seed:
	@./run --seed-packages

test:
	@./run --test
```

Note: `make build` still calls `--sync-packages` before `--build` for parity with the current framework Makefile behavior. If `--build` should auto-sync, that can be a follow-up.

---

## Execution Order

1. Create `infra/_framework-pkg/_framework/_wave-mgr/wave-mgr` (extract from `run`)
2. Add `_WAVE_MGR` to `set_env.sh` (top-level)
3. Add `_WAVE_MGR` to `_git_root/set_env.sh` (template)
4. Replace top-level `run` with the thin orchestration wrapper
5. Replace `_git_root/run` with the thin template wrapper (no bootstrap)
6. Replace top-level `Makefile` with the simplified version
7. Smoke-test: `./run --list-waves` should still work (delegates to wave-mgr)
8. Smoke-test: `./run --help` should show the new slim usage
9. Smoke-test: `wave-mgr --help` should show full wave flags

## Verification

```bash
# wave-mgr exists and is executable
ls -la infra/_framework-pkg/_framework/_wave-mgr/wave-mgr

# _WAVE_MGR is exported
source set_env.sh && echo $_WAVE_MGR

# run delegates list-waves to wave-mgr
./run --list-waves

# run shows slim help (no wave-specific flags)
./run --help

# wave-mgr shows full wave flags
$_WAVE_MGR --help

# Makefile targets still work
make --dry-run build
make --dry-run clean
```
