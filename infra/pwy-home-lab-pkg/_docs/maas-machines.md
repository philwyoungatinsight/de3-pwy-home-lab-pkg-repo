# MaaS-Managed Machines

Physical and virtual machines deployed through the MaaS lifecycle pipeline
(`pwy-home-lab-pkg/_stack/maas/pwy-homelab/machines/`).

---

## Machine Summary

| Machine | Hardware | OS | Version | Network Stack | cloud_public IP | cloud_public NIC | cloud_public Connection | Switch | Switch Port | Provisioning NIC | Power | Role |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ms01-01 | MinisForum MS-01 | Debian → Proxmox VE | Trixie (13) → PVE 9.x | systemd-networkd → pvesh bridges | 10.0.10.116 | 1G RJ45 | `vmbr0` Linux bridge, VLAN 10 subif | UniFi | — | same 1G RJ45 (VLAN 12 tag) | AMT 10.0.11.10 + Tapo plug | Hypervisor node |
| ms01-02 | MinisForum MS-01 | Rocky Linux 9 | 9 (GenericCloud) | NetworkManager + OVS (ovs0) | 10.0.10.117 | 10G SFP+ | `ovs0` OVS bridge, untagged access | CRS317 | sfpplus3 | 1G RJ45 (VLAN 12 tag, UniFi) | AMT 10.0.11.11 | Plain managed host |
| ms01-03 | MinisForum MS-01 | Ubuntu 24.04 LTS | Noble | netplan + OVS (ovs0) | 10.0.10.118 | 10G SFP+ | `ovs0` OVS bridge, untagged access | CRS317 | sfpplus4 | 1G RJ45 (VLAN 12 tag, UniFi) | AMT 10.0.11.12 | Plain managed host |
| nuc-1 | Intel NUC | Ubuntu 24.04 LTS | Noble | systemd-networkd (VLAN 10 subif) | 10.0.10.119 | 1G RJ45 | VLAN 10 subinterface (no bridge) | UniFi | — | same 1G RJ45 (VLAN 12 tag) | Kasa smart plug | Plain managed host |
| pxe-test-vm-1 | Proxmox VM (pve-1) | Ubuntu 24.04 LTS | Noble | cloud-init default | DHCP / cloud_public | virtio (vmbr0) | Proxmox bridge, cloud-init | UniFi (via pve-1) | — | same virtio NIC | Proxmox API | PXE pipeline test |

---

## How Machines Are Built

All physical machines go through the same MaaS lifecycle, implemented as a chain
of Terraform units. Each stage is a separate unit that depends on the previous one.

```
maas.lifecycle.new          machines/<name>                 — machine record + power config
maas.lifecycle.commissioning  machines/<name>/commission      — PXE boot, hardware discovery
maas.lifecycle.ready          machines/<name>/commission/ready — wait for Ready state
maas.lifecycle.allocated      .../ready/allocated             — reserve for this deployment
maas.lifecycle.deploying      .../allocated/deploying         — trigger OS install
maas.lifecycle.deployed       .../deploying/deployed          — wait for Deployed, verify SSH
```

Power-off → PXE boot → ephemeral env → hardware inventory → OS image DD to disk → reboot.

---

## Machine Details

### ms01-01 — Hypervisor (Proxmox VE)

| Field | Value |
|---|---|
| Hardware | MinisForum MS-01 |
| MaaS deploy | Debian 13 (Trixie) — `deploy_osystem: custom`, `deploy_distro: trixie` |
| Final OS | Proxmox VE 9.x (installed post-deploy by `install-proxmox` wave) |
| Network stack | systemd-networkd during Debian phase; pvesh-managed bridges after Proxmox |
| Bridge | `vmbr0` — VLAN-aware, host IP `10.0.10.116/24` on VLAN 10 subinterface |
| IP | 10.0.10.116 (cloud_public VLAN 10) |
| Power | AMT at `10.0.11.10` — requires Tapo P125 smart plug (192.168.1.231) to bounce AC power before AMT wsman commands (AMT firmware crashes after a few minutes idle) |
| PXE MAC | `38:05:25:31:2f:a2` |
| Provisioning IP | 10.0.12.237 (DHCP on VLAN 12) |
| 10G switch port | CRS317 `sfpplus1` |

