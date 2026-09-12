# Wolf (rootful system Quadlet)

This is the unit behind [Why I run Wolf on Podman instead of Docker](../../articles/why-i-run-wolf-on-podman.md). The 2026-09-08 volume pour is [I broke Wolf after an NVIDIA driver update](../../articles/i-broke-wolf-after-an-nvidia-driver-update.md).

**Live path on ENDOR:** `/etc/containers/systemd/wolf.container`  
**Not** a user Quadlet. The rest of the lab is mostly rootless. This one is not.

## What was changed for publication

| Live | Published |
| --- | --- |
| Network bind that backs `/etc/wolf` | `${WOLF_CONFIG}:/etc/wolf:z` |
| GPU UUID in Wolf app env | omitted |
| `config.toml` (paired-client certs) | not in this repo |

Device nodes (`renderD128`, `nvidia0`) stay. They are the architecture.

## Deviations from Wolf's documented Quadlet

- Socket mounted `:rw`, not `:ro`
- `nvidia-driver-vol` + `LD_LIBRARY_PATH` to stop host/image library shadowing
- Tesla headless wlroots env; `WOLF_USE_ZERO_COPY=FALSE`
- Health check on TCP 47989 with `Notify=healthy`
- `ExecStartPre` removes leftover `WolfPulseAudio` / `Wolf-UI_*` containers

Do not treat this as upstream. Read [Wolf's current Podman section](https://games-on-whales.github.io/wolf/stable/user/quickstart.html) first.

## After an NVIDIA driver update

Observed on ENDOR 2026-09-08: host module `580.173.02` → `580.178.04`. Wolf stayed up and answered Moonlight. Stream died in `waylanddisplaysrc` (`Failed to create EGLDisplay`, then `PoisonError` / `RecvError`). GStreamer logged `CUDA_ERROR_SYSTEM_DRIVER_MISMATCH` and Wolf selected software `x264`/`x265` instead of `nvcodec`. Cause: `nvidia-driver-vol` still contained `libcuda.so.580.173.02`.

Two GPU stories on this host. Do not mix them.

| Workload | How it sees the P100 | What to refresh |
| --- | --- | --- |
| Wolf (rootful) | named volume `nvidia-driver-vol` at `/usr/nvidia` + `LD_LIBRARY_PATH` | rebuild GoW userspace image, **copy files into the existing volume**, restart `wolf` |
| Immich / Jellyfin / other CDI units | `AddDevice=nvidia.com/gpu=0` | `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`, then restart those units |

### What the Wolf quickstart does not do

Wolf's `nvidia_temp` recipe seeds an **empty** volume on first install. Mounting `nvidia-driver-vol` over `/usr/nvidia` hides the image files. `podman start nvidia_temp` copies nothing onto a volume that already has yesterday's driver. The GoW image is `FROM scratch`; its `/bin/sh` cannot exec (missing glibc), so you cannot use that image as a copy helper.

Other traps from this update:

- Isolated `podman build` cannot resolve Ubuntu mirrors when host `resolv.conf` is AdGuard on `127.0.0.1`. Use `--network=host`.
- Tag `localhost/gow/nvidia-driver:latest`. Rootful Podman will not resolve the short name `gow/nvidia-driver`, and `localhost/...` is treated as a registry pull unless the image is already in the rootful store. Create the extract container by **image ID**.
- Cached build layers from the previous driver version are wrong. Use `--no-cache` after an `apt` bump.
- `systemctl show wolf` may say `LD_LIBRARY_PATH` is empty. That is the *host* unit environment expanding `${LD_LIBRARY_PATH}`. Inside the container the Quadlet still sets `/usr/nvidia/lib:/usr/nvidia/lib32:`.
- `sudo systemctl restart wolf` remounts the same volume. Restart without a file copy does not "pick up" a newly built image.

Do this only after `/sys/module/nvidia/version` is the version you intend to run.

### CDI containers (Immich, etc.)

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

Then restart the units that use `nvidia.com/gpu=0`. That spec is not what Wolf loads.

### Wolf volume (existing `nvidia-driver-vol`)

```bash
curl -fsSL https://raw.githubusercontent.com/games-on-whales/gow/master/images/nvidia-driver/Dockerfile \
  -o /tmp/gow-nvidia-driver.Dockerfile

sudo podman build --network=host --no-cache \
  -t localhost/gow/nvidia-driver:latest \
  -f /tmp/gow-nvidia-driver.Dockerfile \
  --build-arg NV_VERSION="$(cat /sys/module/nvidia/version)" \
  /tmp

IMG="$(sudo podman images -q localhost/gow/nvidia-driver:latest | head -1)"
sudo podman rm -f gow_extract 2>/dev/null || true
rm -rf /tmp/nvidia-usr && mkdir -p /tmp/nvidia-usr
sudo podman create --name gow_extract "$IMG"
sudo podman cp gow_extract:/usr/nvidia/. /tmp/nvidia-usr/
sudo podman rm gow_extract

# confirm the extract is the new module before touching the volume
ls -l /tmp/nvidia-usr/lib/libcuda.so.1 /tmp/nvidia-usr/lib/libcuda.so.580.*

VOL="$(sudo podman volume inspect nvidia-driver-vol -f '{{.Mountpoint}}')"
sudo cp -a /tmp/nvidia-usr/. "$VOL/"
# do not quote a glob here
sudo ls -l "$VOL/lib" | grep libcuda.so
```

`libcuda.so.1` must point at the running module (`cat /sys/module/nvidia/version`). A merge-copy leaves old `*.so.580.PREV` files next to the new ones. That is fine as long as the `.so.1` symlink is current. Then:

```bash
sudo systemctl restart wolf
sudo podman exec wolf sh -c 'ls -l /usr/nvidia/lib/libcuda.so.1 /usr/nvidia/lib/libcuda.so.580.*'
journalctl -u wolf --since "1 min ago" --no-pager | grep -E 'nvcodec|nvh265|nvh264|encoder|mismatch|CUDA|Software h26|Using h26'
```

Healthy on this box after the 580.178.04 bump: `Using h264 encoder: nvcodec` and `Using h265 encoder: nvcodec`. AV1 staying on `aom` is expected — the P100 has no AV1 NVENC. `CUDA_ERROR_SYSTEM_DRIVER_MISMATCH` or `Using h265 encoder: x265` means the volume copy did not land inside the running container.

I have not automated this. A missed rebuild after `apt` is how the "shadowing" failure comes back.
