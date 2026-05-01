# Add `make all` First-Time Setup Target

## Summary

Added a `make all` convenience target that runs `bootstrap → setup → seed → build`
in order, so a fresh clone can be fully built with a single command. Added explicit
warnings in both the Makefile and README that `make bootstrap` uses `git pull --ff-only`
on external repos — committed changes are safe, uncommitted edits may be overwritten.

## Changes

- **`Makefile`** — added `all` target chaining `bootstrap setup seed build`; added
  comment block explaining the `--ff-only` safety guarantee and uncommitted-edit risk
- **`README.md`** — updated Quick Start to show `make all` as the one-liner; added
  blockquote warning with `--ff-only` semantics explained; added `make all` row to
  the Makefile targets table
