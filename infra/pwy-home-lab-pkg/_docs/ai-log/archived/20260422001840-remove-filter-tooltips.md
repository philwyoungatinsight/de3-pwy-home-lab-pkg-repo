# Remove Filter Item Tooltips from Infra Panel

## Summary

Removed `rx.tooltip()` wrappers from the five filter-item toggle functions in the GUI infra-panel (packages, providers, regions, envs, roles). The Radix tooltip popups were appearing on hover over individual checkboxes in the filter dropdowns, making the UI sluggish and clunky. Each function now returns its `rx.hstack(...)` directly with no tooltip wrapper.

## Changes

- **`infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`** — removed `rx.tooltip()` from `provider_toggle_item`, `_package_toggle_item`, `_region_toggle_item`, `_role_toggle_item`, `_env_toggle_item`; button-level `title=` on dropdown triggers left intact

## Root Cause

Each toggle-item function wrapped its `rx.hstack` in `rx.tooltip(..., content="Click to toggle…")`. Radix UI tooltips fire on hover with a short delay and cause layout recalculation, which is noticeably slow when mousing across a list of checkboxes.

## Notes

The actual code change is in the de3-gui app repo (committed there as `fix(de3-gui): remove rx.tooltip wrappers from filter dropdown items`). This repo only tracks the archived plan.
