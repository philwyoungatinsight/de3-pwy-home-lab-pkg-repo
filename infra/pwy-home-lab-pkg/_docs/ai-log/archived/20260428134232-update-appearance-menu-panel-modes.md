# Update Appearance Menu — Mode Dropdown + Tabbed Panels Layout

## Summary

Replaced the binary "Floating panels mode" checkbox in the Appearance → Layout menu with a
`Mode:` select dropdown offering three choices: `4-panels`, `Floating Panels`, and
`Tabbed Panels`. Added a new Tabbed Panels layout where File Viewer, Terminal, and Object
Viewer appear as tabs to the right of the infra-tree sidebar, with a draggable resizer
between the sidebar and the tab column. Backward-compatible: existing saved `floating_panels_mode: true`
state is migrated to `panel_mode: "floating"` on first load.

## Changes

- **`_ext_packages/de3-runner/main/infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`** —
  10 changes: replace `floating_panels_mode: bool` state with `panel_mode: str` + `tabbed_panel_active: str`;
  replace toggle handlers with `set_panel_mode` / `set_tabbed_panel_active`; replace checkbox in
  Appearance → Layout with `rx.select.root` Mode dropdown; update 3 float-panel visibility guards;
  add `tabbed_panels_layout()` function; replace main layout `rx.cond` with `rx.match` over `panel_mode`
- **`infra/de3-gui-pkg/_config/de3-gui-pkg.yaml`** — bumped version 0.7.0 → 0.8.0
- **`infra/de3-gui-pkg/_config/version_history.md`** — added 0.8.0 entry
- **`infra/pwy-home-lab-pkg/_docs/ai-plans/archived/`** — plan archived after execution

## Notes

- `rx.match` in Reflex 0.8 takes `(value, *cases, default)` — final positional arg is the
  default branch, not a named kwarg. The previous nested `rx.cond(floating_panels_mode, A, rx.cond(max, B, C))`
  became `rx.match(panel_mode, ("floating", A), ("tabbed", T), rx.cond(max, B, C))`.
- The stray extra `),` from the old outer `rx.cond` nesting had to be removed after the
  initial substitution — caught by `python3 -c "import ast; ast.parse(...)"`.
- `tabbed_panel_active` defaults to `"file-viewer"` to match initial state declared in state vars.
