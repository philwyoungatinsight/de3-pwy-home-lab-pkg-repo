# Plan: Nested Physical Deployment Diagram with Cloud Icons

## Objective

Redesign the Arch Diagram view as a nested physical deployment diagram with two
complementary rendering surfaces:

1. **In-browser (React Flow)** — nested boxes with zone/provider/environment containment,
   interactive toolbar controls for depth range, direction, and connection visibility.
2. **draw.io export (drawpyo)** — the same hierarchy rendered with real cloud-specific and
   on-prem icons (AWS S3, GKE cluster, Proxmox VM, Cisco server, UniFi switch, etc.) using
   draw.io's built-in shape libraries. Downloaded as `.drawio` or opened live in
   `app.diagrams.net` from the toolbar.

## Context

### Current implementation

`_build_arch_diagram_elements()` (line 3831) renders one depth level, flat swimlanes.
`_generate_drawio_xml()` (line 4004) hand-crafts mxGraphModel XML with no shape library support.
`_arch_diagram_toolbar()` (line 12296) has only a File → Export → draw.io link.
`arch_diagram_nodes` / `arch_diagram_edges` (lines 4787/4791) return from a static module-level
cache; they have no reactive dependencies — settings changes require app restart.

### Node depth structure

| depth | example path | represents |
|-------|------|------|
| 0 | `pwy-home-lab-pkg` | synthetic package root |
| 1 | `pwy-home-lab-pkg/_stack/proxmox` | provider |
| 2 | `pwy-home-lab-pkg/_stack/proxmox/pwy-homelab` | environment |
| 3 | `pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes` | group/folder |
| 4 | `pwy-home-lab-pkg/_stack/proxmox/pwy-homelab/pve-nodes/pve-1` | physical resource |

Each node has: `path`, `depth`, `name`, `provider`, `has_terragrunt`, `module_source_short`.
`module_source_short` is the last segment of the HCL module path — e.g.
`proxmox_virtual_environment_vm`, `aws_s3_bucket`, `google_container_cluster`.

### drawpyo

`pip install drawpyo>=0.2.5` — Python ≥ 3.10, MIT.
Programmatically generates `.drawio` XML files.
Supports `parent` / `position_rel_to_parent` for nested containers.
Style strings from draw.io ("Edit Style" copy-paste) work directly via `obj.apply_style_string()`.
Draw.io built-in shape stencils (`shape=mxgraph.aws4.*`, `shape=mxgraph.gcp2.*`,
`shape=mxgraph.kubernetes.*`, `shape=mxgraph.cisco.*`) are referenced by style string —
drawpyo doesn't need to load any external mxlibrary file; draw.io's own renderer resolves them
when the `.drawio` file is opened.
Output: `file.write()` writes to disk. For in-memory generation, write to a temp file and read it.

### mxgraph_viewer.html

Already exists at `assets/mxgraph_viewer.html`. Uses raw mxGraph v4.2.2 (open-source core).
**Does NOT support cloud stencils** (AWS/GCP/K8s shapes) — those live in draw.io's app layer.
Replacing it for the arch diagram view is not practical without bundling the full draw.io app.

### diagrams.net live viewer

`https://app.diagrams.net/?url=<encoded-url>` loads a `.drawio` file from any URL.
The toolbar can expose an "Open in draw.io" button that builds this URL from the API endpoint:
`https://app.diagrams.net/?url=http%3A%2F%2Flocalhost%3A3000%2Fapi%2Farch-diagram-drawio%3F...`
This gives the user full icon rendering in their browser via the official draw.io web app,
without requiring self-hosting draw.io.

### Existing module types (seeded into `icon_map` in YAML config)

The table below is the default `icon_map` content for `arch_diagram_config.yaml`.
No shape names appear in Python — they all live in the YAML file.

| module_source_short | provider | draw.io shape |
|---|---|---|
| `proxmox_virtual_environment_vm` | proxmox | `shape=mxgraph.cisco.servers.virtual_machine` |
| `proxmox_virtual_environment_download_file` | proxmox | `shape=mxgraph.cisco.storage.cd_dvd_tape` |
| `proxmox_virtual_environment_file` | proxmox | `shape=mxgraph.cisco.storage.cd_dvd_tape` |
| `maas_machine` | maas | `shape=mxgraph.cisco.servers.standard_server` |
| `maas_lifecycle_*` | maas | `shape=mxgraph.cisco.servers.standard_server` |
| `unifi_device` | unifi | `shape=mxgraph.cisco.switches.workgroup_switch` |
| `unifi_network` | unifi | `shape=mxgraph.cisco.firewalls.firewall` |
| `unifi_port_profile` | unifi | `shape=mxgraph.cisco.switches.workgroup_switch` |
| `routeros_switch` | routeros | `shape=mxgraph.cisco.routers.router` |
| `aws_s3_bucket` | aws | `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.s3` |
| `aws_s3_object` | aws | `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.s3` |
| `google_container_cluster` | gcp | `shape=mxgraph.gcp2.kubernetes_engine` |
| `google_storage_bucket` | gcp | `shape=mxgraph.gcp2.cloud_storage` |
| `google_storage_bucket_object` | gcp | `shape=mxgraph.gcp2.cloud_storage` |
| `azurerm_storage_container` | azure | `shape=mxgraph.azure.storage` |
| `azurerm_storage_blob` | azure | `shape=mxgraph.azure.storage` |
| `null_resource__*` | null | `shape=mxgraph.cisco.servers.application_server` |
| _(depth container — no module)_ | any | `swimlane` style |

## Open Questions

None — ready to proceed.

## Files to Create / Modify

### `infra/de3-gui-pkg/_application/de3-gui/requirements.txt` — modify

Add drawpyo:

```
reflex>=0.6.0
pyyaml>=6.0
reflex-monaco>=0.0.3
drawpyo>=0.2.5
```

### `infra/de3-gui-pkg/_config/arch_diagram_config.yaml` — modify

Replace `component_depth: 1` with `min_depth`/`max_depth`, and add `icon_map` +
`provider_icon_fallbacks` sections. The icon_map keys are `module_source_short` values
(the last segment of the HCL module path). Values are raw draw.io style string fragments
that are passed directly to drawpyo's `apply_style_string()`. A trailing `;` is required.
Prefix keys ending in `*` match any module_source_short that starts with that prefix.