**Build notes:**
- MaaS deploys Debian Trixie (a custom boot resource imported via `import-debian-image.yaml`). Debian is required as the base OS because the Proxmox VE installer bootstraps from a Debian live environment.
- The `install-proxmox` wave runs Ansible post-deploy to install Proxmox VE, reconfigure networking, and register the node.
- The `mgmt_wake_via_plug: true` flag tells the power module to power-cycle via the Tapo plug before issuing AMT wake commands.

---

### ms01-02 — Rocky Linux 9 + OVS

| Field | Value |
|---|---|
| Hardware | MinisForum MS-01 |
| OS | Rocky Linux 9 (GenericCloud qcow2) |
| MaaS deploy | `deploy_osystem: custom`, `deploy_distro: rocky-9` |
| Network stack | NetworkManager + OVS (`ovs0` bridge) |
| Bridge | `ovs0` — OVS bridge on 10G NIC; host IP `10.0.10.117/24`, gateway `10.0.10.1` |
| IP | 10.0.10.117 (cloud_public VLAN 10 via OVS) |
| Provisioning IP | 10.0.12.239 (DHCP on VLAN 12) |
| Power | AMT at `10.0.11.11` port 16993 |
| PXE MAC | `38:05:25:31:81:10` |
| 10G switch port | CRS317 `sfpplus3` (access mode, pvid=10, frames arrive untagged) |
| Default user | `rocky` |

**Build notes:**
- The Rocky 9 MaaS boot resource is built from the [Rocky Linux 9 GenericCloud qcow2](https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2) via `import-rocky-image.yaml`. The pipeline: downloads qcow2 → mounts via qemu-nbd → chroot to install `grub2-efi-x64`, `efibootmgr`, `netplan` (from EPEL 9), `openssh-server` → installs GRUB2 EFI → creates `/curtin` marker → converts to ddgz → imports into MaaS.
- Deployed as `custom/rocky-9` (same mechanism as `custom/trixie` for Debian).
- **OVS is configured automatically** by the `maas.machine.config.networking` wave, which runs immediately after `maas.lifecycle.deployed`. The `bridges:` list in `pwy-home-lab-pkg.yaml` declares the intent; the wave reads it and configures OVS + NetworkManager nmcli connections.
- **After first deploy**: if `bridges[0].nic` is empty, run `scripts/ai-only-scripts/discover-10g-nics` to find the 10G NIC name (the sfpplus3 port on the CRS317), fill in `bridges[0].nic`, then re-run the `maas.machine.config.networking` unit.

---

### ms01-03 — Ubuntu 24.04 + OVS

| Field | Value |
|---|---|
| Hardware | MinisForum MS-01 |
| OS | Ubuntu 24.04 LTS (Noble) |
| MaaS deploy | `deploy_distro: noble` (standard Ubuntu boot resource, auto-synced) |
| Network stack | netplan + OVS (`ovs0` bridge) |
| Bridge | `ovs0` — OVS bridge on 10G NIC; host IP `10.0.10.118/24`, gateway `10.0.10.1` |
| IP | 10.0.10.118 (cloud_public VLAN 10 via OVS) |
| Power | AMT at `10.0.11.12` port 16993 |
| PXE MAC | `38:05:25:31:7f:14` |
| Provisioning IP | 10.0.12.238 (DHCP on VLAN 12) |
| 10G switch port | CRS317 `sfpplus4` (access mode, pvid=10, frames arrive untagged) |
| Default user | `ubuntu` |

**Build notes:**
- Uses the standard Ubuntu Noble boot resource synced by MaaS from Canonical's streams — no custom image import needed.
- **OVS is configured automatically** by the `maas.machine.config.networking` wave. Uses netplan with `openvswitch: {}` syntax for persistent bridge config.
- Same workflow as ms01-02: if `bridges[0].nic` is empty, discover NIC name first, fill in `bridges[0].nic`, then re-run the `maas.machine.config.networking` unit.

---

### nuc-1 — Intel NUC (General Purpose)

