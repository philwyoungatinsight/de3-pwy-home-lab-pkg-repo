# Plan: Fix Loose Ends After Converting `_framework-pkg` to External

## Objective

After converting `infra/_framework-pkg` from an embedded directory to an external
symlink into de3-runner, several root-level files and CLAUDE.md path conventions
now resolve into the de3-runner checkout. Deployment-specific files (CLAUDE.md,
README.md, .sops.yaml) must become real files tracked in pwy-home-lab-pkg. Path
conventions in CLAUDE.md that reference `infra/_framework-pkg/_docs/...` for
writing must be updated to point to `infra/pwy-home-lab-pkg/_docs/...` so that
ai-log entries and ai-plan files land in the right repo.

---

## Context

### Root-level symlinks after migration

| File | Status | Disposition |
|------|--------|-------------|
| `CLAUDE.md` | symlink → de3-runner | Convert to real file — lab-specific rules |
| `README.md` | symlink → de3-runner | Convert to real file — lab-specific quick start |
| `.sops.yaml` | symlink → de3-runner | Convert to real file — lab PGP keys |
| `.gitlab-ci.yml` | symlink → de3-runner | Keep as symlink — generic SAST/secret-detection CI |
| `set_env.sh` | symlink → de3-runner | Keep as symlink — framework code |
| `root.hcl` | symlink → de3-runner | Keep as symlink — framework code |
| `run` | symlink → de3-runner | Keep as symlink — framework code |
| `Makefile` | real file | Already correct |

### CLAUDE.md path references that now write into de3-runner

All occurrences of `infra/_framework-pkg/_docs/` in CLAUDE.md that describe
**write** operations:

- `infra/_framework-pkg/_docs/ai-log/...` — ai-log entry path (line 296)
- `infra/_framework-pkg/_docs/ai-plans/...` — ai-plans path (lines 194, 196, 303, 304)
- `infra/_framework-pkg/_docs/ai-screw-ups/README.md` — **read-only** reference
  (line 3, 194); reading through the symlink from de3-runner is correct — these
  are shared framework-level mistakes. No change needed for read references.

### `infra/pwy-home-lab-pkg/_docs/ai-plans/` does not yet exist

Created as part of this plan. Future ai-plans and maas-snafu files for
pwy-home-lab-pkg live here.

### `.sops.yaml` in de3-runner has lab-specific PGP keys

Both PGP fingerprints (`446B...`, `1FAF...`) are Phil's personal keys specific to
this lab. They must not live in de3-runner. Converting `.sops.yaml` to a real file
removes them from the de3-runner checkout.

---

## Open Questions

None — ready to proceed.

---

## Files to Create / Modify

### `CLAUDE.md` — convert from symlink to real file

1. Remove the symlink: `rm CLAUDE.md`
2. Copy current content: `cp $(readlink -f CLAUDE.md) CLAUDE.md` (reads from de3-runner)
3. Edit the new real file to update path references:

**Line containing ai-log path** (Conventions section):
```
# Before:
- **Logging (ai-log)**: ... File: `infra/_framework-pkg/_docs/ai-log/$(date +%Y%m%d%H%M%S)-<short-description>.md`.

# After:
- **Logging (ai-log)**: ... File: `infra/pwy-home-lab-pkg/_docs/ai-log/$(date +%Y%m%d%H%M%S)-<short-description>.md`.
```

**Lines containing ai-plans path** (Conventions section + MaaS Snafu Tracking section):
```
# Before (all occurrences):
infra/_framework-pkg/_docs/ai-plans/

# After:
infra/pwy-home-lab-pkg/_docs/ai-plans/
```

**ai-screw-ups reference at top of CLAUDE.md** — leave as-is. Reading from
de3-runner is correct; framework mistakes are tracked in the framework repo.

### `README.md` — convert from symlink to real file

1. Remove the symlink: `rm README.md`
2. Copy current content: `cp $(readlink -f README.md) README.md`
3. Update the Quick Start section to add `make bootstrap` as step 1 (since
   `_framework-pkg` is now external):

```markdown
## Quick start

git clone <repo>
cd de3
make bootstrap  # clone de3-runner and link infra/_framework-pkg (first time only)
make setup      # install all CLI tools and language deps
make seed       # provision cloud accounts and authenticate (idempotent)
make            # sync external packages, then build (apply all waves)

`make bootstrap` only needs to run once on a fresh clone. After that, `make setup`
/ `make` / etc. delegate to the framework Makefile as normal.
```

### `.sops.yaml` — convert from symlink to real file

1. Remove the symlink: `rm .sops.yaml`
2. Copy current content from de3-runner (it already has the correct lab PGP keys):
   `cp $(readlink -f .sops.yaml) .sops.yaml`

No content changes needed — the file already has the right keys.

### `infra/pwy-home-lab-pkg/_docs/ai-plans/.gitkeep` — create

Create an empty `.gitkeep` so the directory is tracked in git.

### `infra/pwy-home-lab-pkg/_docs/ai-plans/archived/.gitkeep` — create

Create the `archived/` subdirectory so executed plans have a place to go.

---

## Execution Order

1. **`infra/pwy-home-lab-pkg/_docs/ai-plans/`** — create `.gitkeep` and `archived/.gitkeep`.
   Do this first so the directory exists before the plan is archived.
2. **`CLAUDE.md`** — convert from symlink to real file, update path references.
   Do this before committing so the commit is captured by the updated CLAUDE.md.
3. **`README.md`** — convert from symlink to real file, add bootstrap step.
4. **`.sops.yaml`** — convert from symlink to real file.
5. **Commit** all changes together.

---

## Verification

```bash
# 1. Root files are real files, not symlinks
file CLAUDE.md README.md .sops.yaml
# Expected: all show "ASCII text" (not symlinks)

# 2. .gitlab-ci.yml, set_env.sh, root.hcl, run are still symlinks
ls -la .gitlab-ci.yml set_env.sh root.hcl run
# Expected: still lrwxrwxrwx

# 3. CLAUDE.md references correct paths
grep "ai-log\|ai-plans" CLAUDE.md | grep infra
# Expected: all occurrences show infra/pwy-home-lab-pkg/..., none show infra/_framework-pkg/_docs/ai-log or ai-plans

# 4. ai-screw-ups reference still points to _framework-pkg (de3-runner)
grep "ai-screw-ups" CLAUDE.md
# Expected: infra/_framework-pkg/_docs/ai-screw-ups/README.md (unchanged)

# 5. sops can still encrypt using the real .sops.yaml
sops --encrypt --output /dev/null /dev/stdin <<< "test: value" 2>&1
# Expected: success (no key errors)

# 6. git status shows no untracked files
git status --short
# Expected: clean or only the 5 committed files shown as modified/new

# 7. ai-plans directory exists
ls infra/pwy-home-lab-pkg/_docs/ai-plans/
# Expected: archived/  .gitkeep
```
