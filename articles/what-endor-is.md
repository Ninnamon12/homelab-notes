# What ENDOR is (snapshot, not a shopping list)

**Status:** draft  
**Lab:** ENDOR  
**Date:** 2026-09-07  
**Scope:** inventory of one machine as observed that day  
**Not:** a generic "my homelab 2026" flex, and not a complete parts list

Other notes in this repo assume a box named ENDOR. This is that box: what I will stand behind, what I will not invent, and what was actually running when I looked.

## Why this note exists

A Wolf Quadlet or an Immich pod is unreadable if you do not know the machine around it.

The usual homelab overview solves that by listing every SKU and a tidy architecture diagram. I do not have a complete SKU list written down in this repo, and I am not going to fabricate one so the page looks finished.

What I do have:

- A named lab, board, CPU, RAM, and OS point release
- One GPU that forces a lot of the architecture
- Disk models plus the Btrfs RAID1 + bcache topology
- A runtime policy with one loud exception
- A `podman ps` from 2026-09-07

PSU and case still unnamed. A power-pull test is still unpublished.

## The claim

**Observed:** ENDOR is hostname `endor`, chassis `desktop`, an ASUS PRIME B550-PLUS AC-HES running Ubuntu 26.04.1 LTS (`Linux 7.0.0-31-generic`). CPU is an AMD Ryzen 7 5800XT (8 cores / 16 threads). About 30 GiB RAM visible, no swap. Podman 5.7.0. NVIDIA host module `580.173.02`. Most workloads are rootless Podman Quadlets. Wolf and AdGuard Home are rootful. The interesting GPU is a reused Tesla P100 16 GB (`nvidia0`, `/dev/dri/renderD128`). Bulk app/photo state sits on Btrfs over bcache (writethrough) at `/mnt/network`. Media is a separate 16 TB disk. In front of the host: a UniFi Dream Machine Pro (1 TB HDD) and a USW-16-PoE. UDM-Pro WAN is an Ethernet-to-SFP transceiver because the Spectrum handoff is sold as 1 Gbps and the circuit regularly runs faster than that; the SFP port is how that link lands. DNS on the box is AdGuard Home. Power path is a CyberPower S175UC on NUT, plus wake-on-LAN. Everyday management is Cockpit plus `journalctl`.

**Not claimed:** PSU, case, measured WAN throughput, a pull-the-plug test, or any GPU benchmark. Swap is off on purpose, not because the box has no RAM pressure.

**Inferred:** people landing on the Wolf note want this page first so they stop assuming a GeForce in a Docker compose stack.

## Hardware I will name

| Piece | What I know | Why it matters |
| --- | --- | --- |
| Board | ASUS PRIME B550-PLUS AC-HES, firmware 3621 (2025-01-13) | AM4 desktop board, not a 1U chassis. Onboard Wi-Fi/AC is in the SKU name; the lab network in front of this host is still UniFi. |
| CPU | Ryzen 7 5800XT, 8c/16t, boost listed to ~4.97 GHz | Enough host CPU that Wolf encode is a *choice*, not a rescue from a Celeron. |
| RAM | 30 GiB visible, 0 swap | Swap is disabled so Ubuntu does not wear the NVMe as overflow. That is policy. |
| GPU | Tesla P100 16 GB, host nodes `nvidia0` and `renderD128`, module `580.173.02` | No display outputs. Wolf runs headless wlroots. Zero-copy is off. |
| GPU consumers | Wolf (rootful), Immich server + ML via CDI `nvidia.com/gpu=0`, Ollama | One card, several personalities. Driver updates are a lab event, not an `apt` footnote. |
| OS / runtime | Ubuntu 26.04.1 LTS, kernel 7.0.0-31-generic, Podman 5.7.0 | Version pin for every Quadlet note. Immich ML healthcheck quoting broke on this pairing. |
| Storage shape | Btrfs on bcache **writethrough** in front of two 4 TB HDDs; NVMe root; separate media + Time Machine disks | Cache can accelerate reads. It is not allowed to lie about writes. Not ZFS. Not one big pool. |
| Data placement | App state and photo library live under `/mnt/network` | Containers are not the source of truth. The mount is. Published configs rewrite the paths under it. |
| Network | UDM-Pro (1 TB HDD) + USW-16-PoE; WAN on SFP via Ethernet-to-SFP; AdGuard Home on the box | Gateway and switch are named. APs are not. The SFP WAN choice is the circuit, not a 10 Gb homelab flex. |
| Power | CyberPower S175UC on NUT, plus WOL | Model is named. A pull-the-plug test is still not in this repo. |
| Console | Cockpit, including cockpit-podman | Same engine the Quadlets use. |

The P100 is the part that keeps showing up in other notes, so it gets the only extra paragraph.

