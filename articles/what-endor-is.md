# What ENDOR is (snapshot, not a shopping list)

**Status:** draft  
**Lab:** ENDOR  
**Date:** 2026-09-07  
**Scope:** inventory of one machine as observed that day  
**Not:** a generic homelab flex, and not a complete parts list

<p align="center">
  <img src="images/endor-rack.jpg" alt="ENDOR rack with the glass door open: Ryzen host, Tesla P100 and GTX 960 on the top tray, UniFi Dream Machine Pro and 16-port PoE switch in the middle, spare disks on the shelf below" width="720">
</p>

<p align="center"><em>Floor rack, door parked to the side. Blower Tesla on the tray is the P100 (no display ports). The card to its right with the DisplayPort cable is a GTX 960 for occasional local outputs.</em></p>

Other notes in this repo assume a box named ENDOR. This is that box: what I will stand behind, what I will not invent, and what was actually running when I looked.

## Why this note exists

A Wolf Quadlet or an Immich pod is unreadable if you do not know the machine around it.

What I do have:

- A named lab, board, CPU, RAM, and OS point release
- One encode/compute GPU that forces a lot of the architecture, plus a GTX 960 for local video out
- Disk models plus the Btrfs RAID1 + bcache topology
- A runtime policy with one loud exception
- A `podman ps` from 2026-09-07

The photo is the case: a 12U glass-door floor rack, board on an open tray at the top. Current rack PSU label is unread. A power-pull test is still unpublished.

## The claim

**Observed:** ENDOR is hostname `endor`, chassis `desktop`, an ASUS PRIME B550-PLUS AC-HES running Ubuntu 26.04.1 LTS (`Linux 7.0.0-31-generic`). CPU is an AMD Ryzen 7 5800XT (8 cores / 16 threads). About 30 GiB RAM visible, no swap. Podman 5.7.0. NVIDIA host module `580.173.02`. Most workloads are rootless Podman Quadlets. Wolf and AdGuard Home are rootful. The interesting GPU is a reused Tesla P100 16 GB (`nvidia0`, `/dev/dri/renderD128`). A GTX 960 sits next to it on the same tray and takes a DisplayPort cable when I need a local picture; Wolf/Immich/Jellyfin are not documented as using that card. Bulk app/photo state sits on Btrfs over bcache (writethrough) at `/mnt/network`. Media is a separate 16 TB disk. In front of the host: a UniFi Dream Machine Pro (1 TB HDD) and a USW-16-PoE. UDM-Pro WAN is an Ethernet-to-SFP transceiver because the Spectrum handoff is sold as 1 Gbps and the circuit regularly runs faster than that; the SFP port is how that link lands. DNS on the box is AdGuard Home. Power path is a CyberPower S175UC on NUT, plus wake-on-LAN. Everyday management is Cockpit plus `journalctl`.

**Not claimed:** measured WAN throughput, a pull-the-plug test, or any GPU benchmark. Swap is off on purpose.

## Hardware I will name

| Piece | What I know | Why it matters |
| --- | --- | --- |
| Board | ASUS PRIME B550-PLUS AC-HES, firmware 3621 (2025-01-13) | AM4 desktop board, not a 1U chassis |
| CPU | Ryzen 7 5800XT, 8c/16t | Enough host CPU that Wolf encode is a choice |
| RAM | 30 GiB visible, 0 swap | Swap is disabled so Ubuntu does not wear the NVMe |
| GPU (encode / compute) | Tesla P100 16 GB, nvidia0 / renderD128, module 580.173.02 | Printed shroud + Wathai 9733, PWM from p100-fan-control.service |
| GPU (local display) | GTX 960, DisplayPort cable visible on the right of the tray | Occasional graphical output. Not the Wolf/Immich card in these notes |
| Case | 12U glass-door rack; board on an open tray at the top | Photo above; same file at [images/endor-rack.jpg](images/endor-rack.jpg) |
| GPU consumers | Wolf (rootful), Immich server + ML via CDI, Ollama | Those workloads are wired to the P100 |
| OS / runtime | Ubuntu 26.04.1 LTS, kernel 7.0.0-31-generic, Podman 5.7.0 | Immich ML healthcheck quoting broke on this pairing |
| Storage | Btrfs on bcache writethrough; NVMe root; separate media + Time Machine disks | Not ZFS. Not one big pool |
| Network | UDM-Pro (1 TB HDD) + USW-16-PoE; WAN on SFP via Ethernet-to-SFP; AdGuard Home | SFP is the circuit, not a 10 Gb flex |
| Power | CyberPower S175UC on NUT, plus WOL | No published pull-the-plug test |
| Console | Cockpit, including cockpit-podman | Same engine the Quadlets use |

Why this card exists: [Why I bought a sub-$100 Tesla P100](why-i-bought-a-tesla-p100.md).

## Runtime model

House style: Ubuntu 26.04.1 LTS, Podman 5.7.0, Quadlets, rootless user units for almost everything.

| Workload | Privilege | Live unit location |
| --- | --- | --- |
| Wolf | rootful system Quadlet | /etc/containers/systemd/wolf.container |
| AdGuard Home | rootful | system container |
| Everything else below | rootless | ~/.config/containers/systemd/ |

## What was running on 2026-09-07

### Rootful

| Name | Role |
| --- | --- |
| Wolf | Moonlight supervisor. Sanitized unit: [configs/wolf/](../configs/wolf/) |
| AdGuard Home | LAN DNS. Technitium is planned, not running |

### Rootless

Uptime Kuma; Scrypted (+ Watchtower); LubeLogger + Postgres; AirTrail DB only; Jellyfin (daily client is Infuse); Ollama; Jellyseerr; Home Assistant; Immich pod ([configs/immich/](../configs/immich/)).

Immich ML is healthy as of later 2026-09-07 after a HealthCmd quoting fix on Podman 5.7.0 / Ubuntu 26.04.1. That is liveness, not an embeddings benchmark.

## Disks

| Device | Size | Model | Role |
| --- | --- | --- | --- |
| nvme0n1 | 931.5 G | CT1000P3SSD8 | EFI + /boot + LVM root ext4 |
| sda | 465.8 G | WDC WDS500G1R0A | bcache cache |
| sdb | 3.6 T | ST4000NE001-2MA1 | bcache0 Btrfs (unmounted in dump) |
| sdc | 3.6 T | ST4000NE001-2MA1 | bcache1 Btrfs at /mnt/network |
| sdd | 14.6 T | ST16000NM001G-2K | ext4 /mnt/media |
| sde | 3.6 T | ST4000VN006-3CW1 | Time Machine splits |

Cache mode is writethrough.

## Unfinished

- AirTrail app missing from podman ps
- Immich memories unit on disk, stopped
- Wolf remains rootful
- NVIDIA driver updates still mean rebuild gow/nvidia-driver + nvidia-driver-vol + CDI
- No published power-fail test
- Current rack PSU model unread
- UniFi APs unnamed

LAN address, paths under /mnt/network, GPU UUID, Wolf config.toml, DB passwords, and hostnamectl Machine/Boot ID stay off this repo.