```yaml
arch_diagram:
  direction: LR
  min_depth: 2
  max_depth: 4
  show_connections: true

  # module_source_short → draw.io style fragment.
  # Shape names reference draw.io's built-in stencil libraries; no external
  # mxlibrary loading is needed — draw.io resolves stencils at open time.
  # Use "*" suffix for prefix matching (e.g. "maas_lifecycle_*" matches any lifecycle module).
  icon_map:
    proxmox_virtual_environment_vm:            "shape=mxgraph.cisco.servers.virtual_machine;"
    proxmox_virtual_environment_download_file: "shape=mxgraph.cisco.storage.cd_dvd_tape;"
    proxmox_virtual_environment_file:          "shape=mxgraph.cisco.storage.cd_dvd_tape;"
    maas_machine:                              "shape=mxgraph.cisco.servers.standard_server;"
    "maas_lifecycle_*":                        "shape=mxgraph.cisco.servers.standard_server;"
    maas_machine_release:                      "shape=mxgraph.cisco.servers.standard_server;"
    unifi_device:                              "shape=mxgraph.cisco.switches.workgroup_switch;"
    unifi_network:                             "shape=mxgraph.cisco.firewalls.firewall;"
    unifi_port_profile:                        "shape=mxgraph.cisco.switches.workgroup_switch;"
    routeros_switch:                           "shape=mxgraph.cisco.routers.router;"
    aws_s3_bucket:      "shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.s3;"
    aws_s3_object:      "shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.s3;"
    google_container_cluster:     "shape=mxgraph.gcp2.kubernetes_engine;"
    google_storage_bucket:        "shape=mxgraph.gcp2.cloud_storage;"
    google_storage_bucket_object: "shape=mxgraph.gcp2.cloud_storage;"
    azurerm_storage_container:    "shape=mxgraph.azure.storage;"
    azurerm_storage_blob:         "shape=mxgraph.azure.storage;"
    "null_resource__*":           "shape=mxgraph.cisco.servers.application_server;"

  # Provider-level fallback when module_source_short has no entry in icon_map.
  provider_icon_fallbacks:
    proxmox: "shape=mxgraph.cisco.servers.standard_server;"
    maas:    "shape=mxgraph.cisco.servers.standard_server;"
    unifi:   "shape=mxgraph.cisco.switches.workgroup_switch;"
    routeros: "shape=mxgraph.cisco.routers.router;"
    gcp:    "shape=mxgraph.gcp2.cloud_generic;"
    aws:    "shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.general;"
    azure:  "shape=mxgraph.azure.azure_generic;"
    "null": "shape=mxgraph.cisco.servers.application_server;"

  layers:            # (keep existing — no changes)
    ...
  provider_styles:   # (keep existing — no changes)
    ...
```

### `infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py` — modify

#### A. Add config-driven `_drawio_shape()` helper (after `_ARCH_PROVIDER_ACCENT`, ~line 3829)

No hardcoded shape dict in Python. The mapping lives entirely in `arch_diagram_config.yaml`
under `icon_map` and `provider_icon_fallbacks`. The helper reads from `_ARCH_DIAGRAM_CONFIG`
which is already loaded at import time.

```python
def _drawio_shape(module_source_short: str, provider: str, config: dict) -> str:
    """Return draw.io shape style fragment for a leaf node.

    Lookup order:
    1. Exact key match in config['icon_map']
    2. Wildcard prefix match (keys ending in '*') in config['icon_map']
    3. Provider fallback in config['provider_icon_fallbacks']
    4. Generic rounded rectangle
    """
    icon_map: dict[str, str]      = config.get("icon_map", {})
    fallbacks: dict[str, str]     = config.get("provider_icon_fallbacks", {})

    # 1. Exact match
    if module_source_short in icon_map:
        return icon_map[module_source_short]

    # 2. Wildcard prefix match (key ends with "*")
    for key, val in icon_map.items():
        if key.endswith("*") and module_source_short.startswith(key[:-1]):
            return val

    # 3. Provider fallback
    if provider in fallbacks:
        return fallbacks[provider]

    return "rounded=1;"
```

#### B. Rewrite `_build_arch_diagram_elements()` — complete rewrite (line 3831)

Replace the entire function body with the nested React Flow layout algorithm:

