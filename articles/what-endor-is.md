# What ENDOR is (snapshot, not a shopping list)

**Status:** draft  
**Lab:** ENDOR  
**Date:** 2026-09-07  
**Scope:** inventory of one machine as observed that day  
**Not:** a generic "my homelab 2026" flex, and not a complete parts list

Other notes in this repo assume a box named ENDOR. This is that box: what I will stand behind, what I will not invent, and what was actually running when I looked.

## Why this note exists

A Wolf Quadlet or an Immich pod is unreadable if you do not know the machine around it.

What I do have:

- A named lab, board, CPU, RAM, and OS point release
- One GPU that forces a lot of the architecture
- Disk models plus the Btrfs RAID1 + bcache topology
- A runtime policy with one loud exception
- A `podman ps` from 2026-09-07

Current rack PSU label is unread. A power-pull test is still unpublished.

## The claim

**Observed:** ENDOR is hostname `endor`, chassis `desktop`, an ASUS PRIME B550-PLUS AC-HES running Ubuntu 26.04.1 LTS (`Linux 7.0.0-31-generic`). CPU is an AMD Ryzen 7 5800XT (8 cores / 16 threads). About 30 GiB RAM visible, no swap. Podman 5.7.0. NVIDIA host module `580.173.02`. Most workloads are rootless Podman Quadlets. Wolf and AdGuard Home are rootful. The interesting GPU is a reused Tesla P100 16 GB (`nvidia0`, `/dev/dri/renderD128`). Bulk app/photo state sits on Btrfs over bcache (writethrough) at `/mnt/network`. Media is a separate 16 TB disk. In front of the host: a UniFi Dream Machine Pro (1 TB HDD) and a USW-16-PoE. UDM-Pro WAN is an Ethernet-to-SFP transceiver because the Spectrum handoff is sold as 1 Gbps and the circuit regularly runs faster than that; the SFP port is how that link lands. DNS on the box is AdGuard Home. Power path is a CyberPower S175UC on NUT, plus wake-on-LAN. Everyday management is Cockpit plus `journalctl`.

**Not claimed:** measured WAN throughput, a pull-the-plug test, or any GPU benchmark. Swap is off on purpose.

See the working copy in this conversation for the full hardware table, disk inventory, running stack, and unfinished list. This file was trimmed only if the GitHub API rejected the long draft; prefer the complete local `articles/what-endor-is.md`.
