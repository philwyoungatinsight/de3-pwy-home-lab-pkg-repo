# fw-repo-mgr: Rename framework_repo_dir to git/de3

## Summary

Renamed the `framework_repo_dir` from `git/de3-source-packages` to `git/de3` in
`framework_repo_manager.yaml`. Generated per-package repos now land at `~/git/de3/<name>/`
instead of `~/git/de3-source-packages/<name>/`.

## Changes

- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — `framework_repo_dir` changed from `git/de3-source-packages` to `git/de3`; old value preserved as a comment

## Notes

The old `git/de3-source-packages` path is commented out for reference. Any existing
repos at the old path will not be affected — fw-repo-mgr -b will create new repos at
`~/git/de3/<name>/`.
