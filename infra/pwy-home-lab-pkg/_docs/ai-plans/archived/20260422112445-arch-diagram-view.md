# Plan: Architectural Diagram View for de3-gui

## Objective

Add a new "Arch Diagram" visualization framework to the de3-gui left panel. Like the
other views, it renders the **live infra data** from `_ALL_NODES_CACHE` and
`_DEPENDENCIES_CACHE` — no manual component list. Unlike the Nested Networks or Tree
views, it organises nodes into **swimlane layers** (e.g. Network, On-Prem, Cloud) based
on path-prefix rules in a config file, producing a diagram that looks like a typical
draw.io / Lucidchart architectural diagram. A toolbar above the canvas exposes a
**File → Export → draw.io** menu that downloads the diagram as `.drawio` XML.

---

## Context

### Existing visualization system

- Three frameworks in `VIZ_FRAMEWORKS` (homelab_gui.py:524): `reflex`, `cytoscape`,
  `reactflow`.
- Adding a framework (documented at homelab_gui.py:519):
  1. Register entry in `VIZ_FRAMEWORKS`.
  2. Implement `<key>_view() → rx.Component`.
  3. Add case to `render_left_panel_content()`.
  4. Update `set_view_mode()` (homelab_gui.py:5786) and `view_mode` computed var
     (homelab_gui.py:4302).
- All views use native npm packages via `NoSSRComponent` — the iframe / CDN approach
  was removed (ai-log: 20260308190714) because CDN iframes never rendered correctly.

### React Flow (already installed)

- `reactflow@11.11.4` installed and working.
- `_ReactFlowGraph(NoSSRComponent)` wraps ReactFlow (homelab_gui.py:324).
- React Flow v11 has a built-in `type: "group"` node for swimlane containers; child
  nodes use `parentNode: "<group-id>"` and positions **relative to the parent**.
- No new npm packages needed; all layout computed in Python (existing pattern).

### Live infra data (auto-derived, not manual)

- `_ALL_NODES_CACHE` — scanned once at import; every node has `path`, `name`, `depth`,
  `provider`, `has_terragrunt`.
- `_DEPENDENCIES_CACHE: dict[str, list[str]]` — Terraform dependency graph
  (source path → list of target paths), built at import.
- Components in the arch diagram are **derived from `_ALL_NODES_CACHE`** by selecting
  nodes at a configurable depth and grouping them by which layer's path-prefix rule they
  match. This mirrors how the other views (Cytoscape, React Flow Tree) work.
- Connections are **derived from `_DEPENDENCIES_CACHE`** filtered to node pairs where
  both endpoints are among the shown components.

### Config file role

`arch_diagram_config.yaml` defines **how** to map infra paths to layers (swimlanes) and
controls styling and layout. It does **not** enumerate components — those come from the
live infra scan. This parallels the provider-filter config pattern in `de3-gui-pkg.yaml`.

### draw.io XML format

Simple mxGraph XML: `<mxGraphModel><root>` containing `<mxCell>` elements.
`vertex="1"` for shapes, `edge="1"` for connectors, geometry in `<mxGeometry>`.
Swimlane containers use `style="swimlane;"`. Generated with stdlib
`xml.etree.ElementTree` — no new pip dependencies.

---

## Open Questions

None — ready to proceed.

---

## Files to Create / Modify

---

### `infra/de3-gui-pkg/_config/arch_diagram_config.yaml` — create

Top-level key: `arch_diagram`. Controls layer definitions, component depth, styling, and
connection display. **Does not list components** — those are auto-derived from infra scan.

