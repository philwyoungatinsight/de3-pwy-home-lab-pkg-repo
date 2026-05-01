---
date: 2026-04-21
task: fix-loose-ends-after-external-framework-pkg
---

# Fix Loose Ends After Converting `_framework-pkg` to External

## What was done

After `_framework-pkg` became an external symlink into de3-runner, three root-level
files were still symlinks pointing into de3-runner. Converted them to real files
tracked in pwy-home-lab-pkg:

- **`CLAUDE.md`** — converted from symlink to real file; updated all write-path
  references from `infra/_framework-pkg/_docs/ai-plans/` and
  `infra/_framework-pkg/_docs/ai-log/` to `infra/pwy-home-lab-pkg/_docs/`
  equivalents. The read-only `ai-screw-ups` reference was left pointing to
  `_framework-pkg` (correct — shared framework mistakes live in de3-runner).

- **`README.md`** — converted from symlink to real file; added `make bootstrap`
  as step 1 in Quick Start (required on fresh clones to link `_framework-pkg`);
  added `make bootstrap` row to the Makefile targets table.

- **`.sops.yaml`** — converted from symlink to real file; no content changes —
  PGP keys were already correct in the de3-runner copy. Lab-specific keys now
  live only in pwy-home-lab-pkg.

- **`infra/pwy-home-lab-pkg/_docs/ai-plans/`** — created directory with `.gitkeep`
  and `archived/` subdirectory. Future ai-plans and maas-snafu files for
  pwy-home-lab-pkg live here.

Kept as symlinks (framework code, not lab-specific):
`.gitlab-ci.yml`, `set_env.sh`, `root.hcl`, `run`
