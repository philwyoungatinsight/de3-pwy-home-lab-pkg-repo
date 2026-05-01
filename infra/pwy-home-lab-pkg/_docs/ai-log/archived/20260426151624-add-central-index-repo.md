# Add de3-pwy-home-lab-pkg-repo and de3-central-index-repo

**Date**: 2026-04-26
**Plan**: `ai-plans/archived/20260426151624-add-central-index-repo.md`

## What changed

Added two new commented-out entries to
`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`:

1. **`de3-pwy-home-lab-pkg-repo`** — properly named (de3-prefix, -repo suffix) canonical
   entry for the current deployment repo. Commented out pending creation of the GitHub repo
   at `https://github.com/philwyoungatinsight/de3-pwy-home-lab-pkg-repo`.

2. **`de3-central-index-repo`** — new central discovery index. Declares every known framework
   package repo as an external dependency, making the full ecosystem graph reachable from a
   single entry point. Comments explain the sub-index pattern (domain-specific indexes for
   team/project grouping, all linking back to this central index). Commented out pending
   creation of the GitHub repo at `https://github.com/philwyoungatinsight/de3-central-index-repo`.

## Design decisions

- Both entries are commented out per CLAUDE.md: real repos must exist before entries are
  uncommented.
- Central index external packages reference individual package repos (not de3-runner monorepo)
  to show the distributed graph once packages are migrated.
- `pwy-home-lab-pkg` is included in the central index (marked non-exportable) for completeness.
- `_framework-pkg` is omitted from central index externals — auto-injected by
  `framework_package_template`.

## Next steps

Create the two GitHub repos, then uncomment the entries and validate YAML.