```yaml
arch_diagram:
  # Layout direction for swimlane arrangement: LR (left→right) or TB (top→bottom)
  direction: LR

  # Depth in the infra path at which nodes become diagram "components".
  # 0 = package root (proxmox-pkg, maas-pkg, …)
  # 1 = first sub-level (proxmox-pkg/_stack/proxmox, …)  ← recommended
  # 2 = second sub-level (proxmox-pkg/_stack/proxmox/pwy-homelab, …)
  component_depth: 1

  # Whether to draw edges from the Terraform dependency graph.
  # Only edges where both endpoints resolve to shown components are drawn.
  show_connections: true

  # Swimlane layer definitions.
  # Each layer matches infra paths by prefix (first matching layer wins).
  # Nodes that match no layer go to the implicit "Other" layer at the end.
  layers:
    - id: network
      label: "Network"
      color: "#EEF2FF"      # background fill
      stroke: "#4338CA"     # border / header colour
      order: 1
      path_prefixes:
        - unifi-pkg/

    - id: on_prem
      label: "On-Premise Compute"
      color: "#FFF7ED"
      stroke: "#E07000"
      order: 2
      path_prefixes:
        - proxmox-pkg/
        - maas-pkg/

    - id: cloud
      label: "Cloud"
      color: "#EFF6FF"
      stroke: "#4285F4"
      order: 3
      path_prefixes:
        - gcp-pkg/
        - aws-pkg/
        - azure-pkg/

    - id: orchestration
      label: "Orchestration"
      color: "#F0FDF4"
      stroke: "#16A34A"
      order: 4
      path_prefixes:
        - null-pkg/

  # Styling overrides per provider (accent colour for component boxes).
  # Falls back to PROVIDER_ACCENT colours from the main app config when absent.
  provider_styles:
    proxmox: { color: "#E07000" }
    maas:    { color: "#7C3AED" }
    unifi:   { color: "#4338CA" }
    gcp:     { color: "#4285F4" }
    aws:     { color: "#FF9900" }
    azure:   { color: "#0078D4" }
    "null":  { color: "#6B7280" }
```

---

### `infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py` — modify

Eight independent additions in execution order.

---

#### A. Config loader + module-level cache (near line ~280, after existing config helpers)

```python
# ---------------------------------------------------------------------------
# Arch-diagram config — loaded once at import
# ---------------------------------------------------------------------------

def _load_arch_diagram_config() -> dict:
    """Load arch_diagram_config.yaml; return 'arch_diagram' sub-dict or {}."""
    cfg_path = Path(__file__).parent.parent.parent / "_config" / "arch_diagram_config.yaml"
    if not cfg_path.exists():
        return {}
    try:
        raw = yaml.safe_load(cfg_path.read_text()) or {}
        return raw.get("arch_diagram", {})
    except Exception:
        return {}


_ARCH_DIAGRAM_CONFIG: dict = _load_arch_diagram_config()
```

---

#### B. Infra-data → arch diagram element builder (after `_init_reactflow_cache()`, ~line 3792)

This function reads `_ALL_NODES_CACHE` and `_DEPENDENCIES_CACHE` and produces React Flow
nodes + edges. The config controls layer assignment and depth, not the component list.

