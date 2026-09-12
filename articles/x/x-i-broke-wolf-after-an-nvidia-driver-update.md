# Wolf still answered Moonlight. The volume had yesterday's libcuda

Cover: skip the rack hero. This is a log story, not a hardware unbox.

Promo post to attach when you publish: at the bottom.

---

I updated the NVIDIA driver on my homelab.

Wolf stayed up. Moonlight still found the box. The stream died.

The container was fine. The named volume still had yesterday's `libcuda`.

## The bump

8 Sep 2026. ENDOR. Ubuntu's `580-server` package.

`580.173.02` → `580.178.04`.

`/sys/module/nvidia/version` said the new number. That is the only source of truth I trust after `apt`.

Wolf is a rootful system Quadlet. Tesla P100 as `nvidia0` / `renderD128`. NVIDIA userspace is not "whatever the image shipped." It is a Podman volume, `nvidia-driver-vol`, mounted at `/usr/nvidia`, with `LD_LIBRARY_PATH` pointed at that tree first.

That volume is how I stopped the image and the host from shadowing each other. It is also how a driver update becomes a stream outage that looks like a GPU problem.

## What "healthy" meant

`wolf.service` did not fall over.

The health check is TCP 47989 — Moonlight's control port. Systemd called the unit healthy because that port answered.

Moonlight still opened a session.

Then GStreamer logged `CUDA_ERROR_SYSTEM_DRIVER_MISMATCH`. Wolf picked software `x264` and `x265` instead of `nvcodec`. The compositor failed in `waylanddisplaysrc`: `Failed to create EGLDisplay`, then a poison/recv crash.

I spent time on the wrong layer because the handshake worked. A dead unit is a Quadlet problem. A live unit encoding with `x264` on a P100 is a library problem.

## What did not pour the new driver

Restarting Wolf remounts the same volume. The volume still had `libcuda.so.580.173.02`.

Regenerating `/etc/cdi/nvidia.yaml` is the correct move for Immich and the other CDI units on this box. Wolf does not load that spec. Two GPU stories, two refresh paths. I keep mixing them.

Games on Whales tell you to recreate `nvidia-driver-vol` after a host driver change. Their `nvidia_temp` helper is a first-install seed. Mount that volume over `/usr/nvidia` on a volume that already has files, and the mount hides the new image. Starting the helper copies nothing onto yesterday's driver.

The GoW image is `FROM scratch`. You cannot `podman run` it and get a shell. There is no glibc. It is a file tree. `podman create` plus `podman cp` is the extract. `sh` is not.

Isolated `podman build` on this host cannot resolve Ubuntu mirrors. DNS on the box is AdGuard at `127.0.0.1`. The build jail does not have a resolver. `--network=host` is what made the build finish.

Short name `gow/nvidia-driver` does not resolve in rootful Podman here. Tag `localhost/gow/nvidia-driver:latest`, then create the extract container by image ID. Cached layers from the previous `NV_VERSION` are the wrong userspace. `--no-cache` after `apt`.

## What did

Rebuild the GoW userspace image against `$(cat /sys/module/nvidia/version)`.

Copy `/usr/nvidia` out of that image.

Copy those files onto the existing volume's mountpoint. Do not expect a restart to "pick up" a newly built image that never touched the volume.

Confirm `libcuda.so.1` inside the volume, then inside the running container, points at `580.178.04`.

Restart Wolf.

The journal grew `Using h264 encoder: nvcodec` and `Using h265 encoder: nvcodec`. AV1 stayed on `aom`. The P100 has no AV1 NVENC. That is not a second failure.

Leftover `*.so.580.173.02` files are still on the volume. I left them. The symlink is what Wolf follows.

I have not automated this. A missed pour after the next `apt` is how it comes back.

## What I am not claiming

Not "Podman handles NVIDIA better than Docker." Docker users hit the same CUDA mismatch after a host bump. I did not install Docker on this box to compare volume recipes.

Not a latency win. Zero-copy is still off. That is how the stream works on this Tesla.

Not "Wolf was down." The unit was up. The encoder was the wrong one.

## The long version

Procedure, Quadlet, and the two-path table:

https://github.com/Ninnamon12/homelab-notes/blob/main/articles/i-broke-wolf-after-an-nvidia-driver-update.md

---

## Promo post (paste this when you publish the Article)

After an NVIDIA `apt` bump, Wolf still answered Moonlight. The stream died anyway.

`nvidia-driver-vol` still had yesterday's `libcuda`. Restarting the unit remounts that volume. The official first-install helper does not refresh an existing one.

I documented the failure and the pour here:
