# Plan: Update Appearance Menu — Mode Dropdown + Tabbed Panels Layout

## Objective

Replace the binary "Floating panels mode" checkbox in the Appearance → Layout section with a
`Mode:` select dropdown offering three options: `4-panels`, `Floating Panels`, and
`Tabbed Panels`. Add a new Tabbed Panels layout in which the File Viewer, Terminal, and Object
Viewer appear as tabs to the right of the infra-tree left panel instead of floating freely.

## Context

**Single file**: all changes are in one 18,800-line file:
`_ext_packages/de3-runner/main/infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`

**Current state variables** (line 4652–4663):
```python
floating_panels_mode: bool = False   # persisted — REPLACED by panel_mode
float_file_viewer_open:   bool = True
float_terminal_open:      bool = True
float_object_viewer_open: bool = True
float_fv_saved_x/y, float_term_saved_x/y, float_ov_saved_x/y: str = ""
```

**All `floating_panels_mode` references** (grep confirmed):
- Line 4653 — state declaration
- Line 6027 — `_save_current_config()` snapshot
- Line 6163 — `on_load()` restore
- Line 6349 — `on_load()` post-restore: `if self.floating_panels_mode: init_all_float_panels`
- Lines 6720–6730 — `toggle_floating_panels_mode` / `flip_floating_panels_mode` handlers
- Lines 15060, 15706–15708 — Appearance menu
- Lines 17685, 17740, 17795 — float panel `rx.cond` guards
- Line 18271 — main layout `rx.cond` branch

**Existing `rx.select.root` pattern** (line 14054): the `_panel_view_selector()` function shows
the exact select widget pattern in use:
```python
rx.select.root(
    rx.select.trigger(size="1", title="…"),
    rx.select.content(
        rx.select.item("Label", value="value"),
        …
    ),
    value=AppState.some_state_var,
    on_change=AppState.set_handler,
    size="1",
)
```

**Reflex tabs API** (Reflex 0.8.27, verified via `dir(rx.tabs)`):
`rx.tabs.root`, `rx.tabs.list`, `rx.tabs.trigger`, `rx.tabs.content`

**Tabbed layout position**: tabs go to the RIGHT of the left infra-tree panel, mirroring
floating mode (which also keeps only the left panel as a sidebar). The three content panels
— Object Viewer, File Viewer, Terminal — become tabs in that column.

**Main layout conditional** (line 18268–18378): currently a nested `rx.cond`:
- Outer: `floating_panels_mode` → floating sidebar layout
- Inner: `maximized_panel == ""` → 4-panel grid OR maximized single panel

**Backward-compatibility**: persisted state uses `"floating_panels_mode": bool`. On load,
migrate old bool to the new string value so existing users keep their setting.

## Open Questions

1. **Tab order**: which tab should be first (leftmost) and which should be the default?
   Suggested: `Object Viewer` | `File Viewer` | `Terminal` (object viewer is primary;
   matches its current position as the top-right panel in 4-panel mode). Confirm or reorder.

2. **Panel resizer in tabbed mode**: should there be a draggable resizer between the infra
   tree and the tab column in tabbed mode? Suggested: yes, reuse `panel_resizer()` for
   consistency with 4-panel mode.

3. **Panels menu in tabbed mode**: the "Panels" visibility checkboxes (File viewer, Terminal,
   Object viewer) currently only apply to floating mode. In tabbed mode, all three are always
   visible as tabs. Suggested: keep existing behaviour — show the hint "Enable floating panels
   mode…" for both non-floating AND non-tabbed modes; hide it only in floating mode. Confirm
   or adjust.

4. **Maximized panel in tabbed mode**: the current "maximized" single-panel mode is triggered
   from 4-panel mode headers. Should the maximize buttons be hidden/disabled in tabbed mode,
   or should they still expand a single panel full-screen? Suggested: leave maximize buttons
   as-is; if the user maximizes while in tabbed mode the `maximized_panel != ""` path already
   works independently of `panel_mode`.

## Files to Create / Modify

### `_ext_packages/de3-runner/main/infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py` — modify

**Change 1 — State variables** (around line 4652):

Replace:
```python
    # ── Floating panels mode ─────────────────────────────────────────────
    floating_panels_mode:      bool = False   # persisted
```
With:
```python
    # ── Panel layout mode ────────────────────────────────────────────────
    # "4-panels" | "floating" | "tabbed"  — persisted
    panel_mode:               str  = "4-panels"
    tabbed_panel_active:      str  = "file-viewer"   # active tab in tabbed mode — persisted
```
Keep the remaining `float_*` variables unchanged (they still apply to floating mode).

---

**Change 2 — `_save_current_config`** (line 6027):

Replace:
```python
            "floating_panels_mode":     self.floating_panels_mode,
```
With:
```python
            "panel_mode":               self.panel_mode,
            "tabbed_panel_active":      self.tabbed_panel_active,
```

---

**Change 3 — `on_load` restore** (line 6163):

