# Plan: Add de3-pwy-home-lab-pkg-repo and de3-central-index-repo

## Objective

Add two new entries to `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`:

1. **`de3-pwy-home-lab-pkg-repo`** — a properly named (de3-prefix, -repo suffix) entry for the
   current deployment repo (`pwy-home-lab-pkg` / `philwyoungatinsight/pwy-home-lab-pkg`).
   Gives the home-lab deployment repo a canonical name in the fw-repos ecosystem.

2. **`de3-central-index-repo`** — a new discovery/index repo that declares every known package
   as an external dependency, making it the single starting point for finding any repo or package
   in the de3 ecosystem. Comments explain the sub-index pattern (e.g. by team/project), with the
   rule that all sub-indexes should ultimately link back to this one.

Both entries must be **commented out** per the CLAUDE.md rule ("Before adding a new entry, create
the actual repo first. Keep example/template entries commented out until they are ready to use.")
The plan includes the note to uncomment once the GitHub repos are created.

## Context

### Current state

- Deployment file: `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`
  (346 lines, 11 real repos listed, all following `de3-*-repo` naming convention)
- This repo's two remotes:
  - `origin` → `git@gitlab.com:pwyoung/pwy-home-pkg.git`
  - `philwyoungatinsight` → `https://github.com/philwyoungatinsight/pwy-home-lab-pkg.git`
- All existing `framework_repos` entries follow the schema:
  ```yaml
  - name: de3-<pkg>-repo
    source_repo:
      name: de3-runner          # resolved from source_repo_defaults
    new_repo_config:
      git-remotes:
        - name: origin
          git-source: https://github.com/philwyoungatinsight/de3-<pkg>-repo.git
          git-ref: main
    labels:
      - name: _purpose
        value: "..."
      - name: _docs
        value: "https://github.com/philwyoungatinsight/de3-<pkg>-repo"
    framework_packages:
      - name: <pkg>
        package_type: embedded
        exportable: true
        is_config_package: true
  ```
- External packages currently all reference `de3-runner` as their `repo:` value (since all
  packages live in the monorepo today). For the central index we reference the individual
  package repos instead (see Open Questions #2).
- `package_names_must_be_valid_identifiers: true` enforces a `-pkg` suffix on package names.
  `central-index-pkg` satisfies this.
- There is an unstaged diff removing `de3-demo-buckets-example-pkg-repo` from the file.
  This plan does not touch that diff — it only appends new commented-out entries.

### Existing packages to reference in the central index

From the 11 current repos, the exportable embedded packages are:
- `_framework-pkg` (de3-_framework-pkg-repo)
- `aws-pkg` (de3-aws-pkg-repo)
- `azure-pkg` (de3-azure-pkg-repo)
- `de3-gui-pkg` (de3-gui-pkg-repo)
- `gcp-pkg` (de3-gcp-pkg-repo)
- `image-maker-pkg` (de3-image-maker-pkg-repo)
- `maas-pkg` (de3-maas-pkg-repo)
- `mesh-central-pkg` (de3-mesh-central-pkg-repo)
- `mikrotik-pkg` (de3-mikrotik-pkg-repo)
- `proxmox-pkg` (de3-proxmox-pkg-repo)
- `unifi-pkg` (de3-unifi-pkg-repo)
- `pwy-home-lab-pkg` (de3-pwy-home-lab-pkg-repo — the new entry from this plan)

`_framework-pkg` is auto-injected by `framework_package_template`, so it does NOT need to be
listed again as an explicit external package in the central index.

## Open Questions

1. **Who creates the GitHub repos?** Per CLAUDE.md, both repos must be created on GitHub before
   their entries are uncommented. Should this plan include a step to create them (e.g. via `gh
   repo create`), or will you create them manually and then uncomment the entries?
   **Proposal**: add both entries as commented-out stubs now; create the repos and uncomment in a
   follow-up commit.

2. **External package sources in the central index**: current external packages all use
   `repo: de3-runner` / `source: https://github.com/philwyoungatinsight/de3-runner.git` because
   all packages still live in the monorepo. For the central index the intent is to reference the
   *individual* package repos (e.g. `de3-proxmox-pkg-repo`). Is it correct to start using the
   individual repo URLs now, even though the packages may not have been migrated to those repos
   yet? **Proposal**: yes — use the individual repo URLs. The central index is aspirational; the
   URLs are correct targets even if not yet fully populated. Mark each with a comment noting the
   migration status.

3. **Include `pwy-home-lab-pkg` in the central index?** The home-lab deployment repo is
   deployment-specific, not a reusable framework package. Should it appear in the central index,
   or is the index only for portable/exportable packages?
   **Proposal**: include it — the index should be a complete picture of the ecosystem. Mark it
   clearly as a deployment repo (not a portable package) via its `_purpose` label.

## Files to Create / Modify

### `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml` — modify

Append two new entries at the **end** of the `framework_repos:` list (after the existing
`de3-unifi-pkg-repo` entry). Both are commented out. Include a section header comment before each.

#### Entry 1 — `de3-pwy-home-lab-pkg-repo`

```yaml
    # ── Deployment repo ────────────────────────────────────────────────────────────────
    # de3-pwy-home-lab-pkg-repo is the properly named canonical reference for this repo.
    # It is a deployment repo — not a portable package — so it is not exportable.
    # The GitHub repo must be created before uncommenting this entry.
    #- name: de3-pwy-home-lab-pkg-repo
    #  source_repo:
    #    name: de3-runner
    #  new_repo_config:
    #    git-remotes:
    #      - name: origin
    #        git-source: https://github.com/philwyoungatinsight/de3-pwy-home-lab-pkg-repo.git
    #        git-ref: main
    #  labels:
    #    - name: _purpose
    #      value: "pwy home-lab deployment repo — assembles all de3 framework packages into a
    #        single deployable environment. This is the top-level repo for the pwy home lab;
    #        it is not a reusable framework package."
    #    - name: _docs
    #      value: "https://github.com/philwyoungatinsight/de3-pwy-home-lab-pkg-repo"
    #  framework_packages:
    #    - name: pwy-home-lab-pkg
    #      package_type: embedded
    #      exportable: false
    #      is_config_package: true
```

#### Entry 2 — `de3-central-index-repo`

```yaml
    # ── Central index ──────────────────────────────────────────────────────────────────
    # de3-central-index-repo is the canonical discovery point for the entire de3 ecosystem.
    # It lists every known package repo as an external dependency so that the fw-repos
    # visualiser can draw the full package graph from a single entry point.
    #
    # Sub-indexes are encouraged: create domain-specific index repos (e.g. de3-cloud-index-repo,
    # de3-network-index-repo) to group packages by purpose, team, or project. Sub-indexes
    # should always link back to (or be registered in) this central index so the full graph
    # remains discoverable from one place.
    #
    # The GitHub repo must be created before uncommenting this entry.
    #- name: de3-central-index-repo
    #  source_repo:
    #    name: de3-runner
    #  new_repo_config:
    #    git-remotes:
    #      - name: origin
    #        git-source: https://github.com/philwyoungatinsight/de3-central-index-repo.git
    #        git-ref: main
    #  labels:
    #    - name: _purpose
    #      value: "Central discovery index for the de3 framework ecosystem. Declares every known
    #        package repo as an external dependency so that all repos and packages are reachable
    #        from a single entry point. To find any package in the ecosystem, start here.
    #        Domain-specific sub-indexes (e.g. grouped by cloud provider, team, or project) are
    #        encouraged — but every sub-index should ultimately link back to or be registered in
    #        this central index to keep the full package graph discoverable."
    #    - name: _docs
    #      value: "https://github.com/philwyoungatinsight/de3-central-index-repo"
    #  framework_packages:
    #    # central-index-pkg is a minimal embedded package that acts as the config anchor.
    #    # All content of interest is in the external packages below.
    #    - name: central-index-pkg
    #      package_type: embedded
    #      exportable: false
    #      is_config_package: true
    #    # ── External packages — one per framework repo ──────────────────────────────
    #    # _framework-pkg is omitted here: it is auto-injected by framework_package_template.
    #    - name: aws-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-aws-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-aws-pkg-repo.git
    #      git_ref: main
    #    - name: azure-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-azure-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-azure-pkg-repo.git
    #      git_ref: main
    #    - name: de3-gui-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-gui-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-gui-pkg-repo.git
    #      git_ref: main
    #    - name: gcp-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-gcp-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-gcp-pkg-repo.git
    #      git_ref: main
    #    - name: image-maker-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-image-maker-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-image-maker-pkg-repo.git
    #      git_ref: main
    #    - name: maas-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-maas-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-maas-pkg-repo.git
    #      git_ref: main
    #    - name: mesh-central-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-mesh-central-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-mesh-central-pkg-repo.git
    #      git_ref: main
    #    - name: mikrotik-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-mikrotik-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-mikrotik-pkg-repo.git
    #      git_ref: main
    #    - name: proxmox-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-proxmox-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-proxmox-pkg-repo.git
    #      git_ref: main
    #    - name: unifi-pkg
    #      package_type: external
    #      exportable: true
    #      repo: de3-unifi-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-unifi-pkg-repo.git
    #      git_ref: main
    #    # pwy-home-lab-pkg: deployment repo, not a portable package — included for
    #    # completeness so the full ecosystem graph is visible from this index.
    #    - name: pwy-home-lab-pkg
    #      package_type: external
    #      exportable: false
    #      repo: de3-pwy-home-lab-pkg-repo
    #      source: https://github.com/philwyoungatinsight/de3-pwy-home-lab-pkg-repo.git
    #      git_ref: main
```

## Execution Order

1. Append the two commented-out entries (with their section header comments) to the end of
   `framework_repos:` in
   `infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`.
2. Write the ai-log entry.
3. Commit:
   ```
   feat(fw-repos): add de3-pwy-home-lab-pkg-repo and de3-central-index-repo (commented out)
   ```

There are no code changes beyond this one YAML file. No Terraform, Ansible, or scripts are
affected by YAML comments.

## Verification

After committing:
- `grep -n 'de3-pwy-home-lab-pkg-repo\|de3-central-index-repo' infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml`
  should return the new lines.
- Confirm all new lines begin with `#` (commented out).
- Confirm the file still parses as valid YAML: `python3 -c "import yaml, sys; yaml.safe_load(open('infra/pwy-home-lab-pkg/_config/_framework_settings/framework_repo_manager.yaml'))"`.
- When the GitHub repos are created, remove the `#` prefixes and re-run validation.
