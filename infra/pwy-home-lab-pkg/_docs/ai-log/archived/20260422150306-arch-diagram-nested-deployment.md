# arch-diagram-nested-deployment

**Plan**: `infra/pwy-home-lab-pkg/_docs/ai-plans/arch-diagram-nested-deployment.md`

## What was done

Redesigned the Arch Diagram view as a nested physical deployment diagram with two rendering surfaces.

### Files changed

**`infra/de3-gui-pkg/_application/de3-gui/requirements.txt`**
- Added `drawpyo>=0.2.5`

**`infra/de3-gui-pkg/_config/arch_diagram_config.yaml`**
- Replaced `component_depth: 1` with `min_depth: 2` / `max_depth: 4`
- Added `icon_map` section mapping `module_source_short` → draw.io shape style fragments
- Added `provider_icon_fallbacks` section for provider-level fallbacks

**`infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`**
- Added `_drawio_shape()` helper — config-driven shape lookup (exact → wildcard → provider fallback)
- Rewrote `_build_arch_diagram_elements()` — nested React Flow layout (zone → container → leaf)
  with recursive size computation and depth-range filtering
- Deleted static `_ARCH_DIAGRAM_CACHE` — replaced by reactive computed vars
- Rewrote `_generate_drawio_xml()` — now uses drawpyo with real cloud shape stencils
  (mxgraph.cisco.*, mxgraph.aws4.*, mxgraph.gcp2.*, etc.)
- Added export format registry: `_ARCH_CONFIG_DIR`, `_ARCH_EXPORT_DEFAULT_DIR`,
  `_ARCH_EXPORT_FORMATS`, `_ARCH_GENERATORS`
- Added AppState vars: `arch_direction`, `arch_min_depth`, `arch_max_depth`,
  `arch_show_connections`, `arch_export_dir`, `arch_export_status`
- Added computed vars: `_arch_cfg()`, reactive `arch_diagram_nodes`/`arch_diagram_edges`,
  `arch_export_urls`, `arch_export_dir_label`
- Added event handlers: `set_arch_direction`, `set_arch_min_depth`, `set_arch_max_depth`,
  `toggle_arch_connections`, `set_arch_export_dir`, `export_arch_diagram`
- Updated `_ARCH_DIAGRAM_NODE_CLICK_JS` — `__layer__` → `__zone__`
- Added `_arch_export_menu_item()` helper function
- Rewrote `_arch_diagram_toolbar()` — now has File menu (Save + Open-in-browser), folder
  picker popover, Dir toggle (LR/TB), Min/Max depth sliders, Conn toggle, save status display
- Replaced `_api_arch_diagram_drawio` with `_api_arch_diagram_export` — dispatches via
  `_ARCH_GENERATORS`, supports `format`, `direction`, `min_depth`, `max_depth`,
  `show_connections` query params

**`.gitignore`**
- Added `infra/de3-gui-pkg/_config/tmp/` so exported diagram files are never committed

## Fixes found during execution

- drawpyo 0.2.5 does not accept `parent` and `position_rel_to_parent` as constructor kwargs —
  they must be set as properties after construction
- drawpyo Edge does not support `endFill` via `apply_style_string` — replaced with direct
  property assignment (`strokeColor`, `strokeWidth`, `endArrow`)
