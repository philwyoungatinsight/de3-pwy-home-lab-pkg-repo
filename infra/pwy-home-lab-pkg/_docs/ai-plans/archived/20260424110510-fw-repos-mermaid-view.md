# Plan: Replace fw-repos Cytoscape view with Mermaid class diagram

## Objective

Replace the current (broken, illegible) Cytoscape compound-node view of framework
repos with a Mermaid `classDiagram` rendered in an iframe asset. Repos appear as
UML classes; packages appear as class members; `created_by` lineage appears as
inheritance arrows. This matches the "object-oriented class inheritance diagram"
mental model the user described.

## Context

### Data source
`config/tmp/fw-repos-visualizer/known-fw-repos.yaml` — already read by the GUI.

Structure per repo:
```yaml
<repo-name>:
  url: <git-url or null>
  created_by: <parent-repo-name or null>
  source: local | cloned | declared
  settings_dirs:
    - packages:
        - name: <pkg-name>
          package_type: embedded | external
          exportable: true/false
          provides_capability: [{<name>: <version>}]
```

### Existing pattern
Complex diagrams → `assets/*.html` (loaded via `rx.el.iframe`). This is already
used for `cytoscape_viewer.html` and `mxgraph_viewer.html`. The iframe fetches data
from a `/api/...` backend endpoint.

### Mermaid class diagram analogy
- **Repo** → class
- **Embedded package** → `+ pkg-name: version` (public/owned)
- **External package** → `- pkg-name: version` (private/imported)
- **`created_by`** → inheritance arrow `Parent <|-- Child : creates`
- **Repo stereotype** → `<<local>>` / `<<cloned>>` / `<<declared>>`

Example output:
```
classDiagram
    class `de3-runner` {
        <<cloned>>
        +_framework-pkg: 1.9.0
        -aws-pkg: 1.0.0
    }
    class `proxmox-pkg-repo` {
        <<declared>>
        +proxmox-pkg: 1.0.0
    }
    `de3-runner` <|-- `proxmox-pkg-repo` : creates
```

### Current state to remove
The existing fw-repos Cytoscape view added substantial complexity that will be
completely replaced:
- `_FwReposCytoscapeGraph` subclass — already removed (dagre fix)
- State fields: `fw_repos_positions`, `fw_repos_root_ids`, `fw_repos_collapsed_repos`,
  `fw_repos_layout`, all 7 `fw_repos_show_*` / `fw_repos_merge_*` bools
- Computed vars: `fw_repos_layout_label`, `fw_repos_cyto_layout`
- Event handlers: `save_fw_repos_layout`, `reset_fw_repos_layout`,
  `toggle_fw_repo_collapsed`, `collapse_all_fw_repos`, `expand_all_fw_repos`,
  `set_fw_repos_layout_by_label`, `toggle_fw_repos_show_*` (7 handlers)
- UI functions: `_fw_repos_appearance_menu`, `_fw_repos_collapse_menu`,
  `fw_repos_cytoscape_view`
- Constants: `_FW_REPOS_CYTOSCAPE_STYLESHEET`, `_FW_REPOS_CYTOSCAPE_INIT_JS`,
  `_FW_REPOS_SAVE_LAYOUT_JS`, `_FW_REPOS_LAYOUT` path constant (layout yaml)
- `state/fw-repos-layout.yaml` file
- All fw_repos keys in `_save_current_config` / `_load_state` except `framework_repos_data`
- The layout selector, collapse menu, appearance menu, save/reset layout buttons