| Field | Value |
|---|---|
| Hardware | Intel NUC |
| OS | Ubuntu 24.04 LTS (Noble) |
| MaaS deploy | `deploy_distro: noble` (standard Ubuntu boot resource) |
| Network stack | systemd-networkd; VLAN 10 subinterface configured by cloud-init |
| IP | 10.0.10.119 (cloud_public VLAN 10 via subinterface) |
| Power | Kasa EP25 smart plug at 192.168.1.225 |
| PXE MAC | `48:21:0b:55:b4:5b` |
| Default user | `ubuntu` |

**Build notes:**
- Uses `cloud_init_configure_vlan10: true` which adds a VLAN 10 subinterface at cloud-init time, giving the NUC a stable cloud_public IP without OVS complexity.
- Single physical NIC, no 10G switch connection — connects via the Ubiquiti UniFi switch on VLAN 10.

---

### pxe-test-vm-1 — PXE Pipeline Validation VM

| Field | Value |
|---|---|
| Hardware | Proxmox VM on pve-1 |
| OS | Ubuntu 24.04 LTS (Noble) |
| MaaS deploy | `deploy_distro: noble` |
| Network stack | cloud-init default |
| IP | DHCP on provisioning VLAN 12; post-deploy via cloud_public |
| Power | Proxmox API on pve-1 (10.0.10.115) |

**Purpose:** Validates the full MaaS PXE pipeline — DHCP, TFTP, commissioning, image deployment — without requiring a physical machine. Destroyed and recreated with each test run.

---

## Network Stack Decision Guide

| Scenario | Stack | Why |
|---|---|---|
| Proxmox VE host | pvesh-managed Linux bridges | Proxmox API controls networking; pvesh is the right tool |
| Plain Ubuntu — single NIC, simple | systemd-networkd + VLAN subinterface | Minimal config, cloud-init can set it up |
| Plain Ubuntu — dedicated 10G NIC | netplan + OVS | netplan has native OVS syntax; clean persistent config |
| Rocky Linux — dedicated 10G NIC | NetworkManager + OVS | NM nmcli is the standard EL networking tool; OVS integration via `type ovs-*` connections |

---

## Post-Deploy OVS Setup (ms01-02, ms01-03)

OVS bridges on plain hosts are configured automatically by the `maas.machine.config.networking`
wave, which runs immediately after `maas.lifecycle.deployed`. The wave reads the declarative
`bridges:` list from `pwy-home-lab-pkg.yaml` for every machine with `technology: ovs` and
applies idempotent OVS configuration via Ansible.

**If the 10G NIC name is not yet known** (first deploy of a machine):
- Leave `bridges[0].nic: ""` in `pwy-home-lab-pkg.yaml` — the wave creates the OVS bridge
  without an uplink and warns that the NIC name needs to be discovered.
- Run `scripts/ai-only-scripts/discover-10g-nics/run` to find the NIC name.
- Fill in `bridges[0].nic` in `pwy-home-lab-pkg.yaml`, then re-run the wave:

```bash
source set_env.sh
cd infra/pwy-home-lab-pkg/_stack/null/pwy-homelab/maas/configure-plain-hosts
terragrunt apply
```

The `bridges:` list in `pwy-home-lab-pkg.yaml` is the source of truth. The wave applies it
idempotently — safe to re-run.

**Emergency manual fallback** (if the wave is broken): the ai-only script
`scripts/ai-only-scripts/configure-plain-host-ovs/` still exists for a single machine:
```bash
MACHINE=ms01-02 scripts/ai-only-scripts/configure-plain-host-ovs/run --build
```
Fix the wave automation rather than relying on this.

---

## Custom MaaS Boot Resources

Standard Ubuntu images are auto-synced by MaaS. Non-Ubuntu images require a
custom import pipeline (run during the `configure-maas-server` wave):

| OS | MaaS resource name | Source | Import task |
|---|---|---|---|
| Debian 13 (Trixie) | `custom/trixie` | Debian genericcloud qcow2 | `import-debian-image.yaml` |
| Rocky Linux 9 | `custom/rocky-9` | Rocky GenericCloud qcow2 | `import-rocky-image.yaml` |

Both pipelines: download qcow2 → mount via qemu-nbd → chroot to install GRUB EFI + `netplan` + `openssh-server` + `/curtin` marker → convert to raw → gzip → import as `ddgz` via MaaS CLI.
