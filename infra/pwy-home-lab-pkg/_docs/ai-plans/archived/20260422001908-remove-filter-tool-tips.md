# Plan: Remove Filter Item Tooltips

## Objective
Remove the `rx.tooltip()` wrappers from individual checkbox items inside the five filter
dropdown menus (packages, providers, regions, envs, roles) in the infra-panel. The
tooltips cause sluggishness and clunkiness when hovering over items; removing them
restores snappy interaction without losing any functionality.

## Context
All filter item functions live in a single file:
`infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`

Each function wraps its `rx.hstack(...)` in `rx.tooltip(..., content="...")`. Removing
the tooltip means returning the `rx.hstack(...)` directly.

Five functions to fix:

| Function | Line | Filter |
|---|---|---|
| `provider_toggle_item` | 12643 | Providers |
| `_package_toggle_item` | 13138 | Packages |
| `_region_toggle_item` | 13166 | Regions |
| `_role_toggle_item` | 13194 | Roles |
| `_env_toggle_item` | 13336 | Envs |

The pattern is identical in every case:
```python
# Before
def _xxx_toggle_item(...):
    return rx.tooltip(
        rx.hstack(...),
        content="Click to toggle ...",
    )

# After
def _xxx_toggle_item(...):
    return rx.hstack(...)
```

The button-level `title=` attributes on the dropdown trigger buttons (e.g. "Packages",
"Providers") are NOT touched — those are outside the dropdowns and not causing the
sluggishness.

## Open Questions
None — ready to proceed.

## Files to Create / Modify

### `infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py` — modify

Five edits, each unwrapping `rx.tooltip(rx.hstack(...), content="...")` → `rx.hstack(...)`.

**Edit 1 — `provider_toggle_item` (line 12643)**
```python
# Remove:
    return rx.tooltip(
        rx.hstack(
            ...
        ),
        content="Click to toggle · Double-click: show only this provider (again to invert)",
    )
# Replace with:
    return rx.hstack(
        ...
    )
```

**Edit 2 — `_package_toggle_item` (line 13138)**
Same pattern — remove `rx.tooltip(` wrapper and `content=` line.

**Edit 3 — `_region_toggle_item` (line 13166)**
Same pattern.

**Edit 4 — `_role_toggle_item` (line 13194)**
Same pattern.

**Edit 5 — `_env_toggle_item` (line 13336)**
Same pattern.

## Execution Order
1. Edit `homelab_gui.py` — all 5 tooltip removals (one file, sequential edits)
2. Verify no `rx.tooltip` references remain for filter item functions
3. Bump package version + append version_history entry
4. Write ai-log entry
5. Commit

## Verification
```bash
# Confirm no tooltip wrappers remain on the five item functions
grep -n "rx.tooltip" infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py
# Should show zero results for lines near 12643, 13138, 13166, 13194, 13336
```
The GUI must be restarted (`make` in de3-gui-pkg or equivalent) to pick up Python
changes; the .web/routes/_index.jsx is auto-generated and does not need manual editing.