```python
# ---------------------------------------------------------------------------
# Arch diagram layout builder — auto-derives components from live infra data
# ---------------------------------------------------------------------------

# Provider accent colours (mirrors PROVIDER_ACCENT used elsewhere in the file)
_ARCH_PROVIDER_ACCENT: dict[str, str] = {
    "proxmox": "#E07000",
    "maas":    "#7C3AED",
    "unifi":   "#4338CA",
    "gcp":     "#4285F4",
    "aws":     "#FF9900",
    "azure":   "#0078D4",
    "null":    "#6B7280",
}


def _build_arch_diagram_elements(
    nodes_cache: list[dict],
    deps_cache: dict[str, list[str]],
    config: dict,
) -> dict:
    """Compute React Flow nodes + edges for the architectural diagram.

    Components are nodes from nodes_cache at component_depth whose path matches
    a layer's path_prefixes. Connections come from deps_cache filtered to
    component-to-component pairs.
    """
    if not config:
        return {"nodes": [], "edges": []}

    direction: str      = config.get("direction", "LR")
    target_depth: int   = config.get("component_depth", 1)
    show_conns: bool    = config.get("show_connections", True)
    layers_cfg: list    = sorted(config.get("layers", []), key=lambda l: l.get("order", 99))
    prov_styles: dict   = config.get("provider_styles", {})

    # ── Step 1: select component nodes at target_depth ───────────────────────
    comp_nodes = [n for n in nodes_cache if n["depth"] == target_depth]

    # ── Step 2: assign each component to a layer ────────────────────────────
    def _match_layer(path: str) -> str | None:
        for lc in layers_cfg:
            for prefix in lc.get("path_prefixes", []):
                if path.startswith(prefix):
                    return lc["id"]
        return None

    layer_to_comps: dict[str, list[dict]] = {lc["id"]: [] for lc in layers_cfg}
    unmatched: list[dict] = []
    for cn in comp_nodes:
        lid = _match_layer(cn["path"])
        if lid:
            layer_to_comps[lid].append(cn)
        else:
            unmatched.append(cn)

    # Add implicit "other" layer if there are unmatched nodes
    if unmatched:
        layers_cfg = layers_cfg + [{"id": "_other", "label": "Other",
                                     "color": "#F8FAFC", "stroke": "#94A3B8"}]
        layer_to_comps["_other"] = unmatched

    # ── Step 3: layout constants ─────────────────────────────────────────────
    COMP_W     = 150
    COMP_H     = 60
    COMP_GAP   = 20    # gap between component boxes inside a layer
    LAYER_PAD  = 24    # inner padding of swimlane
    LAYER_GAP  = 32    # gap between swimlanes
    HEADER_H   = 28    # title bar height

    rf_nodes: list[dict] = []
    rf_edges: list[dict] = []
    comp_id_map: dict[str, str] = {}   # infra path → node id (same as path)

    cursor = 0.0
    for lc in layers_cfg:
        lid   = lc["id"]
        comps = layer_to_comps.get(lid, [])
        n     = max(len(comps), 1)

        if direction == "LR":
            inner_w = COMP_W
            inner_h = n * COMP_H + (n - 1) * COMP_GAP
        else:
            inner_w = n * COMP_W + (n - 1) * COMP_GAP
            inner_h = COMP_H

        sw_w = inner_w + 2 * LAYER_PAD
        sw_h = inner_h + 2 * LAYER_PAD + HEADER_H

        sw_x = cursor if direction == "LR" else 0.0
        sw_y = 0.0    if direction == "LR" else cursor

        # Swimlane group node (built-in React Flow type, no custom nodeTypes needed)
        rf_nodes.append({
            "id":       f"__layer__{lid}",
            "type":     "group",
            "position": {"x": sw_x, "y": sw_y},
            "data":     {"label": lc.get("label", lid)},
            "style": {
                "width":        sw_w,
                "height":       sw_h,
                "background":   lc.get("color", "#F8FAFC"),
                "border":       f"2px solid {lc.get('stroke', '#94A3B8')}",
                "borderRadius": "8px",
                "fontSize":     "12px",
                "fontWeight":   "700",
                "color":        lc.get("stroke", "#334155"),
            },
        })

        for i, cn in enumerate(comps):
            path     = cn["path"]
            provider = cn.get("provider", "")
            pstyle   = prov_styles.get(provider, {})
            accent   = pstyle.get("color", _ARCH_PROVIDER_ACCENT.get(provider, "#64748B"))

            if direction == "LR":
                cx = LAYER_PAD
                cy = HEADER_H + LAYER_PAD + i * (COMP_H + COMP_GAP)
            else:
                cx = LAYER_PAD + i * (COMP_W + COMP_GAP)
                cy = HEADER_H + LAYER_PAD

            rf_nodes.append({
                "id":         path,
                "parentNode": f"__layer__{lid}",
                "extent":     "parent",
                "position":   {"x": cx, "y": cy},
                "data":       {
                    "label":    cn["name"],
                    "provider": provider,
                    "path":     path,
                    "paths":    [path],   # for click handler
                },
                "style": {
                    "width":          COMP_W,
                    "height":         COMP_H,
                    "background":     accent + "1A",   # 10% opacity tint
                    "border":         f"2px solid {accent}",
                    "borderRadius":   "6px",
                    "color":          accent,
                    "fontSize":       "12px",
                    "fontWeight":     "600",
                    "display":        "flex",
                    "alignItems":     "center",
                    "justifyContent": "center",
                    "textAlign":      "center",
                    "padding":        "6px",
                    "cursor":         "pointer",
                },
            })
            comp_id_map[path] = path

        cursor += (sw_w if direction == "LR" else sw_h) + LAYER_GAP

    # ── Step 4: connection edges (from TF dependency graph) ──────────────────
    if show_conns:
        comp_paths = set(comp_id_map.keys())
        seen_edges: set[tuple[str, str]] = set()
        for src_path, targets in deps_cache.items():
            # Resolve src to a component-level path (ancestor at target_depth)
            src_parts = src_path.split("/")
            src_comp  = "/".join(src_parts[:target_depth + 1]) if len(src_parts) > target_depth else src_path
            if src_comp not in comp_paths:
                continue
            for tgt_path in targets:
                tgt_parts = tgt_path.split("/")
                tgt_comp  = "/".join(tgt_parts[:target_depth + 1]) if len(tgt_parts) > target_depth else tgt_path
                if tgt_comp not in comp_paths or tgt_comp == src_comp:
                    continue
                key = (src_comp, tgt_comp)
                if key in seen_edges:
                    continue
                seen_edges.add(key)
                rf_edges.append({
                    "id":     f"arch-dep-{src_comp}--{tgt_comp}",
                    "source": src_comp,
                    "target": tgt_comp,
                    "type":   "smoothstep",
                    "style":  {"stroke": "#94A3B8", "strokeWidth": 1.5},
                    "markerEnd": {"type": "arrowclosed", "color": "#94A3B8"},
                })

    return {"nodes": rf_nodes, "edges": rf_edges}


_ARCH_DIAGRAM_CACHE: dict = _build_arch_diagram_elements(
    _ALL_NODES_CACHE, _DEPENDENCIES_CACHE, _ARCH_DIAGRAM_CONFIG
)
```