```python
def _build_arch_diagram_elements(
    nodes_cache: list[dict],
    deps_cache: dict[str, list[str]],
    config: dict,
) -> dict:
    if not config:
        return {"nodes": [], "edges": []}

    direction   = config.get("direction", "LR")
    min_depth   = int(config.get("min_depth", 2))
    max_depth   = int(config.get("max_depth", 4))
    show_conns  = bool(config.get("show_connections", True))
    layers_cfg  = sorted(config.get("layers", []), key=lambda l: l.get("order", 99))
    prov_styles = config.get("provider_styles", {})

    if min_depth > max_depth:
        min_depth, max_depth = max_depth, min_depth

    shown = [n for n in nodes_cache if min_depth <= n["depth"] <= max_depth]
    node_by_path: dict[str, dict] = {n["path"]: n for n in shown}

    def _depth1_prefix(path: str) -> str:
        parts = path.split("/")
        return "/".join(parts[:3]) if len(parts) >= 3 else path

    def _match_zone(path: str) -> str:
        pfx = _depth1_prefix(path)
        for lc in layers_cfg:
            for p in lc.get("path_prefixes", []):
                if pfx == p or path.startswith(p + "/") or path == p:
                    return lc["id"]
        return "_other"

    children_by_path: dict[str, list[str]] = {}
    for n in shown:
        if n["depth"] > min_depth:
            parent_path = "/".join(n["path"].split("/")[:-1])
            if parent_path in node_by_path:
                children_by_path.setdefault(parent_path, []).append(n["path"])

    zone_to_tops: dict[str, list[str]] = {lc["id"]: [] for lc in layers_cfg}
    zone_to_tops["_other"] = []
    for n in shown:
        if n["depth"] == min_depth:
            zid = _match_zone(n["path"])
            zone_to_tops.setdefault(zid, []).append(n["path"])

    LEAF_W    = 160.0;  LEAF_H    = 38.0
    CHILD_GAP = 10.0;   NODE_PAD  = 14.0;  HEADER_H  = 26.0
    ZONE_GAP  = 28.0;   ZONE_PAD  = 18.0

    node_sizes: dict[str, tuple[float, float]] = {}

    def _compute_size(path: str) -> tuple[float, float]:
        if path in node_sizes:
            return node_sizes[path]
        kids = children_by_path.get(path, [])
        if not kids:
            node_sizes[path] = (LEAF_W, LEAF_H)
            return LEAF_W, LEAF_H
        child_sizes = [_compute_size(k) for k in kids]
        inner_w = max(w for w, h in child_sizes)
        inner_h = sum(h for w, h in child_sizes) + CHILD_GAP * (len(kids) - 1)
        w = inner_w + 2 * NODE_PAD
        h = HEADER_H + NODE_PAD + inner_h + NODE_PAD
        node_sizes[path] = (w, h)
        return w, h

    for path in node_by_path:
        _compute_size(path)

    def _zone_size(top_paths: list[str]) -> tuple[float, float]:
        if not top_paths:
            return (LEAF_W + 2 * ZONE_PAD, LEAF_H + 2 * ZONE_PAD + HEADER_H)
        sizes = [node_sizes[p] for p in top_paths]
        inner_w = max(w for w, h in sizes)
        inner_h = sum(h for w, h in sizes) + CHILD_GAP * (len(sizes) - 1)
        return (inner_w + 2 * ZONE_PAD, HEADER_H + ZONE_PAD + inner_h + ZONE_PAD)

    rf_nodes: list[dict] = []
    rf_edges: list[dict] = []

    active_zones = []
    for lc in layers_cfg:
        tops = zone_to_tops.get(lc["id"], [])
        if tops:
            active_zones.append((lc, tops))
    other_tops = zone_to_tops.get("_other", [])
    if other_tops:
        active_zones.append((
            {"id": "_other", "label": "Other", "color": "#F8FAFC", "stroke": "#94A3B8"},
            other_tops,
        ))

    def _place_subtree(path: str, rel_x: float, rel_y: float, parent_rf_id: str) -> None:
        n    = node_by_path[path]
        w, h = node_sizes[path]
        kids = children_by_path.get(path, [])
        provider = n.get("provider", "")
        pstyle   = prov_styles.get(provider, {})
        accent   = pstyle.get("color", _ARCH_PROVIDER_ACCENT.get(provider, "#64748B"))

        is_container = bool(kids)
        rf_node: dict = {
            "id":         path,
            "parentNode": parent_rf_id,
            "extent":     "parent",
            "position":   {"x": rel_x, "y": rel_y},
            "data":       {"label": n["name"], "provider": provider,
                           "path": path, "paths": [path]},
            "style": {"width": w, "height": h, "borderRadius": "6px"},
        }
        if is_container:
            rf_node["type"] = "group"
            rf_node["style"].update({
                "background": accent + "0D",
                "border":     f"1.5px solid {accent}88",
                "fontSize":   "11px", "fontWeight": "600", "color": accent,
            })
        else:
            rf_node["style"].update({
                "background": accent + "1A", "border": f"2px solid {accent}",
                "fontSize": "11px", "fontWeight": "500", "color": accent,
                "display": "flex", "alignItems": "center", "justifyContent": "center",
                "textAlign": "center", "padding": "4px 8px", "cursor": "pointer",
            })
        rf_nodes.append(rf_node)

        cy = HEADER_H + NODE_PAD
        for kid in kids:
            _, kh = node_sizes[kid]
            _place_subtree(kid, NODE_PAD, cy, path)
            cy += kh + CHILD_GAP

    zone_cursor = 0.0
    for lc, top_paths in active_zones:
        zid  = lc["id"]
        zw, zh = _zone_size(top_paths)
        zx = zone_cursor if direction == "LR" else 0.0
        zy = 0.0 if direction == "LR" else zone_cursor

        rf_nodes.append({
            "id": f"__zone__{zid}", "type": "group",
            "position": {"x": zx, "y": zy},
            "data": {"label": lc.get("label", zid)},
            "style": {
                "width": zw, "height": zh,
                "background": lc.get("color", "#F8FAFC"),
                "border": f"2px solid {lc.get('stroke', '#94A3B8')}",
                "borderRadius": "10px",
                "fontSize": "13px", "fontWeight": "700",
                "color": lc.get("stroke", "#334155"),
            },
        })

        cy = HEADER_H + ZONE_PAD
        for path in top_paths:
            _, ph = node_sizes[path]
            _place_subtree(path, ZONE_PAD, cy, f"__zone__{zid}")
            cy += ph + CHILD_GAP

        zone_cursor += (zw if direction == "LR" else zh) + ZONE_GAP

    if show_conns:
        leaf_paths = {n["path"] for n in shown if n["depth"] == max_depth}
        seen_edges: set[tuple[str, str]] = set()
        for src_path, targets in deps_cache.items():
            if src_path not in leaf_paths:
                continue
            for tgt_path in targets:
                if tgt_path not in leaf_paths or tgt_path == src_path:
                    continue
                key = (src_path, tgt_path)
                if key in seen_edges:
                    continue
                seen_edges.add(key)
                rf_edges.append({
                    "id": f"arch-dep-{src_path}--{tgt_path}",
                    "source": src_path, "target": tgt_path,
                    "type": "smoothstep",
                    "style": {"stroke": "#94A3B8", "strokeWidth": 1.5},
                    "markerEnd": {"type": "arrowclosed", "color": "#94A3B8"},
                })

    return {"nodes": rf_nodes, "edges": rf_edges}
```

#### C. Delete `_ARCH_DIAGRAM_CACHE` (lines 3995–3997)

Remove these three lines — the computed vars will call `_build_arch_diagram_elements` reactively:

```python
# DELETE:
_ARCH_DIAGRAM_CACHE: dict = _build_arch_diagram_elements(
    _ALL_NODES_CACHE, _DEPENDENCIES_CACHE, _ARCH_DIAGRAM_CONFIG
)
```

#### D. Rewrite `_generate_drawio_xml()` — complete rewrite using drawpyo (line 4004)

Replace with a drawpyo-based implementation that uses real cloud shape stencils.
The function uses the same sizing/positioning algorithm but creates drawpyo Objects.
Writes to a temp file and returns the XML string.

