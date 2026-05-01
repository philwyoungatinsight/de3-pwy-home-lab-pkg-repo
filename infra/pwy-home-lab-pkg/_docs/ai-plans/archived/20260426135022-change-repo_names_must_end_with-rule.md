# Plan: Change repo_names_must_end_with rule from -pkg-repo to -repo

## Objective

Change the `repo_names_must_end_with` naming rule value from `-pkg-repo` to `-repo` in both
config files that define it: the pwy-home-lab-pkg deployment config and the de3-runner
template config. This relaxes the suffix requirement so repos need only end with `-repo`
(e.g. `proxmox-repo`) rather than the more-specific `-pkg-repo` suffix.

## Context

The `repo_names_must_end_with` rule is config-driven — the `fw-repo-mgr` validation script
at `de3-runner/main/infra/_framework-pkg/_framework/_fw-repo-mgr/fw-repo-mgr` reads the
value directly from the YAML and calls `.endswith(str(v))`. There is no hardcoded `-pkg-repo`
string in the validation logic; changing the YAML is all that's required.

Two live config files define the rule:

1. **Deployment config** (pwy-home-lab-pkg, line 64):
   `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`
2. **Template/default config** (de3-runner, line 95):
   `de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`

All existing repos remain valid after the change:
- `proxmox-pkg-repo` ends with `-pkg-repo`, which ends with `-repo` → still passes ✓
- `de3-aws-pkg`, `de3-azure-pkg`, etc. satisfy the separate `repo_names_must_begin_with: de3-` rule ✓

Historical ai-logs and archived plans reference `-pkg-repo` as examples/notes. These are
frozen historical records and must NOT be modified.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Line 64, under `repo_names_must_end_with`:

```yaml
    - name: repo_names_must_end_with
      value: -repo          # ← was -pkg-repo
```

### `/home/pyoung/git/de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Line 95, under `repo_names_must_end_with`:

```yaml
    - name: repo_names_must_end_with
      value: -repo          # ← was -pkg-repo
```

Also update the inline comment on line 84 that documents the rule, which currently uses
`-pkg-repo` as the illustrative default. Change the comment to reflect `-repo`:

```
  #   repo_names_must_end_with                     value: <suffix>   (multiple = OR)
```

(The comment shows a placeholder `<suffix>` — no change needed there. Only the live
`value:` entry on line 95 needs updating.)

## Execution Order

1. Edit pwy-home-lab-pkg `framework_repo_manager.yaml` (local repo).
2. Edit de3-runner `framework_repo_manager.yaml` (external repo at `de3-ext-packages/de3-runner/main/`).
3. Write ai-log entry in pwy-home-lab-pkg.
4. Bump `_provides_capability` version + append entry in `infra/pwy-home-lab-pkg/_config/version_history.md`.
5. Commit pwy-home-lab-pkg changes.
6. Commit de3-runner changes (separate commit in that repo).

## Verification

```bash
# From pwy-home-lab-pkg root:
fw-repo-mgr -v validate
# Expected: no errors about repo_names_must_end_with

grep "value:" infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml | grep repo_names_must_end
# Expected:       value: -repo

grep "value:" /home/pyoung/git/de3-ext-packages/de3-runner/main/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml | grep -A0 "repo"
# (or just grep the file for -pkg-repo — should return 0 matches in the live rules section)
```