---

#### C. draw.io XML export function (after section B, ~line 3900)

Pure Python, stdlib `xml.etree.ElementTree`. No new pip dependencies.
Mirrors the React Flow layout so the exported diagram matches what the user sees.

```python
# ---------------------------------------------------------------------------
# draw.io XML export
# ---------------------------------------------------------------------------

def _generate_drawio_xml(
    nodes_cache: list[dict],
    deps_cache: dict[str, list[str]],
    config: dict,
) -> str:
    """Generate draw.io-compatible mxGraphModel XML from live infra data + config."""
    import xml.etree.ElementTree as ET

    direction: str    = config.get("direction", "LR")
    target_depth: int = config.get("component_depth", 1)
    show_conns: bool  = config.get("show_connections", True)
    layers_cfg: list  = sorted(config.get("layers", []), key=lambda l: l.get("order", 99))
    prov_styles: dict = config.get("provider_styles", {})

    comp_nodes = [n for n in nodes_cache if n["depth"] == target_depth]

    def _match_layer(path: str) -> str | None:
        for lc in layers_cfg:
            for prefix in lc.get("path_prefixes", []):
                if path.startswith(prefix):
                    return lc["id"]
        return None

    layer_to_comps: dict[str, list[dict]] = {lc["id"]: [] for lc in layers_cfg}
    unmatched: list[dict] = []
    for cn in comp_nodes:
        lid = _match_layer(cn["path"])
        if lid:
            layer_to_comps[lid].append(cn)
        else:
            unmatched.append(cn)
    if unmatched:
        layers_cfg = layers_cfg + [{"id": "_other", "label": "Other",
                                     "color": "#F8FAFC", "stroke": "#94A3B8"}]
        layer_to_comps["_other"] = unmatched

    COMP_W    = 150;  COMP_H    = 60
    COMP_GAP  = 20;   LAYER_PAD = 24
    LAYER_GAP = 32;   HEADER_H  = 28

    model = ET.Element("mxGraphModel", dx="1422", dy="762", grid="0",
                        gridSize="10", guides="1", tooltips="1",
                        connect="0", arrows="0", fold="0",
                        page="0", pageScale="1",
                        pageWidth="1169", pageHeight="827",
                        math="0", shadow="0")
    root = ET.SubElement(model, "root")
    ET.SubElement(root, "mxCell", id="0")
    ET.SubElement(root, "mxCell", id="1", parent="0")

    cell_id = 2
    layer_cell_ids: dict[str, str] = {}
    comp_cell_ids:  dict[str, str] = {}

    cursor = 0.0
    for lc in layers_cfg:
        lid   = lc["id"]
        comps = layer_to_comps.get(lid, [])
        n     = max(len(comps), 1)

        if direction == "LR":
            inner_w = COMP_W
            inner_h = n * COMP_H + (n - 1) * COMP_GAP
        else:
            inner_w = n * COMP_W + (n - 1) * COMP_GAP
            inner_h = COMP_H

        sw_w = inner_w + 2 * LAYER_PAD
        sw_h = inner_h + 2 * LAYER_PAD + HEADER_H
        sw_x = cursor if direction == "LR" else 0.0
        sw_y = 0.0    if direction == "LR" else cursor

        stroke = lc.get("stroke", "#94A3B8").lstrip("#")
        fill   = lc.get("color",  "#F8FAFC").lstrip("#")

        sw_cell = ET.SubElement(root, "mxCell",
            id=str(cell_id), value=lc.get("label", lid),
            style=(f"swimlane;startSize={HEADER_H};fillColor=#{fill};"
                   f"strokeColor=#{stroke};fontStyle=1;fontSize=12;"
                   f"rounded=1;arcSize=4;"),
            vertex="1", parent="1")
        ET.SubElement(sw_cell, "mxGeometry",
            x=str(int(sw_x)), y=str(int(sw_y)),
            width=str(sw_w), height=str(sw_h),
            attrib={"as": "geometry"})
        layer_cell_ids[lid] = str(cell_id)
        cell_id += 1

        for i, cn in enumerate(comps):
            path     = cn["path"]
            provider = cn.get("provider", "")
            pstyle   = prov_styles.get(provider, {})
            accent   = pstyle.get("color", _ARCH_PROVIDER_ACCENT.get(provider, "#64748B"))
            c_hex    = accent.lstrip("#")

            cx = LAYER_PAD if direction == "LR" else LAYER_PAD + i * (COMP_W + COMP_GAP)
            cy = (HEADER_H + LAYER_PAD + i * (COMP_H + COMP_GAP)
                  if direction == "LR" else HEADER_H + LAYER_PAD)

            c_cell = ET.SubElement(root, "mxCell",
                id=str(cell_id), value=cn["name"],
                style=(f"rounded=1;arcSize=10;"
                       f"fillColor=#{c_hex}1A;strokeColor=#{c_hex};"
                       f"fontStyle=1;fontSize=12;fontColor=#{c_hex};"),
                vertex="1", parent=layer_cell_ids[lid])
            ET.SubElement(c_cell, "mxGeometry",
                x=str(cx), y=str(cy),
                width=str(COMP_W), height=str(COMP_H),
                attrib={"as": "geometry"})
            comp_cell_ids[path] = str(cell_id)
            cell_id += 1

        cursor += (sw_w if direction == "LR" else sw_h) + LAYER_GAP

    if show_conns:
        comp_paths = set(comp_cell_ids.keys())
        seen: set[tuple[str, str]] = set()
        for src_path, targets in deps_cache.items():
            src_parts = src_path.split("/")
            src_comp  = "/".join(src_parts[:target_depth + 1]) if len(src_parts) > target_depth else src_path
            if src_comp not in comp_paths:
                continue
            for tgt_path in targets:
                tgt_parts = tgt_path.split("/")
                tgt_comp  = "/".join(tgt_parts[:target_depth + 1]) if len(tgt_parts) > target_depth else tgt_path
                if tgt_comp not in comp_paths or tgt_comp == src_comp:
                    continue
                key = (src_comp, tgt_comp)
                if key in seen:
                    continue
                seen.add(key)
                e_cell = ET.SubElement(root, "mxCell",
                    id=str(cell_id), value="",
                    style="edgeStyle=orthogonalEdgeStyle;rounded=0;",
                    edge="1",
                    source=comp_cell_ids[src_comp],
                    target=comp_cell_ids[tgt_comp],
                    parent="1")
                ET.SubElement(e_cell, "mxGeometry", relative="1",
                              attrib={"as": "geometry"})
                cell_id += 1

    return ET.tostring(model, encoding="unicode", xml_declaration=False)
```