**Keep**: `framework_repos_data: dict` state field, `_FW_REPOS_YAML` and
`_FW_REPOS_VIZ_BIN` path constants, `refresh_fw_repos_data` event handler,
`framework_repos_data_keys` computed var (used by refresh logic).

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/de3-gui-pkg/_application/de3-gui/assets/fw_repos_mermaid_viewer.html` — create

Full-page HTML that:
1. Loads Mermaid.js from CDN: `https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js`
2. On `DOMContentLoaded`, fetches `/api/fw-repos-graph`
3. Builds `classDiagram` Mermaid syntax from the JSON response
4. Renders it via `mermaid.render()`
5. Has a "Refresh" button that re-fetches and re-renders

Mermaid syntax rules to follow:
- Class names with hyphens/special chars → wrap in backticks: `` `my-repo` ``
- Strip `<` / `>` from `<current-repo>` → render as `current-repo`
- Sort embedded packages before external within each class
- Include version from `provides_capability[0]` if present, else omit version
- Stereotype = source field: `<<local>>`, `<<cloned>>`, `<<declared>>`
- Only emit inheritance arrows where `created_by` is non-empty

Styling: dark background matching GUI theme (`#0f172a` body, `#1e293b` toolbar).
The Mermaid diagram itself uses the `dark` theme.

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #0f172a; color: #e2e8f0; font-family: system-ui, sans-serif;
           display: flex; flex-direction: column; height: 100vh; overflow: hidden; }
    #toolbar { display: flex; gap: 8px; align-items: center; padding: 6px 10px;
               background: #1e293b; border-bottom: 1px solid #334155; flex-shrink: 0; }
    #toolbar button { padding: 4px 10px; background: #334155; color: #e2e8f0;
                      border: none; border-radius: 4px; cursor: pointer; font-size: 12px; }
    #toolbar button:hover { background: #475569; }
    #status { font-size: 11px; color: #64748b; }
    #diagram-wrap { flex: 1; overflow: auto; padding: 20px; display: flex;
                    justify-content: center; align-items: flex-start; }
    #diagram { min-width: 600px; }
  </style>
</head>
<body>
  <div id="toolbar">
    <button onclick="load()">↻ Refresh</button>
    <span id="status">Loading…</span>
  </div>
  <div id="diagram-wrap"><div id="diagram"></div></div>
  <script>
    mermaid.initialize({ startOnLoad: false, theme: 'dark', securityLevel: 'loose' });

    function buildMermaid(repos) {
      var lines = ['classDiagram'];
      Object.entries(repos).forEach(([name, r]) => {
        var safe = name.replace(/[<>]/g, '').trim() || 'current-repo';
        var pkgs = [];
        (r.settings_dirs || []).forEach(d => (d.packages || []).forEach(p => pkgs.push(p)));
        var embedded = pkgs.filter(p => p.package_type === 'embedded');
        var external = pkgs.filter(p => p.package_type !== 'embedded');
        lines.push('    class `' + safe + '` {');
        if (r.source) lines.push('        <<' + r.source + '>>');
        embedded.forEach(p => {
          var ver = (p.provides_capability || [])[0];
          var v = ver ? ': ' + Object.values(ver)[0] : '';
          lines.push('        +' + p.name + v);
        });
        external.forEach(p => {
          var ver = (p.provides_capability || [])[0];
          var v = ver ? ': ' + Object.values(ver)[0] : '';
          lines.push('        -' + p.name + v);
        });
        lines.push('    }');
      });
      // Inheritance arrows
      Object.entries(repos).forEach(([name, r]) => {
        if (r.created_by) {
          var child  = name.replace(/[<>]/g, '').trim() || 'current-repo';
          var parent = r.created_by.replace(/[<>]/g, '').trim() || 'current-repo';
          lines.push('    `' + parent + '` <|-- `' + child + '` : creates');
        }
      });
      return lines.join('\n');
    }

    async function load() {
      document.getElementById('status').textContent = 'Loading…';
      try {
        var resp = await fetch('/api/fw-repos-graph');
        var data = await resp.json();
        var defn = buildMermaid(data.repos || {});
        var { svg } = await mermaid.render('fw-repos-diagram', defn);
        document.getElementById('diagram').innerHTML = svg;
        document.getElementById('status').textContent =
          Object.keys(data.repos || {}).length + ' repos';
      } catch(e) {
        document.getElementById('status').textContent = 'Error: ' + e.message;
      }
    }
    load();
  </script>
</body>
</html>
```

### `infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py` — modify

**A. Add `/api/fw-repos-graph` endpoint** (after the existing `/api/infra-graph` endpoint):

```python
async def _api_fw_repos_graph(request: Request) -> _JSONResponse:
    """Repos + packages data for the Mermaid class diagram viewer."""
    if not _FW_REPOS_YAML.exists():
        return _JSONResponse({"repos": {}})
    raw = yaml.safe_load(_FW_REPOS_YAML.read_text()) or {}
    return _JSONResponse({"repos": raw.get("data", {}).get("repos", {})})

