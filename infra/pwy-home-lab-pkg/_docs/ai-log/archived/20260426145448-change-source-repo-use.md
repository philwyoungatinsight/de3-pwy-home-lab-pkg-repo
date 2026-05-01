# change-source-repo-use

## Summary

Changed `framework_repo_manager.framework_repos[].source_repo` from a plain
string (name-only lookup) to an inline object with `name`, optional `url`, and
optional `ref` fields.  When only `name` is given, `url` and `ref` are resolved
from the renamed `source_repo_defaults` section.  This makes per-repo source
overrides possible without a separate registry entry.

## Changes

- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** —
  renamed `source_repos` → `source_repo_defaults`; updated comment to describe
  fallback semantics; updated per-repo comment to document `source_repo` object
  fields (`name`, `url`, `ref`); expanded all 12 `source_repo: de3-runner` string
  values to `source_repo:\n  name: de3-runner` objects.

- **`infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`** (de3-runner tier-3) —
  same `source_repos` → `source_repo_defaults` rename; updated commented example
  entry and real `pwy-home-lab-pkg` entry to object form; updated inline comment
  from "source_repos registry" to "source_repo_defaults".

- **`_ext_packages/de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr`** —
  rewrote `_resolve_source()`: reads `source_repo_defaults` (renamed key) and
  treats `source_repo` as an object; `source_repo.url`/`.ref` take precedence
  over defaults; dropped legacy `source_url`/`source_ref` sibling fields.
  Updated `_build_repo()` update-branch: replaced `_repo_field` scalar read of
  `source_repo` with inline Python that reads `source_repo.name`.
  Updated `usage()` workflow docs to reference `source_repo_defaults`.