---

#### D. Starlette API route for draw.io download (near existing API route registrations)

```python
async def _api_arch_diagram_drawio(request: Request) -> Response:
    """Return draw.io XML as a downloadable .drawio file."""
    from starlette.responses import Response as _StarletteResponse
    xml = _generate_drawio_xml(_ALL_NODES_CACHE, _DEPENDENCIES_CACHE, _ARCH_DIAGRAM_CONFIG)
    return _StarletteResponse(
        content=xml,
        media_type="application/xml",
        headers={"Content-Disposition": 'attachment; filename="arch-diagram.drawio"'},
    )

app._api.add_route("/api/arch-diagram-drawio", _api_arch_diagram_drawio, methods=["GET"])
```

---

#### E. AppState computed vars (in AppState class, near other reactflow/cytoscape vars)

```python
@rx.var
def arch_diagram_nodes(self) -> list[dict]:
    """React Flow nodes for the arch diagram view."""
    return _ARCH_DIAGRAM_CACHE.get("nodes", [])

@rx.var
def arch_diagram_edges(self) -> list[dict]:
    """React Flow edges for the arch diagram view."""
    return _ARCH_DIAGRAM_CACHE.get("edges", [])
```

---

#### F. VIZ_FRAMEWORKS, `view_mode`, `set_view_mode` (three small edits)