```python
def _generate_drawio_xml(
    nodes_cache: list[dict],
    deps_cache: dict[str, list[str]],
    config: dict,
) -> str:
    """Generate draw.io XML using drawpyo with cloud-specific shape stencils."""
    import tempfile, os
    import drawpyo

    direction   = config.get("direction", "LR")
    min_depth   = int(config.get("min_depth", 2))
    max_depth   = int(config.get("max_depth", 4))
    show_conns  = bool(config.get("show_connections", True))
    layers_cfg  = sorted(config.get("layers", []), key=lambda l: l.get("order", 99))
    prov_styles = config.get("provider_styles", {})

    if min_depth > max_depth:
        min_depth, max_depth = max_depth, min_depth

    shown = [n for n in nodes_cache if min_depth <= n["depth"] <= max_depth]
    node_by_path: dict[str, dict] = {n["path"]: n for n in shown}

    def _depth1_prefix(path: str) -> str:
        parts = path.split("/")
        return "/".join(parts[:3]) if len(parts) >= 3 else path

    def _match_zone(path: str) -> str:
        pfx = _depth1_prefix(path)
        for lc in layers_cfg:
            for p in lc.get("path_prefixes", []):
                if pfx == p or path.startswith(p + "/") or path == p:
                    return lc["id"]
        return "_other"

    children_by_path: dict[str, list[str]] = {}
    for n in shown:
        if n["depth"] > min_depth:
            parent_path = "/".join(n["path"].split("/")[:-1])
            if parent_path in node_by_path:
                children_by_path.setdefault(parent_path, []).append(n["path"])

    zone_to_tops: dict[str, list[str]] = {lc["id"]: [] for lc in layers_cfg}
    zone_to_tops["_other"] = []
    for n in shown:
        if n["depth"] == min_depth:
            zid = _match_zone(n["path"])
            zone_to_tops.setdefault(zid, []).append(n["path"])

    # Layout constants (match React Flow values so download mirrors browser)
    LEAF_W    = 160;  LEAF_H    = 38
    CHILD_GAP = 10;   NODE_PAD  = 14;  HEADER_H  = 26
    ZONE_GAP  = 28;   ZONE_PAD  = 18;  ICON_SIZE = 32

    node_sizes: dict[str, tuple[int, int]] = {}

    def _compute_size(path: str) -> tuple[int, int]:
        if path in node_sizes:
            return node_sizes[path]
        kids = children_by_path.get(path, [])
        if not kids:
            node_sizes[path] = (LEAF_W, LEAF_H)
            return LEAF_W, LEAF_H
        child_sizes = [_compute_size(k) for k in kids]
        inner_w = max(w for w, h in child_sizes)
        inner_h = sum(h for w, h in child_sizes) + CHILD_GAP * (len(kids) - 1)
        w = inner_w + 2 * NODE_PAD
        h = HEADER_H + NODE_PAD + inner_h + NODE_PAD
        node_sizes[path] = (w, h)
        return w, h

    for path in node_by_path:
        _compute_size(path)

    def _zone_size(top_paths: list[str]) -> tuple[int, int]:
        if not top_paths:
            return (LEAF_W + 2 * ZONE_PAD, LEAF_H + 2 * ZONE_PAD + HEADER_H)
        sizes = [node_sizes[p] for p in top_paths]
        inner_w = max(w for w, h in sizes)
        inner_h = sum(h for w, h in sizes) + CHILD_GAP * (len(sizes) - 1)
        return (inner_w + 2 * ZONE_PAD, HEADER_H + ZONE_PAD + inner_h + ZONE_PAD)

    # Build drawpyo diagram
    tmp = tempfile.mktemp(suffix=".drawio")
    try:
        dfile = drawpyo.File()
        dfile.file_path = os.path.dirname(tmp)
        dfile.file_name = os.path.basename(tmp)
        page  = drawpyo.Page(file=dfile)

        drawpyo_objs: dict[str, object] = {}  # path/zone-id → drawpyo Object

        active_zones = []
        for lc in layers_cfg:
            tops = zone_to_tops.get(lc["id"], [])
            if tops:
                active_zones.append((lc, tops))
        other_tops = zone_to_tops.get("_other", [])
        if other_tops:
            active_zones.append((
                {"id": "_other", "label": "Other", "color": "#F8FAFC", "stroke": "#94A3B8"},
                other_tops,
            ))

        zone_cursor = 0
        for lc, top_paths in active_zones:
            zid = lc["id"]
            zw, zh = _zone_size(top_paths)
            zx = zone_cursor if direction == "LR" else 0
            zy = 0 if direction == "LR" else zone_cursor

            fill   = lc.get("color",  "#F8FAFC").lstrip("#")
            stroke = lc.get("stroke", "#94A3B8").lstrip("#")
            zone_obj = drawpyo.diagram.Object(
                page=page,
                value=lc.get("label", zid),
                width=zw, height=zh,
                position=(zx, zy),
            )
            zone_obj.apply_style_string(
                f"swimlane;startSize={HEADER_H};fillColor=#{fill};"
                f"strokeColor=#{stroke};fontStyle=1;fontSize=13;rounded=1;arcSize=4;"
            )
            drawpyo_objs[f"__zone__{zid}"] = zone_obj

            def _place_drawpyo(path: str, rel_x: int, rel_y: int, parent_obj) -> None:
                n    = node_by_path[path]
                w, h = node_sizes[path]
                kids = children_by_path.get(path, [])
                provider = n.get("provider", "")
                pstyle   = prov_styles.get(provider, {})
                accent   = pstyle.get("color", _ARCH_PROVIDER_ACCENT.get(provider, "#64748B"))
                a_hex    = accent.lstrip("#")
                mss      = n.get("module_source_short", "")

                obj = drawpyo.diagram.Object(
                    page=page,
                    value=n["name"],
                    width=w, height=h,
                    parent=parent_obj,
                    position_rel_to_parent=(rel_x, rel_y),
                )
                if kids:
                    # Container node
                    obj.apply_style_string(
                        f"swimlane;startSize={HEADER_H};"
                        f"fillColor=#{a_hex}11;strokeColor=#{a_hex}88;"
                        f"fontStyle=1;fontSize=11;rounded=1;arcSize=4;"
                    )
                else:
                    # Leaf node with cloud icon shape
                    shape_frag = _drawio_shape(mss, provider, config)
                    obj.apply_style_string(
                        f"{shape_frag}fillColor=#{a_hex}1A;strokeColor=#{a_hex};"
                        f"fontColor=#{a_hex};fontSize=10;fontStyle=1;"
                        f"verticalLabelPosition=bottom;verticalAlign=top;"
                        f"align=center;rounded=1;arcSize=30;"
                    )
                drawpyo_objs[path] = obj

                cy = HEADER_H + NODE_PAD
                for kid in kids:
                    _, kh = node_sizes[kid]
                    _place_drawpyo(kid, NODE_PAD, cy, obj)
                    cy += kh + CHILD_GAP

            cy = HEADER_H + ZONE_PAD
            for path in top_paths:
                _, ph = node_sizes[path]
                _place_drawpyo(path, ZONE_PAD, cy, zone_obj)
                cy += ph + CHILD_GAP

            zone_cursor += (zw if direction == "LR" else zh) + ZONE_GAP

        # Dependency edges
        if show_conns:
            leaf_paths = {n["path"] for n in shown if n["depth"] == max_depth}
            seen_edges: set[tuple[str, str]] = set()
            for src_path, targets in deps_cache.items():
                if src_path not in leaf_paths or src_path not in drawpyo_objs:
                    continue
                for tgt_path in targets:
                    if (tgt_path not in leaf_paths or tgt_path == src_path
                            or tgt_path not in drawpyo_objs):
                        continue
                    key = (src_path, tgt_path)
                    if key in seen_edges:
                        continue
                    seen_edges.add(key)
                    edge = drawpyo.diagram.Edge(
                        page=page,
                        source=drawpyo_objs[src_path],
                        target=drawpyo_objs[tgt_path],
                    )
                    edge.apply_style_string(
                        "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;"
                        "jettySize=auto;exitX=0.5;exitY=1;entryX=0.5;entryY=0;"
                        "strokeColor=#94A3B8;strokeWidth=1.5;endArrow=block;endFill=0;"
                    )

        dfile.write()
        with open(tmp, "r", encoding="utf-8") as f:
            return f.read()
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass
```

