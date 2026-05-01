# Move version history from YAML comments to version_history.md

Moved the `# Version history` comment block from `infra/_framework-pkg/_config/_framework-pkg.yaml`
into a peer file `infra/_framework-pkg/_config/version_history.md`.

Updated CLAUDE.md convention: all packages now track version history in
`infra/<pkg>/_config/version_history.md` (markdown) rather than YAML comments.
The `/ship` skill and any package code change must append an entry to that file.

Files changed:
- `infra/_framework-pkg/_config/_framework-pkg.yaml` — stripped version history comments
- `infra/_framework-pkg/_config/version_history.md` — new file with full history
- `CLAUDE.md` — updated Package version history convention