It is a Pascal datacenter card. It has HBM2 and no monitor ports. Wolf therefore sets `WLR_BACKEND=headless` and `WOLF_RENDER_NODE=/dev/dri/renderD128`. Immich talks to the same card through CDI, not through Wolf's driver volume. Mixing those two GPU stories is how an evening disappears.

Why this card exists on ENDOR is a separate note: [Why I bought a sub-$100 Tesla P100](why-i-bought-a-tesla-p100.md). This page is only "what is in the chassis that other articles keep pointing at."

## Runtime model

House style:

- Ubuntu 26.04.1 LTS
- Podman 5.7.0
- Quadlets under systemd
- Rootless user units for almost everything
- One engine, so Cockpit and `journalctl` see the same world

Exceptions that are part of the design, not accidents:

| Workload | Privilege | Live unit location | Why |
| --- | --- | --- | --- |
| Wolf | rootful system Quadlet | `/etc/containers/systemd/wolf.container` | Host devices, `podman.socket`, sibling session containers |
| AdGuard Home | rootful | system container | DNS for the LAN is not a user-session service |
| Everything else observed below | rootless | `~/.config/containers/systemd/` | Default |

Calling ENDOR "a rootless Podman homelab" is still the shortest true sentence. Wolf is the sentence after it.

## What was running on 2026-09-07

Snapshot from `podman ps` that day. Names are as the runtime reported them. This is not a promise that the same list will be true next month.

### Rootful

| Name | Role | Notes |
| --- | --- | --- |
| Wolf | Moonlight game streaming supervisor | System Quadlet. Starts Steam (and other session apps) as sibling containers through `podman.sock`. Sanitized unit: [`configs/wolf/`](../configs/wolf/). |
| AdGuard Home | LAN DNS / filtering | Rootful. Technitium is a planned migration, not what is running. |

### Rootless

| Name | Role | Notes |
| --- | --- | --- |
| Uptime Kuma | Monitoring | — |
| Scrypted | Cameras / home video | Watchtower sits next to this stack. That is observed, not a lab-wide update policy. |
| LubeLogger + Postgres | Vehicle maintenance | Own Postgres, not shared with Immich. |
| AirTrail DB | Flight-log backend | Database container only. The app container was not in `podman ps`. |
| Jellyfin | Media | Daily playback is Infuse. |
| Ollama | Local models | Shares the P100 in principle. No benchmark in this repo. |
| Jellyseerr | Requests in front of Jellyfin | — |
| Home Assistant | Home automation | — |
| Immich (pod) | Photos | Infra + server + Redis + Postgres + CUDA ML. Sanitized units: [`configs/immich/`](../configs/immich/). |

### Immich, because it is the other GPU stack

- Rootless pod + dedicated network
- Ports published on the *pod*, not the member containers (Podman 5 rejects `PublishPort=` on a container that joined a pod)
- Dual bind: loopback plus one LAN address. Not `0.0.0.0`. The real LAN IP stays off this repo.
- GPU via `AddDevice=nvidia.com/gpu=0` on server and ML
- ML image is the CUDA tag, started with `--disable-cuda-graph`
- **`immich_machine_learning` was unhealthy** in the original `podman ps` snapshot. Same-day diagnosis: a nested `python -c` HealthCmd that had been stable on Podman 4.9.3 / Ubuntu 24.04.4 died on Podman 5.7.0 / Ubuntu 26.04.1 with `/bin/sh: Syntax error: Unterminated quoted string`. JSON exec form against `/ping` made the container healthy again. Host and engine both changed; cause not isolated to one.
- `immich-memories.container` exists on disk and was not running
- DB password is still inlined in the live units. The published tree uses placeholders.

Do not copy the Immich units and assume CUDA ML *quality* works on a P100. The files document what is deployed. They do not document a smart-search bake-off.

## Disks, as `lsblk` reported them

Root is boring on purpose. The interesting pool is not the OS disk.

| Device | Size | Model | Role |
| --- | --- | --- | --- |
| `nvme0n1` | 931.5 G | CT1000P3SSD8 | EFI + `/boot` + LVM `ubuntu-vg/ubuntu-lv` on `/` (ext4) |
| `sda` | 465.8 G | WDC WDS500G1R0A | bcache cache device |
| `sdb` | 3.6 T | ST4000NE001-2MA1 | bcache backing → `bcache0` (Btrfs, not mounted in this dump) |
| `sdc` | 3.6 T | ST4000NE001-2MA1 | bcache backing → `bcache1` (Btrfs at `/mnt/network`) |
| `sdd` | 14.6 T | ST16000NM001G-2K | ext4 `/mnt/media` |
| `sde` | 3.6 T | ST4000VN006-3CW1 | ext4 Time Machine splits (`/mnt/timemachine_macbookpro`, `/mnt/timemachine_macmini`) |