#### E. Remove static `_ARCH_DIAGRAM_CACHE` (lines 3995–3997) — see step C above

#### F. Add export format registry + default export dir (after `_generate_drawio_xml`, ~line 4130)

`_ARCH_EXPORT_FORMATS` is the single place to register a format.
`_ARCH_GENERATORS` maps format id → generator function.
`_ARCH_EXPORT_DEFAULT_DIR` is the default server-side directory for saved files —
`de3-gui-pkg/_config/tmp/` (peer to `arch_diagram_config.yaml`, gitignored).
Adding a new format in future requires:
  1. Write `_generate_<format>(nodes_cache, deps_cache, config) -> str`
  2. Append one entry to each dict below — no other code changes.

```python
# ---------------------------------------------------------------------------
# Arch diagram export format registry
# ---------------------------------------------------------------------------

# Default server-side directory for saved export files.
# Path(__file__) is homelab_gui.py; four .parent calls reach de3-gui-pkg/.
_ARCH_CONFIG_DIR:       Path = Path(__file__).parent.parent.parent.parent / "_config"
_ARCH_EXPORT_DEFAULT_DIR: str = str(_ARCH_CONFIG_DIR / "tmp")

# Metadata for each export format. The toolbar builds its "Export" menu from this list.
# 'open_url_template' is optional; if present, an "Open in browser" link is also shown.
# Use {api_url} as the URL-encoded API endpoint placeholder.
_ARCH_EXPORT_FORMATS: list[dict] = [
    {
        "id":       "drawio",
        "label":    "draw.io / diagrams.net (.drawio)",
        "filename": "arch-diagram.drawio",
        "mime":     "application/xml",
        "open_url_template": "https://app.diagrams.net/?url={api_url}",
    },
    # Future formats — add entries here, implement generator below, add to _ARCH_GENERATORS.
    # {"id": "graphml", "label": "GraphML (.graphml)", "filename": "arch-diagram.graphml",
    #  "mime": "application/xml"},
    # {"id": "mermaid", "label": "Mermaid (.md)",      "filename": "arch-diagram.md",
    #  "mime": "text/plain"},
    # {"id": "dot",     "label": "Graphviz DOT (.dot)", "filename": "arch-diagram.dot",
    #  "mime": "text/plain"},
]

# Generator functions: format id → callable(nodes_cache, deps_cache, config) -> str
_ARCH_GENERATORS: dict[str, Any] = {
    "drawio": _generate_drawio_xml,
}
```

Also add `_config/tmp/` to `.gitignore` in the de3-gui-pkg root (or the repo root) so
exported diagram files are never accidentally committed.

#### G. Add AppState vars for arch diagram settings (after `viz_framework`, line 4312)

```python
# Arch diagram — live toolbar controls (seeded from arch_diagram_config.yaml)
arch_direction:        str  = _ARCH_DIAGRAM_CONFIG.get("direction", "LR")
arch_min_depth:        int  = int(_ARCH_DIAGRAM_CONFIG.get("min_depth", 2))
arch_max_depth:        int  = int(_ARCH_DIAGRAM_CONFIG.get("max_depth", 4))
arch_show_connections: bool = bool(_ARCH_DIAGRAM_CONFIG.get("show_connections", True))

# Export destination — server-side filesystem path; user can change via toolbar popup
arch_export_dir:    str = _ARCH_EXPORT_DEFAULT_DIR
arch_export_status: str = ""   # "Saved to …" | "Error: …" | "" (hidden)
```

#### H. Rewrite computed vars `arch_diagram_nodes` / `arch_diagram_edges` (lines 4787–4794)

Replace both with reactive versions plus helper and `arch_export_urls` (replaces the old
single `arch_drawio_export_url` var — now covers all registered formats automatically):

```python
def _arch_cfg(self) -> dict:
    return {
        **_ARCH_DIAGRAM_CONFIG,
        "direction":        self.arch_direction,
        "min_depth":        self.arch_min_depth,
        "max_depth":        self.arch_max_depth,
        "show_connections": self.arch_show_connections,
    }

@rx.var
def arch_diagram_nodes(self) -> list[dict]:
    return _build_arch_diagram_elements(
        _ALL_NODES_CACHE, _DEPENDENCIES_CACHE, self._arch_cfg()
    )["nodes"]

@rx.var
def arch_diagram_edges(self) -> list[dict]:
    return _build_arch_diagram_elements(
        _ALL_NODES_CACHE, _DEPENDENCIES_CACHE, self._arch_cfg()
    )["edges"]

@rx.var
def arch_export_urls(self) -> list[dict]:
    """One entry per registered export format.

    Each dict: {id, label, download_url, open_url}.
    open_url is "" when the format has no open_url_template.
    The toolbar iterates this list — no hardcoded format names in UI code.
    """
    import urllib.parse
    sc = "true" if self.arch_show_connections else "false"
    qs = (f"format={{fmt_id}}"
          f"&direction={self.arch_direction}"
          f"&min_depth={self.arch_min_depth}"
          f"&max_depth={self.arch_max_depth}"
          f"&show_connections={sc}")
    result = []
    for fmt in _ARCH_EXPORT_FORMATS:
        fid          = fmt["id"]
        download_url = f"/api/arch-diagram-export?" + qs.format(fmt_id=fid)
        open_url     = ""
        tmpl = fmt.get("open_url_template", "")
        if tmpl:
            full = "http://localhost:3000" + download_url
            open_url = tmpl.format(api_url=urllib.parse.quote(full, safe=""))
        result.append({
            "id":           fid,
            "label":        fmt["label"],
            "download_url": download_url,
            "open_url":     open_url,
        })
    return result
```