Replace:
```python
        self.floating_panels_mode     = bool(saved_menu.get("floating_panels_mode",     False))
```
With:
```python
        _saved_mode = saved_menu.get("panel_mode", None)
        if _saved_mode is None:
            # Migrate from old boolean — users who had floating mode keep it
            _saved_mode = "floating" if bool(saved_menu.get("floating_panels_mode", False)) else "4-panels"
        self.panel_mode = _saved_mode if _saved_mode in ("4-panels", "floating", "tabbed") else "4-panels"
        self.tabbed_panel_active = saved_menu.get("tabbed_panel_active", "file-viewer")
```

---

**Change 4 — `on_load` post-restore init** (line 6349):

Replace:
```python
        if self.floating_panels_mode:
            scripts.append(AppState.init_all_float_panels)
```
With:
```python
        if self.panel_mode == "floating":
            scripts.append(AppState.init_all_float_panels)
```

---

**Change 5 — Event handlers** (lines 6718–6730):

Replace the entire floating-panels-mode block:
```python
    # ── Floating panels mode ─────────────────────────────────────────────────

    def toggle_floating_panels_mode(self, checked: bool):
        self.floating_panels_mode = checked
        self._save_current_config()
        if checked:
            return AppState.init_all_float_panels

    def flip_floating_panels_mode(self):
        self.floating_panels_mode = not self.floating_panels_mode
        self._save_current_config()
        if self.floating_panels_mode:
            return AppState.init_all_float_panels
```
With:
```python
    # ── Panel layout mode ────────────────────────────────────────────────────

    def set_panel_mode(self, mode: str):
        self.panel_mode = mode
        self._save_current_config()
        if mode == "floating":
            return AppState.init_all_float_panels

    def set_tabbed_panel_active(self, tab: str):
        self.tabbed_panel_active = tab
        self._save_current_config()
```

---

**Change 6 — Appearance menu Layout section** (lines 15704–15710):

Replace the `_appearance_menu_item("Floating panels mode", ...)` block:
```python
                    _appearance_menu_item(
                        "Floating panels mode",
                        AppState.floating_panels_mode,
                        AppState.toggle_floating_panels_mode,
                        AppState.flip_floating_panels_mode,
                        tooltip="Switch to draggable floating panels for file viewer, terminal, and object viewer",
                    ),
```
With:
```python
                    rx.hstack(
                        rx.text(
                            "Mode:",
                            font_size="13px",
                            title="Switch between 4-panel grid, draggable floating panels, or tabbed panels",
                        ),
                        rx.spacer(),
                        rx.select.root(
                            rx.select.trigger(size="1"),
                            rx.select.content(
                                rx.select.item("4-panels",        value="4-panels"),
                                rx.select.item("Floating Panels", value="floating"),
                                rx.select.item("Tabbed Panels",   value="tabbed"),
                            ),
                            value=AppState.panel_mode,
                            on_change=AppState.set_panel_mode,
                            size="1",
                        ),
                        width="100%",
                        align="center",
                        padding_x="6px",
                        padding_y="6px",
                    ),
```

---

**Change 7 — Panels menu floating-mode hint** (line 15060):

Replace:
```python
            rx.cond(
                ~AppState.floating_panels_mode,
                rx.text(
                    "Enable floating panels mode\n(Appearance → Layout)\nfor file viewer, terminal,\nand object viewer",
```
With:
```python
            rx.cond(
                AppState.panel_mode != "floating",
                rx.text(
                    "Enable Floating Panels mode\n(Appearance → Layout → Mode)\nfor file viewer, terminal,\nand object viewer",
```

---

**Change 8 — Float panel visibility guards** (lines 17685, 17740, 17795):

Replace all three occurrences of `AppState.floating_panels_mode &` with
`(AppState.panel_mode == "floating") &`:

Line 17685:
```python
        AppState.floating_panels_mode & AppState.float_file_viewer_open,
```
→
```python
        (AppState.panel_mode == "floating") & AppState.float_file_viewer_open,
```

Line 17740:
```python
        AppState.floating_panels_mode & AppState.float_terminal_open,
```
→
```python
        (AppState.panel_mode == "floating") & AppState.float_terminal_open,
```

Line 17795:
```python
        AppState.floating_panels_mode & AppState.float_object_viewer_open,
```
→
```python
        (AppState.panel_mode == "floating") & AppState.float_object_viewer_open,
```

---

**Change 9 — New `tabbed_panels_layout()` function** (add near other layout functions,
before the `page()` / main layout function, around line 18260):

