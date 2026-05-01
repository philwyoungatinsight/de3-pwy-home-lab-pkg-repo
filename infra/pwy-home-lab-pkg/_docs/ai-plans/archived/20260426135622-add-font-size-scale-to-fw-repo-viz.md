# Plan: Add Font Size Scale to fw-repo Visualizer

## Objective

Add a **Font Size** slider to the fw-repos Mermaid diagram viewer so the user can make class-diagram text larger without relying on the coarse SVG zoom. The slider lives in the Appearance panel of the parent Reflex GUI and drives a real-time Mermaid re-render via `postMessage`-style `rx.call_script`, identical to how the existing zoom slider calls `_applyZoom` in the iframe.

## Context

- The viewer is `infra/de3-gui-pkg/_application/de3-gui/assets/fw_repos_mermaid_viewer.html`. It renders a Mermaid `classDiagram` SVG.
- Zoom is CSS-only (scales SVG `width`/`height`) and does not change font size — zooming in requires scrolling, which makes it hard to see the full picture while also reading text.
- Mermaid exposes font size through `mermaid.initialize({ themeVariables: { fontSize: '18px' } })`. Changing font size requires a full Mermaid re-render of the diagram.
- The parent Reflex app (`homelab_gui/homelab_gui.py`) controls the iframe by:
  1. Passing URL params in `fw_repos_iframe_src` (for initial state on each reload).
  2. Calling functions directly on `iframe.contentWindow` via `rx.call_script` (for real-time updates without reload) — the same pattern used by `set_fw_repos_zoom` calling `_applyZoom`.
- Mermaid `@11` dark-theme default fontSize is `18px`.
- The save/load persistence pattern for all `fw_repos_*` state vars is consistent: state var → `_save_current_config()` dict → `saved_menu.get(...)` in load path.
- de3-gui-pkg current version: **0.6.0** → bump to **0.7.0**.

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/de3-gui-pkg/_application/de3-gui/assets/fw_repos_mermaid_viewer.html` — modify

Three changes:

**1. Add module-level variables** (replace the single top-level `mermaid.initialize(...)` call and add cached-data variable):

```javascript
// Replace:
mermaid.initialize({ startOnLoad: false, theme: 'dark', securityLevel: 'loose' });

// With:
var _fontSizePx = parseInt(new URLSearchParams(window.location.search).get('fontSize') || '18');
var _repos = {};

function _initMermaid() {
  mermaid.initialize({
    startOnLoad: false,
    theme: 'dark',
    securityLevel: 'loose',
    themeVariables: { fontSize: _fontSizePx + 'px' }
  });
}
```

**2. Refactor `load()` to cache repos and call helpers:**

```javascript
// Replace the existing load() function with:
async function _renderDiagram() {
  if (Object.keys(_repos).length === 0) return;
  var defn = buildMermaid(_repos);
  var id = 'fw-repos-' + (++_renderCount);
  var result = await mermaid.render(id, defn);
  document.getElementById('diagram').innerHTML = result.svg;
  _initZoom();
}

async function load() {
  try {
    var resp = await fetch(apiBase() + '/api/fw-repos-graph');
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    var data = await resp.json();
    _repos = data.repos || {};

    if (Object.keys(_repos).length === 0) {
      document.getElementById('diagram').innerHTML =
        '<p style="color:#64748b;margin-top:40px;">No repos found. ' +
        'Run fw-repos-visualizer --list first.</p>';
      return;
    }

    _initMermaid();
    await _renderDiagram();
  } catch(e) {
    document.getElementById('diagram').innerHTML =
      '<p style="color:#ef4444;margin-top:40px;">Error: ' + e.message + '</p>';
    console.error(e);
  }
}
```

**3. Expose `window._setFontSize`** (add before the `load()` call at the bottom of the script):

```javascript
window._setFontSize = async function(sizePx) {
  _fontSizePx = sizePx;
  _initMermaid();
  await _renderDiagram();
};
```

### `infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py` — modify (7 touch points)

**a. State variable** — add after `fw_repos_packages` (~line 4471):
```python
fw_repos_font_size:    int  = 18     # diagram font size in px (10–40)
```

**b. `fw_repos_iframe_src` computed property** — append `&fontSize=...` to the f-string (~line 4688):
```python
# Change:
f"&inaccessible={self.fw_repos_inaccessible}&zoom={self.fw_repos_zoom}"
# To:
f"&inaccessible={self.fw_repos_inaccessible}&zoom={self.fw_repos_zoom}"
f"&fontSize={self.fw_repos_font_size}"
```

**c. Computed vars for slider** — add after `fw_repos_zoom_label` (~line 5953):
```python
@rx.var
def fw_repos_font_size_list(self) -> list[int]:
    return [self.fw_repos_font_size]