Also add a computed var for the compact directory label shown in the toolbar:

```python
@rx.var
def arch_export_dir_label(self) -> str:
    """Show last two path segments so the toolbar stays compact.

    e.g. '/long/path/de3-gui-pkg/_config/tmp' → '_config/tmp'
    """
    parts = Path(self.arch_export_dir).parts
    return str(Path(*parts[-2:])) if len(parts) >= 2 else self.arch_export_dir
```

Note: `_arch_cfg` is a plain method (not `@rx.var`); `_build_arch_diagram_elements` runs
twice per render (once for nodes, once for edges) — acceptable for a fast Python computation.

#### I. Add event handlers for arch diagram settings (after existing `set_depth_limit` handler)

```python
def set_arch_direction(self, val: str) -> None:
    if val in ("LR", "TB"):
        self.arch_direction = val

def set_arch_min_depth(self, val: list[int]) -> None:
    v = int(val[0]) if val else 1
    self.arch_min_depth = max(1, min(v, self.arch_max_depth))

def set_arch_max_depth(self, val: list[int]) -> None:
    v = int(val[0]) if val else 1
    self.arch_max_depth = max(self.arch_min_depth, min(v, 6))

def toggle_arch_connections(self) -> None:
    self.arch_show_connections = not self.arch_show_connections

def set_arch_export_dir(self, path: str) -> None:
    stripped = path.strip()
    if stripped:
        self.arch_export_dir = stripped
        self.arch_export_status = ""

def export_arch_diagram(self, fmt_id: str) -> None:
    """Save the current arch diagram to arch_export_dir on the server filesystem."""
    generator = _ARCH_GENERATORS.get(fmt_id)
    if not generator:
        self.arch_export_status = f"Error: unknown format '{fmt_id}'"
        return
    fmt_meta = next((f for f in _ARCH_EXPORT_FORMATS if f["id"] == fmt_id), {})
    try:
        cfg     = self._arch_cfg()
        content = generator(_ALL_NODES_CACHE, _DEPENDENCIES_CACHE, cfg)
        out_dir = Path(self.arch_export_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        filename = fmt_meta.get("filename", f"arch-diagram.{fmt_id}")
        out_path = out_dir / filename
        out_path.write_text(content, encoding="utf-8")
        self.arch_export_status = f"Saved → {out_path}"
    except Exception as exc:
        self.arch_export_status = f"Error: {exc}"
```

`set_arch_min_depth` / `set_arch_max_depth` take `list[int]` because Radix `rx.slider`
`on_change` fires with a list (same pattern as `set_depth_limit` at line ~14498).

`export_arch_diagram` runs entirely server-side — the file is written to the server filesystem.
The HTTP endpoint (`_api_arch_diagram_export`) remains available for the "open in browser"
diagrams.net feature, which needs a URL to fetch from.

#### J. Update `_ARCH_DIAGRAM_NODE_CLICK_JS` (line 12289)

Change `'__layer__'` → `'__zone__'`:

```python
_ARCH_DIAGRAM_NODE_CLICK_JS = r"""(event, node) => {
  if (!node.id || node.id.startsWith('__zone__')) return;
  window._rfSelectedPath = node.id;
  var trigger = document.getElementById('rf-node-trigger');
  if (trigger) trigger.click();
}"""
```

#### K. Rewrite `_arch_diagram_toolbar()` (line 12296)

The "File → Export" section iterates `AppState.arch_export_urls` via `rx.foreach` so the
menu grows automatically when new formats are added to `_ARCH_EXPORT_FORMATS`. Export items
are **Save buttons** (write to `arch_export_dir` on the server) rather than download links.
The "open in browser" link (diagrams.net) is still shown when the format supports it.
A folder picker popover lets the user change the destination directory. `arch_export_status`
is shown inline in the toolbar after a save attempt.

