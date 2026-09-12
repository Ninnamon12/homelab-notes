# I broke Wolf after an NVIDIA driver update — the volume still had yesterday's libcuda

**Status:** published  
**Lab:** ENDOR  
**Date:** 2026-09-08 (written 2026-09-12)  
**Scope:** one `apt` bump of the host NVIDIA module, one rootful Wolf Quadlet, one named volume  
**Not:** a Docker bake-off, a CDI tutorial, or a claim that Wolf was down as a systemd unit

On 8 Sep 2026 I let Ubuntu update the host NVIDIA module on ENDOR from `580.173.02` to `580.178.04`. Wolf stayed up. Moonlight still found the host. The stream died.

This is the postmortem the Wolf-on-Podman note said it was waiting for. Commands that I actually used live next to the unit: [`configs/wolf/README.md`](../configs/wolf/README.md). This page is what failed, what looked healthy while it was failing, and which official recipe did not pour the new driver.

## The claim

**Observed:** after `apt` moved `580-server` `580.173.02` → `580.178.04`, `/sys/module/nvidia/version` was `580.178.04`. `wolf.service` stayed running. The health check on TCP `47989` still passed, so systemd called the unit healthy. A Moonlight client still reached the host. GStreamer logged `CUDA_ERROR_SYSTEM_DRIVER_MISMATCH`. Wolf selected software `x264` / `x265` instead of `nvcodec`. The compositor then failed in `waylanddisplaysrc` (`Failed to create EGLDisplay`, then `PoisonError` / `RecvError`). `nvidia-driver-vol` still contained `libcuda.so.580.173.02`. Restarting Wolf remounted that same volume. The GoW `nvidia_temp` recipe did not refresh it. Rebuilding `localhost/gow/nvidia-driver:latest` against the new module and copying `/usr/nvidia` onto the existing volume mountpoint made Wolf log `Using h264 encoder: nvcodec` and `Using h265 encoder: nvcodec` again. AV1 stayed on `aom`. The P100 has no AV1 NVENC.

**Documented (Games on Whales, not my invention):** anytime the host NVIDIA driver changes, the userspace in `nvidia-driver-vol` has to match. Their troubleshooting page says recreate the volume from the quickstart. The `nvidia_temp` helper is written as a first-install seed.