```python
def tabbed_panels_layout() -> rx.Component:
    """Tabbed mode: infra tree sidebar + all content panels as tabs to the right."""
    return rx.hstack(
        rx.box(
            left_panel(),
            id="left-column",
            overflow_y="auto",
            overflow_x="hidden",
            height="100%",
            border_right="1px solid var(--gui-border)",
            style={
                "min_width": AppState.left_panel_width_style,
                "width": "max-content",
                "height": "100%",
            },
        ),
        panel_resizer(),
        rx.tabs.root(
            rx.tabs.list(
                rx.tabs.trigger("Object Viewer", value="object-viewer", size="1"),
                rx.tabs.trigger("File Viewer",   value="file-viewer",   size="1"),
                rx.tabs.trigger("Terminal",      value="terminal",      size="1"),
            ),
            rx.tabs.content(
                rx.box(top_right_panel(), width="100%", height="100%", overflow="hidden"),
                value="object-viewer",
                flex="1",
                min_height="0",
                overflow="hidden",
                display="flex",
                flex_direction="column",
            ),
            rx.tabs.content(
                rx.box(bottom_left_panel(), width="100%", height="100%", overflow="hidden"),
                value="file-viewer",
                flex="1",
                min_height="0",
                overflow="hidden",
                display="flex",
                flex_direction="column",
            ),
            rx.tabs.content(
                rx.box(bottom_right_panel(), width="100%", height="100%", overflow="hidden"),
                value="terminal",
                flex="1",
                min_height="0",
                overflow="hidden",
                display="flex",
                flex_direction="column",
            ),
            value=AppState.tabbed_panel_active,
            on_change=AppState.set_tabbed_panel_active,
            flex="1",
            min_width="0",
            height="100%",
            overflow="hidden",
            display="flex",
            flex_direction="column",
        ),
        spacing="0",
        width="100%",
        height="100%",
        overflow="hidden",
        align="start",
    )
```

---

**Change 10 — Main layout conditional** (lines 18268–18378):

The outer `rx.cond(AppState.floating_panels_mode, ...)` becomes `rx.match(AppState.panel_mode, ...)`.

Replace the entire outer `rx.cond` starting at line 18269:
```python
        rx.cond(
            AppState.floating_panels_mode,
            # ── Floating mode layout: infra tree sidebar only ──────────────
            rx.box(
                left_panel(),
                …
            ),
            # ── Normal / maximized layout ──────────────────────────────────
            rx.cond(
                AppState.maximized_panel == "",
                # ── Normal 4-panel layout ──────────────────────────────────
                rx.box( … ),
                # ── Maximized single-panel layout ──────────────────────────
                rx.box( … ),
            ),
        ),
```
With:
```python
        rx.match(
            AppState.panel_mode,
            # ── Floating mode ──────────────────────────────────────────────
            ("floating",
                rx.box(
                    left_panel(),
                    id="left-column",
                    overflow_y="auto",
                    overflow_x="hidden",
                    height="100%",
                    border_right="1px solid var(--gui-border)",
                    style={
                        "min_width": AppState.left_panel_width_style,
                        "width": "max-content",
                        "height": "100%",
                    },
                ),
            ),
            # ── Tabbed mode ────────────────────────────────────────────────
            ("tabbed", tabbed_panels_layout()),
            # ── Default: 4-panels / maximized ─────────────────────────────
            rx.cond(
                AppState.maximized_panel == "",
                # Normal 4-panel grid
                rx.box( … ),        # <-- keep existing 4-panel code verbatim
                # Maximized single panel
                rx.box( … ),        # <-- keep existing maximized code verbatim
            ),
        ),
```

Note: `rx.match` in Reflex takes `(value, branch, ...)` tuples and a final default expression.
The existing 4-panel and maximized-panel code blocks are preserved verbatim inside the default branch.

## Execution Order

1. **State variables** (Change 1) — rename `floating_panels_mode` first; all subsequent
   changes reference the new `panel_mode` name.
2. **`_save_current_config`** (Change 2) — update the persistence snapshot key.
3. **`on_load` restore** (Change 3) — update load with migration logic.
4. **`on_load` post-restore** (Change 4) — update the floating-panel init guard.
5. **Event handlers** (Change 5) — add `set_panel_mode` / `set_tabbed_panel_active`, remove old handlers.
6. **Appearance menu** (Change 6) — replace checkbox with select; references `set_panel_mode`.
7. **Panels menu hint** (Change 7) — update the condition text.
8. **Float panel guards** (Change 8) — update all three `rx.cond` guards.
9. **New layout function** (Change 9) — add `tabbed_panels_layout()`.
10. **Main layout** (Change 10) — replace outer `rx.cond` with `rx.match`.

## Verification

After executing, start the GUI and verify:

1. **Appearance → Layout section** shows `Mode:` label + dropdown (not a checkbox).
2. **Dropdown options** are `4-panels`, `Floating Panels`, `Tabbed Panels`.
3. **Selecting `4-panels`**: standard 2×2 grid renders correctly; drag resizers work.
4. **Selecting `Floating Panels`**: floating windows appear; drag/resize/close works.
5. **Selecting `Tabbed Panels`**: infra tree left panel + tab bar to the right; switching
   tabs shows the correct panel content (Object Viewer / File Viewer / Terminal).
6. **Reload browser**: selected mode is restored from `state/current.yaml`.
7. **Migration**: manually set `floating_panels_mode: true` in `state/current.yaml` (remove
   `panel_mode` key), reload → should restore to `floating` mode automatically.
8. **Panels menu**: shows the `"Enable Floating Panels mode…"` hint when in `4-panels` or
   `tabbed` mode; hint is hidden in `floating` mode.