**VIZ_FRAMEWORKS** (homelab_gui.py:524) — append:
```python
{
    "key": "archdiagram",
    "label": "Arch Diagram",
    "description": "Architectural layers diagram, auto-derived from infra data",
},
```

**`view_mode` computed var** (homelab_gui.py:4302) — add case:
```python
if self.viz_framework == "archdiagram":
    return "archdiagram"
```

**`set_view_mode`** (homelab_gui.py:5786) — add branch:
```python
elif mode == "archdiagram":
    self.viz_framework = "archdiagram"
```

---

#### G. Canvas toolbar + view function

**`_ARCH_DIAGRAM_NODE_CLICK_JS`** — add near `_REACTFLOW_NODE_CLICK_JS` (~line 11908):

```python
_ARCH_DIAGRAM_NODE_CLICK_JS = r"""(event, node) => {
  // Group (swimlane) nodes have id prefixed __layer__ and no selectable path.
  if (!node.id || node.id.startsWith('__layer__')) return;
  window._rfSelectedPath = node.id;
  var trigger = document.getElementById('rf-node-trigger');
  if (trigger) trigger.click();
}"""
```

**`_arch_diagram_toolbar()`** — new helper function for the menu bar rendered above the
canvas. Uses a Reflex popover to simulate a "File" menu with an Export option. The
download link points to `/api/arch-diagram-drawio` (served by the Starlette backend on
port 9000, same host/port as other API endpoints).

```python
def _arch_diagram_toolbar() -> rx.Component:
    """Thin menu bar rendered above the arch diagram canvas.

    Contains a 'File' dropdown with an Export → draw.io option.
    """
    return rx.hstack(
        # ── File menu ──────────────────────────────────────────────────────
        rx.popover.root(
            rx.popover.trigger(
                rx.button(
                    rx.hstack(
                        rx.text("File", font_size="12px"),
                        rx.text("▾", font_size="10px"),
                        spacing="1",
                    ),
                    variant="ghost",
                    size="1",
                    color_scheme="gray",
                    cursor="pointer",
                    padding="4px 8px",
                ),
            ),
            rx.popover.content(
                rx.vstack(
                    rx.text("Export", font_size="10px", font_weight="700",
                            color="var(--gui-text-dim)", text_transform="uppercase",
                            letter_spacing="0.07em", padding="4px 8px 2px"),
                    rx.link(
                        rx.hstack(
                            rx.text("draw.io / diagrams.net (.drawio)",
                                    font_size="12px", color="var(--gui-text-primary)"),
                            padding="6px 12px",
                            width="100%",
                            _hover={"background": "var(--gray-3)"},
                            border_radius="4px",
                        ),
                        href="/api/arch-diagram-drawio",
                        is_external=False,
                        text_decoration="none",
                    ),
                    spacing="0",
                    padding="4px",
                    min_width="220px",
                ),
                padding="4px",
            ),
        ),
        # ── Spacer + info label ────────────────────────────────────────────
        rx.spacer(),
        rx.text(
            "Arch Diagram — auto-derived from infra data",
            font_size="10px",
            color="var(--gui-text-dim)",
            padding_right="8px",
        ),
        # ── Toolbar styles ─────────────────────────────────────────────────
        width="100%",
        height="32px",
        align="center",
        padding="0 8px",
        background="var(--gray-2)",
        border_bottom="1px solid var(--gray-5)",
        flex_shrink="0",
    )
```

**`arch_diagram_view()`** — new view function, placed after `reactflow_view()` (~line 11940):