```python
def _arch_export_menu_item(fmt: dict) -> rx.Component:
    """One row in the Export section: Save button + optional Open-in-browser link."""
    return rx.vstack(
        rx.button(
            rx.text("Save  " + fmt["label"], font_size="12px",
                    color="var(--gui-text-primary)"),
            variant="ghost", size="1", color_scheme="gray",
            cursor="pointer", width="100%", text_align="left",
            padding="6px 12px",
            on_click=AppState.export_arch_diagram(fmt["id"]),
            _hover={"background": "var(--gray-3)"}, border_radius="4px",
        ),
        rx.cond(
            fmt["open_url"] != "",
            rx.link(
                rx.hstack(
                    rx.text(fmt["label"] + "  ↗ open in browser",
                            font_size="11px", color="var(--gui-text-dim)"),
                    padding="4px 12px", width="100%",
                    _hover={"background": "var(--gray-3)"}, border_radius="4px",
                ),
                href=fmt["open_url"],
                is_external=True, text_decoration="none",
            ),
            rx.box(),
        ),
        spacing="0", width="100%",
    )


def _arch_diagram_toolbar() -> rx.Component:
    def _depth_popover(label: str, value_var, on_change, min_v: int, max_v: int):
        return rx.popover.root(
            rx.popover.trigger(
                rx.button(
                    label, value_var,
                    variant="outline", size="1", color_scheme="gray",
                    cursor="pointer", padding="2px 8px", font_size="11px",
                ),
            ),
            rx.popover.content(
                rx.vstack(
                    rx.hstack(
                        rx.text(label, font_size="12px", font_weight="600"),
                        rx.spacer(),
                        rx.text(value_var, font_size="12px", color="#3b82f6",
                                font_weight="600", min_width="20px", text_align="right"),
                        width="160px", align="center",
                    ),
                    rx.slider(
                        min=min_v, max=max_v, step=1,
                        value=[value_var],
                        on_change=on_change,
                        width="160px",
                    ),
                    rx.hstack(
                        rx.text(str(min_v), font_size="10px", color="var(--gui-text-dim)"),
                        rx.spacer(),
                        rx.text(str(max_v), font_size="10px", color="var(--gui-text-dim)"),
                        width="160px",
                    ),
                    spacing="2", padding="10px", width="180px",
                ),
                side="bottom", align="start",
            ),
        )

    # Folder picker popover — lets the user change where exported files are saved.
    # Uses on_blur so typing doesn't fire events on every keystroke.
    dir_picker = rx.popover.root(
        rx.popover.trigger(
            rx.button(
                rx.hstack(
                    rx.text("📁", font_size="10px"),
                    rx.text(AppState.arch_export_dir_label, font_size="10px",
                            max_width="100px", overflow="hidden",
                            text_overflow="ellipsis", white_space="nowrap"),
                    spacing="1",
                ),
                variant="outline", size="1", color_scheme="gray",
                cursor="pointer", padding="2px 6px",
                title=AppState.arch_export_dir,
            ),
        ),
        rx.popover.content(
            rx.vstack(
                rx.text("Export Directory", font_size="12px", font_weight="600"),
                rx.input(
                    default_value=AppState.arch_export_dir,
                    on_blur=AppState.set_arch_export_dir,
                    placeholder="/path/to/save",
                    font_size="11px", width="320px",
                ),
                rx.text("Files are written to this path on the server.",
                        font_size="10px", color="var(--gui-text-dim)"),
                spacing="2", padding="10px",
            ),
            side="bottom", align="start",
        ),
    )

    return rx.hstack(
        # File menu — export section built from _ARCH_EXPORT_FORMATS registry
        rx.popover.root(
            rx.popover.trigger(
                rx.button(
                    rx.hstack(rx.text("File", font_size="12px"),
                              rx.text("▾", font_size="10px"), spacing="1"),
                    variant="ghost", size="1", color_scheme="gray",
                    cursor="pointer", padding="4px 8px",
                ),
            ),
            rx.popover.content(
                rx.vstack(
                    rx.text("Export", font_size="10px", font_weight="700",
                            color="var(--gui-text-dim)", text_transform="uppercase",
                            letter_spacing="0.07em", padding="4px 8px 2px"),
                    rx.foreach(AppState.arch_export_urls, _arch_export_menu_item),
                    spacing="0", padding="4px", min_width="280px",
                ),
                padding="4px",
            ),
        ),

        dir_picker,

        rx.divider(orientation="vertical", height="16px", color="var(--gray-5)"),

        # Direction toggle
        rx.hstack(
            rx.text("Dir:", font_size="11px", color="var(--gui-text-dim)"),
            rx.button("→ LR", size="1",
                      variant=rx.cond(AppState.arch_direction == "LR", "solid", "outline"),
                      color_scheme="blue", cursor="pointer",
                      on_click=AppState.set_arch_direction("LR"),
                      padding="2px 6px", font_size="11px"),
            rx.button("↓ TB", size="1",
                      variant=rx.cond(AppState.arch_direction == "TB", "solid", "outline"),
                      color_scheme="blue", cursor="pointer",
                      on_click=AppState.set_arch_direction("TB"),
                      padding="2px 6px", font_size="11px"),
            spacing="1", align="center",
        ),

        rx.divider(orientation="vertical", height="16px", color="var(--gray-5)"),

        _depth_popover("Min:", AppState.arch_min_depth, AppState.set_arch_min_depth, 1, 5),
        _depth_popover("Max:", AppState.arch_max_depth, AppState.set_arch_max_depth, 1, 6),

        rx.divider(orientation="vertical", height="16px", color="var(--gray-5)"),

        rx.button(
            rx.cond(AppState.arch_show_connections,
                    rx.text("⊶ Conn", font_size="11px"),
                    rx.text("⊶ Conn", font_size="11px", opacity="0.4")),
            size="1",
            variant=rx.cond(AppState.arch_show_connections, "soft", "outline"),
            color_scheme="gray", cursor="pointer",
            on_click=AppState.toggle_arch_connections,
            padding="2px 8px",
            title="Toggle dependency connection edges",
        ),

        rx.spacer(),

        # Save status — shown in muted green (success) or red (error); hidden when empty
        rx.cond(
            AppState.arch_export_status != "",
            rx.text(
                AppState.arch_export_status,
                font_size="10px",
                color=rx.cond(
                    AppState.arch_export_status.contains("Error"),
                    "var(--red-9)", "var(--green-9)",
                ),
                max_width="220px", overflow="hidden",
                text_overflow="ellipsis", white_space="nowrap",
                padding_right="6px",
            ),
            rx.box(),
        ),

        rx.text("Arch Diagram", font_size="10px",
                color="var(--gui-text-dim)", padding_right="8px"),

        width="100%", height="36px", align="center", spacing="2",
        padding="0 8px",
        background="var(--gray-2)",
        border_bottom="1px solid var(--gray-5)",
        flex_shrink="0",
    )
```

#### L. Replace `_api_arch_diagram_drawio` with `_api_arch_diagram_export` (line 18344)

Remove the old single-format endpoint and register a new one that dispatches via
`_ARCH_GENERATORS`. The route changes from `/api/arch-diagram-drawio` to
`/api/arch-diagram-export`. The old route can be kept as a redirect for compatibility
(add `format=drawio` and redirect), or simply removed since no external code depends on it.