`bcache0` and `bcache1` both show as 3.6 T Btrfs. Only `bcache1` was mounted (`/mnt/network`) in this dump. Cache mode is **writethrough**: the SSD can make reads cheaper; it does not become the source of truth for writes. That is the RAID1 + bcache *shape* other notes keep pointing at. The full `btrfs filesystem show` write-up is still the dedicated storage article.

Top-level mounts I will name: `/`, `/boot`, `/mnt/network`, `/mnt/media`, the two Time Machine mounts. Paths *under* `/mnt/network` stay rewritten in published Quadlets.

## Storage, network, power — only the shape

```text
clients (Moonlight, browsers, phones, Infuse)
        |
        v
   UDM-Pro (WAN via Ethernet-to-SFP)
        USW-16-PoE
        |
        |- AdGuard Home          (rootful DNS)
        +- ENDOR
              |- Cockpit
              |- rootless Quadlets
              |- Wolf  -- podman.sock -- session containers (Steam, …)
              |- P100  -- nvidia0 / renderD128
              |            |- Wolf (driver volume + devices)
              |            +- Immich / others (CDI)
              |- NVMe root (ext4 / LVM)
              |- Btrfs RAID1 + bcache writethrough → /mnt/network
              |- 16 TB ext4 → /mnt/media
              +- 4 TB ext4 → Time Machine targets
```

Power: CyberPower S175UC on NUT, WOL to bring the box back. I have not published a pull-the-plug test in this repo. Until that note exists, treat "automatic recovery" as intent plus wiring, not as a measured RTO.

I am not publishing:

- The LAN address
- Paths under `/mnt/network` (photo library, container state)
- GPU UUID
- Wolf `config.toml` (Moonlight client certificates)
- Database passwords
- `hostnamectl` Machine ID / Boot ID

## What is unfinished on the box

These are not secrets. They are the honest holes so a later article does not have to pretend the lab is tidy.

- Immich ML was unhealthy in the first snapshot; healthcheck quoting was the immediate bug. CUDA-on-P100 quality is still unproven here
- AirTrail is a database without its app in `podman ps`
- Immich memories unit is on disk, stopped
- Wolf remains rootful; there is no rootless Wolf I would tell someone to copy
- NVIDIA driver updates still mean: regenerate CDI, rebuild `gow/nvidia-driver` against `/sys/module/nvidia/version`, refill `nvidia-driver-vol`, restart Wolf. Not automated.
- DNS migration to Technitium is backlog, not a cutover
- PSU and case still unnamed
- UniFi APs unnamed (gateway and PoE switch are)
- `bcache0` unmounted in the dump; do not invent why
- No published power-fail test on the S175UC

## How to read the rest of the repo against this map

| Note | What it assumes you already know |
| --- | --- |
| [Why I bought a sub-$100 Tesla P100](why-i-bought-a-tesla-p100.md) | Encoders exist for Wolf; Infuse is the daily media client; Immich ML healthcheck was the same-day fire |
| [Why I run Wolf on Podman](why-i-run-wolf-on-podman.md) | P100 has no outputs; Wolf is the rootful exception; socket is `:rw` |
| [`configs/wolf/`](../configs/wolf/) | After a host driver bump, the official quickstart is not the ops procedure |
| [`configs/immich/`](../configs/immich/) | Dual bind, GPU on the container, ML flag, HealthCmd quoting |

Planned notes that hang off the same machine, not written yet:

- Tesla P100 as a game-streaming card (Wolf encode path)
- Wolf after an NVIDIA driver update (postmortem, not just commands)
- Btrfs RAID1 + bcache instead of ZFS
- Power-fail recovery (NUT + WOL), once there is a test log

## What I would tell someone else

If you want a shopping list for "a homelab that runs Immich and Jellyfin," this page will disappoint you. Buy whatever you already have. The interesting decisions on ENDOR are not the case fans.

If you are reading the Wolf or Immich files and wondering why the units look hostile — host devices, two privilege domains, a driver volume *and* CDI, network mounts, dual binds — this is why. One reused P100, one Podman engine, two GPU integration stories, and a refusal to run Docker just so the first README is happier.

## What this article is not

- A complete bill of materials
- A performance claim for the P100, Ollama, or Jellyfin
- A network diagram with VLANs and SSIDs
- An invitation to scrape the LAN
- Proof that every container in the table is a good idea

## Later

Still missing, not invented:

- PSU and case
- UniFi AP models
- `btrfs filesystem show` (mode is known: writethrough)
- A power-pull test log on the S175UC
- Measured WAN numbers that justify the SFP story (owner-observed "faster than 1 Gbps"; no iperf in this repo)

Machine ID and boot ID from `hostnamectl` stay off this repo.