**Not claimed:** that Podman handles this better than Docker. Docker users hit the same mismatch (GoW wolf#410 is the same CUDA error after a host bump). I did not install Docker on ENDOR to compare pour methods. I also did not time the stream before and after. "Hardware encode came back" is the observation. "The stream felt faster" is not.

**Inferred:** a health check on the Moonlight control port will not catch an encoder fallback. Healthy here means "TCP 47989 answers," not "nvcodec loaded against the running module."

## What I thought I was doing

Host driver updates on this box are supposed to be a short checklist, already written into the Wolf unit comments as "Phase 2 Shadowing":

1. Confirm `/sys/module/nvidia/version` is the version I meant to run.
2. Refresh whatever userspace the workloads actually load.
3. Restart those units.

Two GPU stories share the P100. They do not share a refresh procedure.

| Workload | How it sees the P100 | What an `apt` bump actually stale-dates |
| --- | --- | --- |
| Wolf (rootful system Quadlet) | named volume `nvidia-driver-vol` at `/usr/nvidia`, plus `LD_LIBRARY_PATH` | the files inside that volume |
| Immich / Jellyfin / other CDI units | `AddDevice=nvidia.com/gpu=0` | `/etc/cdi/nvidia.yaml` |

I regenerated CDI for the rootless stack. That is the correct move for Immich. It is not what Wolf loads. Wolf's Quadlet never asks NVIDIA Container Toolkit for a device. It bind-mounts `nvidia0` / `renderD128` and hopes `/usr/nvidia/lib/libcuda.so.1` is the same module the kernel just loaded.

## What it looked like from the couch

The failure did not look like "GPU passthrough is gone."

- `systemctl status wolf` was fine.
- Cockpit still listed the container.
- Moonlight still resolved the host and opened a session.
- The picture then died in the compositor, not at the handshake.

That split is why I wasted time on the wrong layer. A dead unit is a Quadlet problem. A live unit that encodes with `x264` on a P100 is a library problem.

The log line that mattered was not the EGL panic. That was the downstream crash. The line that named the cause was:

```text
CUDA_ERROR_SYSTEM_DRIVER_MISMATCH
```

followed by Wolf picking the software encoders. On this card, software H.264/H.265 is the fallback I bought the Tesla to avoid. AV1 on `aom` after the fix is expected. Do not treat that as a second failure.

## Failed approaches

These are the ones I actually tried, or that the docs told me to try, before the copy-into-the-volume pour.

**Restart Wolf.**  
`sudo systemctl restart wolf` remounts `nvidia-driver-vol`. The volume still had `libcuda.so.580.173.02`. The unit came back healthy on port 47989. The mismatch came back with it.

**Regenerate CDI and restart Immich.**  
`sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` is required on this host after a module change. It does not write `nvidia-driver-vol`. Mixing the two stories is how an evening disappears.

**The official `nvidia_temp` pour on an existing volume.**  
Wolf's NVIDIA manual path builds `gow/nvidia-driver` and starts a helper with `nvidia-driver-vol` mounted on `/usr/nvidia`. That works the first time, when the volume is empty and the image files become the volume files. On a volume that already has yesterday's driver, the mount *hides* the image files. `podman start nvidia_temp` copies nothing useful onto the volume. I have now watched that happen.

**Delete the volume and start over.**  
That is what several write-ups, including GoW's "recreate the volume" snippet, tell you to do. I did not do it on this bump. Wolf's `/etc/wolf` bind is separate from the driver volume, but I already had a volume with the right *shape* and a Quadlet that names it. The missing step was replacing the files inside it. If you do delete the volume, you still have to get files onto it; `nvidia_temp` only helps once it is empty again.

**Build the GoW image the way a laptop build works.**  
Isolated `podman build` on ENDOR cannot resolve Ubuntu mirrors. Host `resolv.conf` points at AdGuard on `127.0.0.1`. The build jail does not have a DNS server. `--network=host` is what made the build finish. That is an ENDOR DNS fact, not a GoW bug.

**Tag the image `gow/nvidia-driver` and refer to it by short name.**  
Rootful Podman on this box does not resolve that short name as a local image. `localhost/gow/nvidia-driver:latest` is the tag that stays in the rootful store. Even then, `localhost/...` looks like a registry. Create the extract container by **image ID**.

**Reuse cached build layers.**  
The Dockerfile is the same file. The build-arg is not. Layers from `580.173.02` are the wrong userspace. `--no-cache` after an `apt` bump.

**Exec into the scratch image to copy files.**  
`gow/nvidia-driver` is `FROM scratch`. There is no glibc. `/bin/sh` cannot exec. That image is a file tree, not a helper OS. `podman create` + `podman cp` is the extract path. `podman run ... sh` is not.

**Trust `systemctl show wolf` for `LD_LIBRARY_PATH`.**  
The host unit expands `${LD_LIBRARY_PATH}` in the Quadlet. `systemctl show` can print that variable empty. Inside the container the unit still prefixes `/usr/nvidia/lib:/usr/nvidia/lib32:`. Empty on the host is not proof the container lost the path.

## What actually poured 580.178.04

Source of truth is the running module:

```bash
cat /sys/module/nvidia/version
```

That printed `580.178.04` before I touched the volume. Then: fetch the current GoW Dockerfile, build with host networking and no cache, create a container from the image ID, `podman cp` `/usr/nvidia` to `/tmp`, copy those files onto the volume mountpoint, confirm `libcuda.so.1` points at `580.178.04`, restart Wolf, confirm the same symlink inside the running container, and read the encoder lines from `journalctl -u wolf`.

The exact command block is in [`configs/wolf/README.md`](../configs/wolf/README.md). I am not going to maintain two copies of a procedure that already bit me for being stale.

A merge-copy leaves leftover `*.so.580.173.02` files next to the new ones. That is what this volume looks like after the 8 Sep pour. It is fine as long as `libcuda.so.1` is the new module. I have not cleaned the leftovers. I have not automated the pour. A missed rebuild after `apt` is how this failure returns.

After the restart, Wolf selected `h264`/`h265` `nvcodec` and stayed on the legacy pipeline against `renderD128`. Zero-copy is still off. That flag is how the stream works on this Tesla, not part of the driver-volume fix.

## What I would do differently

- Treat "Moonlight connected" as a handshake check, not an encode check. The line to grep after a driver bump is `nvcodec` / `mismatch` / `Using h26`, not `active`.
- Stop expecting the first-install helper to be an upgrade helper. Empty volume and existing volume are different operations.
- Keep the two NVIDIA refresh paths on separate sticky notes. CDI regen is for Immich and friends. Volume pour is for Wolf. Doing only one of them is how half the lab looks fine.
- Build GoW images with `--network=host` on this box without rediscovering AdGuard.
- Pin the extract to an image ID so a short name does not become a pull.

I still would not install Docker to see whether `docker volume rm` plus their snippet is prettier. The mismatch is the volume contents versus `/sys/module/nvidia/version`. The engine that mounted the volume is not the interesting part.

## Limitations

- One bump: `580.173.02` → `580.178.04` on Ubuntu 26.04.1, Podman 5.7.0, Tesla P100, Wolf as a system Quadlet.
- I did not capture a full `journalctl -u wolf` blob for this repo. The strings above are the ones I used to decide I was done.
- I have not tested deleting `nvidia-driver-vol` and reseeding it empty. The copy-in path is what I ran.
- Immich after this bump was "regenerate CDI and restart the pod." That is a different note. Healthy Immich ML after the HealthCmd quoting fix is not evidence about this volume.

## Related

- [Why I run Wolf on Podman](why-i-run-wolf-on-podman.md)
- [Why I bought a sub-$100 Tesla P100](why-i-bought-a-tesla-p100.md)
- [What ENDOR is](what-endor-is.md)
- [Wolf unit (sanitized)](../configs/wolf/wolf.container)
- [After an NVIDIA driver update (commands)](../configs/wolf/README.md)
- [Wolf troubleshooting — recreating the NVIDIA driver volume](https://games-on-whales.github.io/wolf/stable/user/troubleshooting.html)
- [Wolf quickstart](https://games-on-whales.github.io/wolf/stable/user/quickstart.html)
- [GoW wolf#410 — same CUDA mismatch after a host driver bump](https://github.com/games-on-whales/wolf/issues/410)
