# What ENDOR is: one box, one day, and what I won't claim about it

Cover image: the rack shot (`articles/images/endor-rack.jpg`).

Promo post to attach when you publish: at the bottom.

---

Every homelab note I write assumes a box called ENDOR.

This is that box on 7 Sep 2026. No benchmarks. No parts list. Just what was actually running.

## The box

ASUS PRIME B550-PLUS. Ryzen 7 5800XT, 8 cores, 16 threads.

About 30 GiB of RAM. Swap off on purpose.

Ubuntu 26.04.1 LTS, kernel 7.0.0-31. Podman 5.7.0.

It lives on an open tray at the top of a 12U glass-door floor rack. A UDM-Pro and a 16-port PoE switch sit under it.

## Two GPUs, one job

The blower card is a reused Tesla P100 16 GB. It does the work: Wolf for Moonlight streaming, Immich, Jellyfin, Ollama.

The card next to it is a GTX 960. It is there for a local picture when I plug in a DisplayPort cable. None of those workloads use it.

## Rootless, with two exceptions

Almost everything is a rootless Podman Quadlet: Immich, Jellyfin, Home Assistant, Uptime Kuma, Scrypted, LubeLogger, Ollama, Jellyseerr.

Two things run rootful. Wolf wants host devices and a container API, so it runs as a system Quadlet. AdGuard Home is the box's DNS.

Docker is not installed. This is not a bake-off.

## Storage

Btrfs over bcache in writethrough mode. A 500 GB SSD caches two 4 TB drives.

Root is on NVMe. Media is a separate 16 TB disk. Time Machine has its own drive.

Not ZFS. Not one big pool.

## What broke the next day

On 8 Sep, Ubuntu moved the NVIDIA driver from 580.173.02 to 580.178.04. Wolf stayed up. The stream died. The driver volume still had yesterday's libcuda.

That is its own write-up. This snapshot keeps the 7 Sep numbers.

## What I am not claiming

No GPU, disk, or WAN number was measured for this.

No pull-the-plug test. The UPS is on NUT. I have not published a power-fail run.

Not a recommendation. It is one machine on one day.

## The long version

Disk table, runtime table, and what is still unfinished:

https://github.com/Ninnamon12/homelab-notes/blob/main/articles/what-endor-is.md

---

## Promo post (paste this when you publish the Article)

Every homelab note I write assumes a box called ENDOR. Here it is on one day: a reused Tesla P100, rootless Podman with two rootful exceptions, Btrfs over bcache. No benchmarks, no parts list.
