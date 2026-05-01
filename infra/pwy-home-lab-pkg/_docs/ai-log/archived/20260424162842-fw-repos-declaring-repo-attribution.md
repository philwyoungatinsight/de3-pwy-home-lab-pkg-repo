# Fix fw-repos-visualizer: proxmox-pkg-repo declaring repo attribution

## Summary

`proxmox-pkg-repo` was incorrectly attributed to `de3-runner` in the fw-repos diagram instead of `pwy-home-lab-pkg`. The `declaring_repo` scanner fix (committed in a prior session) correctly tracks which repo's settings file declares a generated repo, but `proxmox-pkg-repo` was still physically listed in de3-runner's template — so when the GUI scanned from de3-runner's context, it set `declaring_repo = "de3-runner"` first, and first-write-wins in the lineage dict.

The fix moves `proxmox-pkg-repo` into pwy-home-lab-pkg's OWN `framework_repo_manager.yaml` and comments it out from de3-runner's template. When the visualizer's BFS clones pwy-home-lab-pkg and scans its settings, it finds `proxmox-pkg-repo` with `declaring_repo = "pwy-home-lab-pkg"`.

## Changes

- **`infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — added `proxmox-pkg-repo` entry at the top of `framework_repos`, establishing pwy-home-lab-pkg as the repo that declares it
- **`de3-runner/infra/_framework-pkg/_config/_framework_settings/framework_repo_manager.yaml`** — re-commented the `proxmox-pkg-repo` example with an explanatory comment; deployment-specific repos belong in the deployment repo's own config, not the template

## Root Cause

The `declaring_repo` parameter fix in scanner.py correctly attributes repos based on which settings file declares them. However, `proxmox-pkg-repo` was declared in de3-runner's template (which the user had uncommented), so the first BFS pass set `lineage["proxmox-pkg-repo"] = "de3-runner"`. Moving the entry to pwy-home-lab-pkg's own config ensures it is found during the cloned-repo scan phase with the correct declaring repo.

## Notes

- This is the canonical pattern: deployment-specific repos (created for a particular deployment) should be listed in the deployment repo's own `framework_repo_manager.yaml`, not in the de3-runner template
- De3-runner's template should only show the pattern with a commented example
- Both repos pushed; a GUI refresh (which pulls the latest pwy-home-lab-pkg clone) will show the corrected attribution
