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
