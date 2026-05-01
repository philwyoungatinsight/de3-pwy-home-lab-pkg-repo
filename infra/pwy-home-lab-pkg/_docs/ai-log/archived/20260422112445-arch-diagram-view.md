# 20260422112445 — arch-diagram-view

## What was done

Implemented the "Arch Diagram" visualization framework for de3-gui. Adds a new
swimlane-based architectural diagram view that auto-derives components from live infra
data (`_ALL_NODES_CACHE`) and connections from the Terraform dependency graph
(`_DEPENDENCIES_CACHE`). No manual component list — everything is auto-derived.

## Files created/modified

- **`infra/de3-gui-pkg/_config/arch_diagram_config.yaml`** — new config file defining
  layer/swimlane rules (path prefix → layer assignment), layout direction, component
  depth, and provider accent colours. Top-level key: `arch_diagram`.

- **`infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`** — eight additions:
  - `_load_arch_diagram_config()` + `_ARCH_DIAGRAM_CONFIG` — config loader (Section A)
  - `_ARCH_PROVIDER_ACCENT`, `_build_arch_diagram_elements()`, `_ARCH_DIAGRAM_CACHE` — layout builder (Section B)
  - `_generate_drawio_xml()` — draw.io XML export (Section C)
  - `_api_arch_diagram_drawio()` + route `/api/arch-diagram-drawio` — Starlette handler (Section D)
  - `AppState.arch_diagram_nodes` / `arch_diagram_edges` computed vars (Section E)
  - `VIZ_FRAMEWORKS` entry + `view_mode` + `set_view_mode` patches (Section F)
  - `_ARCH_DIAGRAM_NODE_CLICK_JS`, `_arch_diagram_toolbar()`, `arch_diagram_view()`, `render_left_panel_content()` wire-up (Section G)

- **`infra/de3-gui-pkg/_application/de3-gui/README.instructions.md`** — updated framework
  table (added `archdiagram` row), API endpoint table (added drawio route), and added
  "Left Panel — Arch Diagram Framework" subsection documenting config, component
  derivation, toolbar, and click behaviour.

## Key decisions

- Used React Flow `type: "group"` (built-in) for swimlane containers — no custom nodeTypes needed.
- Positions computed in Python (same pattern as existing `_build_reactflow_elements`).
- draw.io export via stdlib `xml.etree.ElementTree` — no new pip dependencies.
- Clicking swimlane group nodes (`__layer__` prefix) is a no-op; only component boxes are selectable.
- The `_ARCH_DIAGRAM_CACHE` is module-level (computed once at import), matching the pattern
  for `_RF_DATA_CACHE` and `_SYNTHETIC_COMPOUND_ELEMENTS`.
