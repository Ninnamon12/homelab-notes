# Wolf (rootful system Quadlet)

This is the unit behind [Why I run Wolf on Podman instead of Docker](../../articles/why-i-run-wolf-on-podman.md).

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

The Wolf guide's driver-volume steps are a first-install recipe. They do not stay valid when the host driver changes. `nvidia-driver-vol` still holds the old userspace until you rebuild it against `/sys/module/nvidia/version`.

Do this only after the host NVIDIA driver has been updated and the module is the version you intend to run.

```bash
# CDI spec used by other GPU containers on this host (Immich, etc.)
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# Rebuild the Games-on-Whales driver image against the running module
sudo curl https://raw.githubusercontent.com/games-on-whales/gow/master/images/nvidia-driver/Dockerfile \
  | sudo podman build -t gow/nvidia-driver:latest -f - \
      --build-arg NV_VERSION="$(cat /sys/module/nvidia/version)" .

# Pour the new files into the existing named volume
sudo podman create --name nvidia_temp --rm \
  --mount type=volume,source=nvidia-driver-vol,destination=/usr/nvidia \
  gow/nvidia-driver:latest sh

sudo podman start nvidia_temp
```

Then restart Wolf (`sudo systemctl restart wolf`) and confirm the module version and the volume contents still match. I have not automated this. A missed rebuild after `apt` is how the "shadowing" failure comes back.
