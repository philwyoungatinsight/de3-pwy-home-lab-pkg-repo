# Fix set_env.sh git root detection when CWD is inside a symlinked package repo

## Summary

`./run -A de3-gui` was failing because `infra/de3-gui-pkg` is a symlink into
`de3-gui-pkg-repo`. When `make` changed directory into that symlinked path, git
followed the symlinks to the physical location and returned `de3-gui-pkg-repo` as
the toplevel — not the deployment repo. This caused both `set_env.sh` and
`framework-utils.sh` to use the wrong `_GIT_ROOT`, and `set_env.sh` in
`de3-gui-pkg-repo/main/` is a broken symlink that points into `_framework-pkg` (absent
there), producing the "No such file or directory" error.

## Changes

- **`de3-framework-pkg-repo: infra/_framework-pkg/_framework/_git_root/set_env.sh`** —
  changed `_GIT_ROOT` derivation from `git rev-parse --show-toplevel` to
  `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`. `set_env.sh` is always at the deployment
  repo root by convention, so `dirname` of its own sourced path is always correct
  regardless of CWD.

- **`de3-framework-pkg-repo: infra/_framework-pkg/_framework/_utilities/bash/framework-utils.sh`** —
  changed `. $(git rev-parse --show-toplevel)/set_env.sh` to
  `. ${_GIT_ROOT:-$(git rev-parse --show-toplevel)}/set_env.sh`. If `_GIT_ROOT` is
  already correctly set (by a prior `set_env.sh` source), it is reused instead of
  re-running `git rev-parse` and getting the wrong answer.

## Root Cause

`git rev-parse --show-toplevel` resolves symlinks when locating the git repo root.
`infra/de3-gui-pkg` symlinks into `de3-gui-pkg-repo/main/infra/de3-gui-pkg`, so git
sees the CWD as being inside `de3-gui-pkg-repo` and returns its root — not the
deployment repo root. `de3-gui-pkg-repo/main/set_env.sh` is itself a symlink to
`infra/_framework-pkg/_framework/_git_root/set_env.sh`, which does not exist inside
`de3-gui-pkg-repo` (only in `de3-framework-pkg-repo`), causing the fatal error.

## Notes

The fix is entirely in `de3-framework-pkg-repo` (committed as `f4420c4`). The
`BASH_SOURCE[0]` approach is robust: bash stores the path as passed to the `.`
(source) command without resolving symlinks, so `dirname "${BASH_SOURCE[0]}"` gives
the logical directory of the sourced file — which is the deployment repo root.
