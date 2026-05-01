# Replace fw-repos Cytoscape View with Mermaid Class Diagram

## Summary

Replaced the Framework Repos Cytoscape compound-node graph (broken and illegible — no
visible text) with a Mermaid `classDiagram` rendered in an iframe asset. Repos appear
as UML classes, embedded packages as `+ name: version` public members, external packages
as `- name: version` private members, and `created_by` lineage as inheritance arrows
(`Parent <|-- Child : creates`). The implementation follows the existing iframe-asset
pattern used for `cytoscape_viewer.html` and `mxgraph_viewer.html`.

## Changes

- **`infra/de3-gui-pkg/_application/de3-gui/assets/fw_repos_mermaid_viewer.html`** — created; full-page HTML that fetches `/api/fw-repos-graph`, builds Mermaid classDiagram syntax, and renders via Mermaid.js from CDN. Has a Refresh button.
- **`infra/de3-gui-pkg/_application/de3-gui/homelab_gui/homelab_gui.py`** — removed ~370 lines of Cytoscape-specific fw_repos code (state fields, computed vars, event handlers, constants, menu functions, `_save_current_config` keys, `_load_state` restore lines, `on_load` layout restore); added `/api/fw-repos-graph` endpoint; added `fw_repos_mermaid_view()` component function using `rx.el.iframe`; updated `refresh_fw_repos_data` to trigger iframe reload via `rx.call_script`.
- **`infra/de3-gui-pkg/_application/de3-gui/state/fw-repos-layout.yaml`** — deleted (no longer needed).
- **`infra/de3-gui-pkg/_config/de3-gui-pkg.yaml`** — bumped version 0.4.0 → 0.5.0.
- **`infra/de3-gui-pkg/_config/version_history.md`** — added 0.5.0 entry.

## Root Cause

The Cytoscape view was implemented in a previous session but produced a diagram with no
visible text — compound nodes rendered without labels in the React-Cytoscapejs integration.
The dagre layout plugin also failed to load due to an async import race with
`componentDidMount`. Rather than debug further, the user requested switching to Mermaid
which maps cleanly to the repo/package data model.

## Notes

- The `<current-repo>` entry in `known-fw-repos.yaml` (angle brackets in name) is
  sanitized in the HTML by stripping `<` / `>` before building Mermaid class names.
- Mermaid requires backtick-quoting for class names with hyphens: `` `my-repo` ``.
- The API endpoint reads directly from `_FW_REPOS_YAML` (no state field needed — the
  iframe fetches on its own load cycle).