@rx.var
def fw_repos_font_size_label(self) -> str:
    return f"{self.fw_repos_font_size}px"
```

**d. `_save_current_config()`** — add after `"fw_repos_packages"` line (~line 6053):
```python
"fw_repos_font_size":    self.fw_repos_font_size,
```

**e. Load state from disk** — add after `fw_repos_packages` restore (~line 6189):
```python
self.fw_repos_font_size = int(saved_menu.get("fw_repos_font_size", 18))
```

**f. Event handler** — add after `set_fw_repos_zoom` (~line 7084):
```python
async def set_fw_repos_font_size(self, value: Any):
    """Set the fw-repos diagram font size and re-render the live iframe."""
    try:
        px = int(round(float(value[0]) if isinstance(value, list) else float(value)))
    except (TypeError, ValueError):
        return
    self.fw_repos_font_size = max(10, min(40, px))
    self._save_current_config()
    yield rx.call_script(
        "var f=document.querySelector('iframe[src*=\"fw_repos\"]');"
        "if(f&&f.contentWindow){"
        "var w=f.contentWindow;"
        f"if(w._setFontSize)w._setFontSize({self.fw_repos_font_size});"
        "}"
    )
```

**g. UI slider** — add a Font Size vstack immediately after the Zoom vstack block (after the closing `),` of the zoom vstack, ~line 15679), before the `),` that closes the fw-repos section:

```python
rx.vstack(
    rx.hstack(
        rx.text("Font Size", font_size="13px",
                title="Mermaid classDiagram font size in points — re-renders the diagram"),
        rx.spacer(),
        rx.text(
            AppState.fw_repos_font_size_label,
            font_size="12px",
            color="var(--gui-text-muted)",
            font_weight="600",
            min_width="36px",
            text_align="right",
        ),
        width="100%",
        align="center",
    ),
    rx.slider(
        min=10,
        max=40,
        step=2,
        value=AppState.fw_repos_font_size_list,
        on_change=AppState.set_fw_repos_font_size,
        width="100%",
    ),
    spacing="1",
    padding_x="6px",
    padding_y="6px",
    width="100%",
),
```

### `infra/de3-gui-pkg/_config/de3-gui-pkg.yaml` — modify

Bump `_provides_capability` version from `0.6.0` to `0.7.0`.

### `infra/de3-gui-pkg/_config/version_history.md` — modify

Append:
```markdown
## 0.7.0  (2026-04-26, git: <sha-after-commit>)
- feat: add Font Size slider to fw-repos Mermaid viewer — scales classDiagram text independently of zoom
```

### `infra/de3-gui-pkg/_application/de3-gui/docs/ai-log/<timestamp>-fw-repos-font-size-scale.md` — create

Write after commit (per de3-gui-pkg CLAUDE.md requirement). Summarise: state var added, `_setFontSize` exposed on iframe window, slider added to Appearance panel.

### `infra/de3-gui-pkg/_application/de3-gui/docs/ai-log-summary/README.ai-log-summary.md` — modify

Update to reflect the new font size control (per de3-gui-pkg CLAUDE.md requirement).

## Execution Order

1. **`fw_repos_mermaid_viewer.html`** — HTML changes first; they're independent and can be verified with a manual reload.
2. **`homelab_gui.py`** — all 7 touch points in a single edit pass; order within the file: state var → iframe src → computed vars → save → load → handler → slider UI.
3. **`de3-gui-pkg.yaml`** — bump version.
4. **`version_history.md`** — append entry (needs git sha, so do after commit or use placeholder and update).
5. **Docs** — ai-log + ai-log-summary (per de3-gui-pkg CLAUDE.md).
6. **Commit** all changes together.

## Verification

```bash
# Start the GUI
cd infra/de3-gui-pkg/_application/de3-gui
./run

# Open in browser, navigate to fw-repos tab, open Appearance panel.
# 1. Confirm "Font Size" slider appears below "Zoom" with label "18px".
# 2. Drag slider to 28 → diagram re-renders with larger text (no iframe reload flash).
# 3. Drag back to 14 → text shrinks.
# 4. Reload the page → font size restored to last-saved value (persistence check).
# 5. Change another setting (e.g. git → hide) → iframe reloads with correct ?fontSize= in URL.
```
