# homelab-notes

Engineering notes from **ENDOR** — an Ubuntu Server homelab running mostly rootless Podman, Quadlets, a reused Tesla P100, Wolf/Moonlight, and Btrfs RAID1 + bcache.

These are not generic tutorials. They are what I actually ran, what broke, and what I would do differently.

## Notes

| Date | Title | Status |
| --- | --- | --- |
| 2026-09-07 | [What ENDOR is (snapshot, not a shopping list)](articles/what-endor-is.md) | draft |
| 2026-09-07 | [Why I bought a sub-$100 Tesla P100](articles/why-i-bought-a-tesla-p100.md) | published |
| 2026-09-07 | [Why I run Wolf on Podman instead of Docker (even though the permissions are worse)](articles/why-i-run-wolf-on-podman.md) | published |
| 2026-09-08 | [I broke Wolf after an NVIDIA driver update — the volume still had yesterday's libcuda](articles/i-broke-wolf-after-an-nvidia-driver-update.md) | published |

X Article drafts live in [`articles/x/`](articles/x/). GitHub notes above stay canonical.

## Layout

```text
articles/     published and draft write-ups
articles/x/   X Article drafts (distribution)
configs/      sanitized Quadlets (wolf is rootful; most of the lab is not)
```

Wolf unit: [`configs/wolf/wolf.container`](configs/wolf/wolf.container)

Hobby project. Updates happen when something breaks or gets rebuilt.