app.add_api_route("/api/fw-repos-graph", _api_fw_repos_graph)
```

**B. Replace `fw_repos_cytoscape_view()`** with a simple iframe view:

```python
def fw_repos_mermaid_view() -> rx.Component:
    """Framework Repos view — Mermaid class diagram in an iframe."""
    return rx.box(
        rx.hstack(
            rx.button(
                "Refresh", size="1", variant="soft",
                on_click=AppState.refresh_fw_repos_data,
                title="Re-run fw-repos-visualizer --list and reload data",
            ),
            padding="4px", gap="6px", flex_shrink="0",
            background="var(--gui-bg-panel)",
            border_bottom="1px solid var(--gui-border-subtle)",
        ),
        rx.el.iframe(
            src="/fw_repos_mermaid_viewer.html",
            width="100%",
            height="100%",
            style={"border": "none", "display": "block"},
        ),
        display="flex", flex_direction="column",
        width="100%", height="100%", overflow="hidden",
    )
```

**C. Update `render_left_panel_content()`**: change `fw_repos_cytoscape_view()` → `fw_repos_mermaid_view()`

**D. Remove all Cytoscape-specific fw_repos state, computed vars, event handlers, constants, and menu functions:**

State fields to remove (lines ~4454–4466):
- `fw_repos_positions`, `fw_repos_root_ids`, `fw_repos_collapsed_repos`
- `fw_repos_layout`, `fw_repos_show_lineage`, `fw_repos_show_source_badge`
- `fw_repos_show_url`, `fw_repos_show_packages`, `fw_repos_show_pkg_type_badge`
- `fw_repos_show_exportable`, `fw_repos_merge_duplicates`

Computed vars to remove:
- `fw_repos_layout_label`, `fw_repos_cyto_layout`
- `framework_repos_data_keys` — keep only if used; it's used in collapse menu which is being removed → **remove**

Event handlers to remove:
- `save_fw_repos_layout`, `reset_fw_repos_layout`
- `toggle_fw_repo_collapsed`, `collapse_all_fw_repos`, `expand_all_fw_repos`
- `set_fw_repos_layout_by_label`
- `toggle_fw_repos_show_lineage` through `toggle_fw_repos_merge_duplicates` (7 handlers)

Constants to remove:
- `_FW_REPOS_CYTOSCAPE_STYLESHEET`, `_FW_REPOS_CYTOSCAPE_INIT_JS`, `_FW_REPOS_SAVE_LAYOUT_JS`
- `_FW_REPOS_LAYOUT` path constant

UI functions to remove:
- `_fw_repos_appearance_menu`, `_fw_repos_collapse_menu`, `fw_repos_cytoscape_view`

`_save_current_config()` — remove all fw_repos keys except leave `framework_repos_data` untouched (it's not saved there anyway — it's populated from the YAML file on load).

`_load_state()` — remove all fw_repos restore lines (they'll no longer exist as state fields).

**E. `refresh_fw_repos_data`** — keep the handler but also trigger an iframe reload. Since the iframe has `src="/fw_repos_mermaid_viewer.html"`, the JS inside fetches `/api/fw-repos-graph` on load and has its own Refresh button. The Reflex-side `refresh_fw_repos_data` just re-runs the visualizer binary. Then `rx.call_script` can reload the iframe:

```python
async def refresh_fw_repos_data(self):
    if _FW_REPOS_VIZ_BIN.exists():
        subprocess.run([str(_FW_REPOS_VIZ_BIN), "--list"], capture_output=True)
    yield rx.call_script(
        "var f=document.querySelector('iframe[src*=\"fw_repos\"]'); if(f) f.contentWindow.load();"
    )
```

**F. Remove `state/fw-repos-layout.yaml`** — no longer needed.

**G. Update `_explorer_root_selector()`** — no label change needed (still "Framework Repos").

## Execution Order

1. Add the API endpoint to `homelab_gui.py` (near other `app.add_api_route` calls)
2. Create `assets/fw_repos_mermaid_viewer.html`
3. Replace `fw_repos_cytoscape_view` with `fw_repos_mermaid_view` in `homelab_gui.py`
4. Update `render_left_panel_content()` reference
5. Remove all dead Cytoscape fw_repos code (state fields, vars, handlers, constants, menus)
6. Update `_save_current_config` / `_load_state` to remove dead keys
7. Update `refresh_fw_repos_data` to trigger iframe reload
8. Delete `state/fw-repos-layout.yaml`

## Verification

```bash
./run -A de3-gui
# Open browser → Framework Repos dropdown
# Should show a Mermaid class diagram with repos as classes
# Each class shows +embedded and -external packages
# Inheritance arrows for created_by relationships
# Refresh button re-runs visualizer and reloads diagram
```
