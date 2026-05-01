## fix-gui + /doit all-package plan search — 2026-04-22

Fixed `./run -A de3-gui` (de3-runner) and improved `/doit` plan discovery (pwy-home-lab-pkg).

### de3-runner: fix waves_ordering.yaml discovery and -A early-exit

`./run -A de3-gui` failed with `ERROR: waves_ordering.yaml not found` before reaching the
application. Two bugs caused this:

1. `load_all_configs()` searched `config/` and `infra/*/_config/` for `waves_ordering.yaml`
   but missed `_framework_settings/` subdirectories where the file actually lives. Fixed by
   replacing the hand-rolled search with `find_framework_config_dirs()` (reversed for
   highest-priority-first), consistent with the rest of the script.

2. The `-A`/`--app` handler was placed after `load_all_configs()`, so the wave config load
   always ran even when no wave config was needed. Moved the early-exit before
   `load_all_configs()` and deleted the duplicate block.

### pwy-home-lab-pkg: /doit searches all ai-plan directories

Added CLAUDE.md convention and updated `/doit` Step 2: plan names are unique across all
packages, so `find infra -path "*/_docs/ai-plans/<name>.md"` is used instead of
hardcoding `infra/pwy-home-lab-pkg/_docs/ai-plans/`. This fixes the session where the
fix-gui plan was found at `infra/_framework-pkg/_docs/ai-plans/fix-gui.md` but /doit
only looked in the pwy-home-lab-pkg directory.