```python
async def _api_arch_diagram_export(request: Request):
    """Serve an arch diagram export in the requested format.

    Query params:
      format          — required; must be a key in _ARCH_GENERATORS
      direction       — LR | TB  (default from config)
      min_depth       — int
      max_depth       — int
      show_connections — true | false
    """
    params    = dict(request.query_params)
    fmt_id    = params.get("format", "drawio")
    generator = _ARCH_GENERATORS.get(fmt_id)
    if generator is None:
        return _PlainTextResponse(
            f"Unknown format '{fmt_id}'. Available: {list(_ARCH_GENERATORS)}",
            status_code=400, media_type="text/plain",
        )

    # Find format metadata for filename + mime type
    fmt_meta = next((f for f in _ARCH_EXPORT_FORMATS if f["id"] == fmt_id), {})

    cfg = {**_ARCH_DIAGRAM_CONFIG}
    if "direction" in params and params["direction"] in ("LR", "TB"):
        cfg["direction"] = params["direction"]
    if "min_depth" in params:
        try: cfg["min_depth"] = int(params["min_depth"])
        except ValueError: pass
    if "max_depth" in params:
        try: cfg["max_depth"] = int(params["max_depth"])
        except ValueError: pass
    if "show_connections" in params:
        cfg["show_connections"] = params["show_connections"].lower() == "true"

    content  = generator(_ALL_NODES_CACHE, _DEPENDENCIES_CACHE, cfg)
    filename = fmt_meta.get("filename", f"arch-diagram.{fmt_id}")
    mime     = fmt_meta.get("mime", "text/plain")
    return _PlainTextResponse(
        content, media_type=mime,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


app._api.add_route("/api/arch-diagram-export", _api_arch_diagram_export, methods=["GET"])
```

Also **remove** the old `app._api.add_route("/api/arch-diagram-drawio", ...)` line.

Check the response class name (`_PlainTextResponse` or equivalent) against the existing
endpoint and match it.

## Execution Order

1. **`requirements.txt`** — add `drawpyo>=0.2.5`. Run `pip install drawpyo` in the venv.

2. **`arch_diagram_config.yaml`** — replace `component_depth: 1` with `min_depth: 2` /
   `max_depth: 4`; add `icon_map` and `provider_icon_fallbacks` sections.

3. **`homelab_gui.py` — `_drawio_shape()` helper** — add config-driven helper after
   `_ARCH_PROVIDER_ACCENT` (~line 3829). No hardcoded dict.

4. **`homelab_gui.py` — `_build_arch_diagram_elements()`** — complete rewrite (nested React
   Flow layout). Steps 3 and 4 are independent; do them in either order.

5. **`homelab_gui.py` — delete `_ARCH_DIAGRAM_CACHE`** (lines 3995–3997).

6. **`homelab_gui.py` — `_generate_drawio_xml()`** — complete rewrite using drawpyo.

7. **`homelab_gui.py` — format registry + default export dir** — add `_ARCH_CONFIG_DIR`,
   `_ARCH_EXPORT_DEFAULT_DIR`, `_ARCH_EXPORT_FORMATS` list, and `_ARCH_GENERATORS` dict
   immediately after `_generate_drawio_xml()`.

8. **`homelab_gui.py` — AppState vars** — add six `arch_*` vars after `viz_framework`:
   `arch_direction`, `arch_min_depth`, `arch_max_depth`, `arch_show_connections`,
   `arch_export_dir` (seeded from `_ARCH_EXPORT_DEFAULT_DIR`), `arch_export_status`.

9. **`homelab_gui.py` — computed vars** — replace `arch_diagram_nodes` / `arch_diagram_edges`
   bodies; add `_arch_cfg()`, `arch_export_urls`, and `arch_export_dir_label`.

10. **`homelab_gui.py` — event handlers** — add `set_arch_direction`, `set_arch_min_depth`,
    `set_arch_max_depth`, `toggle_arch_connections`, `set_arch_export_dir`,
    `export_arch_diagram` after `set_depth_limit`.

11. **`homelab_gui.py` — `_ARCH_DIAGRAM_NODE_CLICK_JS`** — change `__layer__` → `__zone__`.

12. **`homelab_gui.py` — toolbar** — add `_arch_export_menu_item()` helper (Save buttons +
    open-in-browser links), rewrite `_arch_diagram_toolbar()` with folder picker popover,
    `rx.foreach` export menu, and `arch_export_status` display.

13. **`homelab_gui.py` — API endpoint** — replace `_api_arch_diagram_drawio` with
    `_api_arch_diagram_export`; update `app._api.add_route` call.

14. **`.gitignore`** — add `infra/de3-gui-pkg/_config/tmp/` (or `_config/tmp/`) so exported
    diagram files are never accidentally committed.

15. **Restart app** and verify.

## Verification

```bash
# 1. Verify drawpyo installed
python3 -c "import drawpyo; print(drawpyo.__version__)"

# 2. Restart app and open Arch Diagram view.
#    Expected: nested box layout, toolbar shows:
#      File ▾  📁 _config/tmp  |  Dir: → LR  ↓ TB  |  Min: 2  Max: 4  |  ⊶ Conn

# 3. Test save button — click File ▾ → "Save draw.io / diagrams.net (.drawio)".
#    Expected: toolbar shows "Saved → <path>/arch-diagram.drawio" in green.
#    Verify the file exists:
ls -lh "$(find . -path '*/de3-gui-pkg/_config/tmp/arch-diagram.drawio' 2>/dev/null | head -1)"
#    Open the saved file in draw.io desktop or upload to diagrams.net.
#    Expected: nested swimlane containers with cloud-specific icons (server shapes,
#    K8s icons, storage icons) at leaf nodes.

# 4. Test folder picker — click the 📁 button, change path to /tmp/arch-export-test,
#    click Save again. Expected: file written to /tmp/arch-export-test/arch-diagram.drawio.
ls /tmp/arch-export-test/arch-diagram.drawio

# 5. Test draw.io export via HTTP endpoint (used by "open in browser" link):
curl "http://localhost:3000/api/arch-diagram-export?format=drawio&direction=LR&min_depth=2&max_depth=4&show_connections=true" \
  -o /tmp/arch.drawio
# Expected: valid XML file beginning with <?xml or <mxGraphModel>.

# 6. Test unknown format returns 400:
curl -s "http://localhost:3000/api/arch-diagram-export?format=bogus" | grep "Unknown format"

# 7. Test "open in browser" link — clicking it in the toolbar should open
#    app.diagrams.net with the diagram loaded (icons visible).

# 8. Test error display — set export dir to a read-only path (e.g. /root/noperm),
#    click Save. Expected: toolbar shows red "Error: ..." message.

# 9. If drawpyo object placement is incorrect (nodes outside containers):
#    Check that position_rel_to_parent is supported in the installed version.
#    Fallback: use absolute position=(zx+rel_x, zy+rel_y) with parent=None.

# 10. If cloud icon shapes don't render in draw.io:
#    In draw.io desktop: right-click shape → Edit Style → paste the shape string → OK.
```