```python
def arch_diagram_view() -> rx.Component:
    """Architectural diagram rendered via React Flow.

    Components are auto-derived from _ALL_NODES_CACHE at component_depth.
    Layers are defined in arch_diagram_config.yaml by path prefix rules.
    Connections come from _DEPENDENCIES_CACHE filtered to component pairs.
    A toolbar above the canvas provides File → Export → draw.io.
    """
    return rx.vstack(
        _arch_diagram_toolbar(),
        rx.box(
            _ReactFlowGraph.create(
                nodes=AppState.arch_diagram_nodes,
                edges=AppState.arch_diagram_edges,
                fit_view=True,
                nodes_draggable=False,
                nodes_connectable=False,
                rf_style={"width": "100%", "height": "100%", "background": "#F8FAFC"},
                on_node_click_cb=Var(_js_expr=_ARCH_DIAGRAM_NODE_CLICK_JS),
            ),
            width="100%",
            flex="1",
            overflow="hidden",
        ),
        width="100%",
        height="100%",
        spacing="0",
        overflow="hidden",
    )
```

**`render_left_panel_content()`** (homelab_gui.py:12621) — add case:

```python
("archdiagram", arch_diagram_view()),
```

---

#### H. `README.instructions.md` update

1. Add `archdiagram` row to the framework table:
   ```
   | `archdiagram` | Arch Diagram | React Flow group nodes, Python-computed positions from live infra |
   ```

2. Add to API endpoints table:
   ```
   | `GET /api/arch-diagram-drawio` | draw.io mxGraphModel XML | arch diagram toolbar export |
   ```

3. Add "Arch Diagram" subsection after the mxGraph viewer section documenting:
   - Config file location and key fields
   - Component derivation approach
   - Toolbar and export mechanism

---

## Execution Order

1. Create `arch_diagram_config.yaml`.
2. Add config loader + `_ARCH_DIAGRAM_CONFIG` (Section A).
3. Add `_ARCH_PROVIDER_ACCENT`, `_build_arch_diagram_elements()`, `_ARCH_DIAGRAM_CACHE` (Section B).
4. Add `_generate_drawio_xml()` (Section C).
5. Add Starlette handler + route registration (Section D).
6. Add AppState computed vars `arch_diagram_nodes` / `arch_diagram_edges` (Section E).
7. Register in VIZ_FRAMEWORKS; patch `view_mode`; patch `set_view_mode` (Section F).
8. Add `_ARCH_DIAGRAM_NODE_CLICK_JS`, `_arch_diagram_toolbar()`, `arch_diagram_view()`;
   wire `render_left_panel_content()` (Section G).
9. Update `README.instructions.md` (Section H).

---

## Verification

```bash
# 1. Start the app
cd infra/de3-gui-pkg/_application/de3-gui
make run

# 2. Open http://localhost:9080
# 3. In the view-mode dropdown, confirm "Arch Diagram" appears.
# 4. Switch to Arch Diagram:
#    - Swimlane containers render with coloured headers.
#    - Provider component boxes appear inside the correct layer.
#    - TF dependency edges appear between component boxes (if show_connections: true).
# 5. Click a component box → right panel updates with that unit's params.
# 6. Click layer/swimlane group node → no selection change (id starts with __layer__).
# 7. Click "File" in toolbar → dropdown opens with "Export" section.
# 8. Click "draw.io / diagrams.net (.drawio)" → .drawio file downloads.
# 9. Open the .drawio file in https://app.diagrams.net or draw.io desktop → diagram renders
#    with the same layers and components as the in-app view.
# 10. No console errors in browser DevTools.
```

---

## Notes and Future Enhancements

- **Depth toggle**: adding a slider in the toolbar to change `component_depth` at runtime
  would let users drill down from package-level (depth 0) to sub-group level (depth 2+).
- **@maxgraph/core**: if a fully-editable in-app draw.io canvas is wanted later,
  `@maxgraph/core` (MIT, pre-1.0) can replace the React Flow renderer while reusing
  the same config and XML export code.
- **Icon support**: custom node types in React Flow (extending `_ReactFlowGraph` with
  a `node_types` prop) could add SVG icons per provider. Deferred to keep this change
  minimal.
- **Lucidchart**: Lucidchart can import draw.io XML directly, so no separate export
  format is needed.
