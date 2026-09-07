# Why I run Wolf on Podman instead of Docker (even though the permissions are worse)

**Status:** published  
**Lab:** ENDOR  
**Date:** 2026-09-07  
**Scope:** one homelab, one workload — not a generic runtime shoot-out  
**Unit:** system Quadlet at `/etc/containers/systemd/wolf.container`  
**Sanitized copy:** [`configs/wolf/wolf.container`](../configs/wolf/wolf.container)

This is not "Podman vs Docker." That article already exists a few hundred times.

This is why ENDOR runs [Wolf](https://github.com/games-on-whales/wolf) — Moonlight game streaming backed by on-demand session containers — on Podman, what that choice actually bought me, and the permission tax I keep paying for it.

## What ENDOR is, and why Wolf is the test that mattered

ENDOR is an Ubuntu Server homelab. Most of the stack is rootless Podman and user Quadlets. Wolf is not. The lab snapshot is in [What ENDOR is](what-endor-is.md).

The interesting hardware is a reused Tesla P100 (`nvidia0`, `/dev/dri/renderD128`). Why that card exists is a separate note: [Why I bought a sub-$100 Tesla P100](why-i-bought-a-tesla-p100.md). The interesting workload is Wolf: one host container that stands up per-client virtual desktops and streams them to Moonlight. On this box the first app that matters is Steam, started by Wolf as another container (`type = "docker"` in Wolf's config) from `ghcr.io/games-on-whales/steam:master`.

Wolf is a bad candidate for a generic container-engine comparison, which is exactly why it is a good one for this lab.

Most "app" containers need a filesystem, a network, and maybe a published port. Wolf needs:

- GPU device nodes and a render node
- `/dev/uinput` and `/dev/uhid` so gamepads exist
- live udev
- a container-runtime socket, because Wolf is not only *a* container — it is a supervisor that starts and stops *other* containers for sessions, Wolf UI, and audio
- host networking, IPC, and a fairly wide `/dev` surface

That last point is the one generic comparisons skip. Wolf speaks the Docker API. The documented Podman path is not "Podman is a drop-in binary." It is: run `podman.socket`, mount `/run/podman/podman.sock` onto `/var/run/docker.sock` inside the Wolf container, and accept that Wolf will create sibling containers through that socket.

So the runtime choice is an architecture decision, not a CLI preference.

## The claim

I run Wolf on Podman because the rest of ENDOR is already Podman, Quadlets, systemd, and Cockpit. Wolf does not need Docker-the-product. It needs a Docker-compatible API next to a lot of host devices. Putting that API on a second engine would split the lab for a README example.

**Observed on this box:**

- Wolf is a system Quadlet (`wolf.service`), not a user Quadlet and not a compose stack.
- Restart is `systemctl restart wolf`. Crash leftovers are an `ExecStartPre` problem. Liveness is a health check on TCP 47989.
- After an NVIDIA host-driver bump, the named volume `nvidia-driver-vol` goes stale until I rebuild it against `/sys/module/nvidia/version`.

**Not claimed:** Podman encodes frames faster, reduces Moonlight input lag, or makes the P100 "snappier" than Docker. I do not have a side-by-side on this host. Stream feel is dominated by the card, the network, and `WOLF_USE_ZERO_COPY=FALSE`, not by which process created the session container. I am not installing Docker on ENDOR to manufacture that number.

**Inferred:** "lower-level" is how close the failure domain sits to systemd, udev, and device nodes — which is where Wolf actually breaks.

## Where that shows up

Docker's model is a daemon. You talk to `dockerd`. `dockerd` talks to the rest of the machine.

Podman's model on this server is the host's normal service model: a Quadlet unit, `podman.socket`, an OCI runtime, and `journalctl`. Wolf is `wolf.service`. When it wedges, systemd restarts it. When a previous run leaves `WolfPulseAudio` or a `Wolf-UI_*` container behind, an `ExecStartPre` tears those names down before the new unit starts.

That difference is academic for a `hello-world` container. It is not academic for Wolf.

The failure domain on ENDOR is:

1. Does the host see the P100 (`nvidia-smi`, `/dev/nvidia0`, `/dev/dri/renderD128`)?
2. Can the Wolf unit see those nodes, plus `/dev/uinput`, `/dev/uhid`, and udev?
3. Is `podman.socket` up, and does Wolf's mount of that socket actually work?
4. When a Moonlight client connects, does Wolf succeed at creating the Steam session container through that socket?
5. Did the last crash leave a helper container that will collide on the next start?

Those are host questions. Podman does not hide them. Docker does not make the hardware easier either — it just adds `dockerd` as another place the same failure can hide.

### Wolf is a system Quadlet, not a rootless one

The unit lives in `/etc/containers/systemd/wolf.container`. It requires the system `podman.socket`. That is the same layout Wolf's own docs use, and it is a different trust boundary from the user Quadlets that run the rest of the lab.

I still call ENDOR a rootless-Podman homelab. Wolf is the exception I keep having to explain. That exception is part of the article, not a footnote.

### The socket is the real integration point

Wolf's documented Docker run bind-mounts `/var/run/docker.sock`. The Quadlet on ENDOR does this:

```ini
Requires=network-online.target podman.socket
After=network-online.target podman.socket
Volume=/run/podman/podman.sock:/var/run/docker.sock:rw
```

Two details that are easy to copy wrong:

- Official Wolf examples often mount the socket `:ro`. Mine is `:rw`. Wolf has to create containers. A read-only socket is a polite way to get a supervisor that cannot supervise.
- The socket has to be the *system* socket. A user-namespace socket cannot see the devices this unit passes through.

### The P100 is not a GeForce

This card has no monitor ports. Local picture on the box, when I need one, comes from a GTX 960 on the same tray (DisplayPort cable in the [rack photo](what-endor-is.md)). That GeForce is not the Wolf encode device. The buying reason and the encode-block caveat are in [the P100 note](why-i-bought-a-tesla-p100.md). The Wolf unit does not pretend the Tesla has an HDMI jack:

```ini
Environment=WLR_BACKEND=headless
Environment=WLR_RENDERER=gles2
Environment=WLR_NO_HARDWARE_CURSORS=1
Environment=WOLF_RENDER_NODE=/dev/dri/renderD128
Environment=WOLF_USE_ZERO_COPY=FALSE
```

NVIDIA libraries come from a named volume, `nvidia-driver-vol`, mounted at `/usr/nvidia`, with `LD_LIBRARY_PATH` pointed at that volume first. That exists because the container image and the host driver like to step on each other. I have already hit that class of failure; the comment in the unit still says "Phase 2 Shadowing."

Zero-copy is off on purpose. It made the stream *work* on this card. It is not a latency flex.

A health check hits Moonlight's control port (`47989`). If Wolf is up as a container but dead as a streamer, systemd kills it. That is Quadlet/`Notify=healthy` doing work I would otherwise put in a wrapper script.

### The official driver-volume path goes stale on every host driver bump

Wolf's NVIDIA manual path is: build `gow/nvidia-driver` against the host driver version, pour those files into `nvidia-driver-vol`, mount the volume at `/usr/nvidia`. That works until the next `apt upgrade` of the NVIDIA driver. Then the volume still contains *yesterday's* userspace, the host kernel module is *today's*, and Wolf fails in ways that look like GPU passthrough, encoding, or "shadowing" depending on which library loaded first.

The Wolf quickstart is not wrong about the first install. It is incomplete as an operations note. On ENDOR the host driver version is the source of truth (`/sys/module/nvidia/version`). After a driver update I rebuild the image from that version, repopulate the same named volume, and regenerate the CDI spec the rest of the lab uses. Commands live next to the unit: [`configs/wolf/README.md`](../configs/wolf/README.md).

This is not a Podman-vs-Docker difference. Docker hits the same volume/driver skew. Podman made it visible because the Quadlet names the volume and the `LD_LIBRARY_PATH` instead of hiding it behind `--gpus=all`.

## What "responsive" meant, without a stopwatch

Not frame time. The loop I actually use:

- Start and restart are `systemctl restart wolf`. There is no separate "is the daemon up?" step in the happy path.
- Leftover session containers are a known failure mode. The unit deletes them before start.
- Debugging "why is this session container not starting?" is `systemctl` / `journalctl -u wolf` / `podman ps -a`.

If I later time `systemctl start wolf` until port 47989 answers, that number belongs here and will be dated. It still would not be a Docker comparison.

## Cockpit

I manage the box through Cockpit. The container UI I actually want is [cockpit-podman](https://github.com/cockpit-project/cockpit-podman), which talks to Podman's API.

- The same engine that runs the Wolf Quadlet is the engine the browser can list.
- Wolf, Wolf UI, and the Steam session container show up as siblings. They *are* siblings.
- When a session looks wedged, I can see it next to the rest of the lab without SSH-first.

Cockpit is not a substitute for `journalctl -u wolf` when GPU passthrough is on fire. It is the everyday control plane.

## The honest cost: permissions are worse

Docker's default is simple because it is privileged-by-habit. Rootful Docker plus the NVIDIA Container Toolkit path is a well-lit trail. Wolf's own quickstart is Docker-first for a reason.

Podman makes the permission model visible. Visible is not the same as easy.

**1. Devices are first-class problems.**  
The unit adds `/dev/dri`, `/dev/uinput`, `/dev/uhid`, and the P100 NVIDIA nodes one by one, then also bind-mounts `/dev` and `/run/udev` read-write so controllers can appear after start. Device cgroup rule `c 13:* rmw` is in `PodmanArgs`. Wolf's Steam app repeats the pattern and adds `c 244:* rmw`, plus `/dev/input` as a volume. None of that is a Podman-vs-Docker feature. All of it is easy to get half-right.

**2. The runtime socket is writable on purpose.**  
`:rw` on `podman.sock` is a privilege decision. So is `SecurityLabelDisable=true`. So is `Network=host` and `--ipc=host`. I am not running a locked-down workload. I am running a compositor supervisor that creates other containers.

**3. Config lives outside the unit, and UIDs still matter.**  
`/etc/wolf` is a bind mount from networked storage, with `:z` left on the volume even though this host is not using SELinux in anger. Paired Moonlight clients in Wolf's config run as UID/GID 1000. The Steam runner is `Privileged=false` and then walks it back with `SYS_ADMIN`, `NET_ADMIN`, `MKNOD`, `seccomp=unconfined`, and `apparmor=unconfined`. "Not privileged" is not the same as "simple permissions."

**4. Child containers outlive the unit.**  
Wolf UI and Pulse helpers persist as real Podman containers. After a crash they occupy names. The Quadlet has an `ExecStartPre` that force-removes `WolfPulseAudio` and anything matching `Wolf-UI_`. That line exists because I have already needed it.

**5. The lab policy and the Wolf policy disagree.**  
House style is rootless user Quadlets. Wolf is a rootful system Quadlet with host devices and a system socket. Copying a pattern from Immich into Wolf, or the other way around, is how I waste an evening.

I am not going to claim I have a clean rootless Wolf setup worth copying. I do not. The win is one engine and one service model, not purity.

## What I would tell someone else

If you already run Docker, Wolf is happy, and you do not care about Cockpit-podman or systemd units, do not migrate for the mythology. The generic "Podman is rootless therefore better" pitch is weakest on the exact workload I care about, because Wolf wants host devices and a container API.

If you already standardized on Podman + Quadlets + Cockpit, running Wolf on Docker just to follow the first README example is the worse split. You now have two engines, two logging stories, and a GPU device story that still is not simple.

That is the trade I accepted:

| Keep | Pay |
| --- | --- |
| One engine for the lab | Device and socket permissions you cannot ignore |
| Wolf as `wolf.service` | This unit is system/rootful; the rest of the lab is not |
| Cockpit talking to the same API | No "it just works" NVIDIA one-liner |
| systemd health + crash cleanup | More time spent on UIDs, groups, udev, leftover names, and driver-volume rebuilds |

For ENDOR — a Tesla P100, Wolf, Steam-as-a-child-container, and Cockpit on a Podman box — that trade is worth it. For a single Docker compose stack on a NAS, it probably is not.

## What this article is not

- A Quadlet you should paste blindly. Start at the [Wolf quickstart (Podman Quadlets)](https://games-on-whales.github.io/wolf/stable/user/quickstart.html), then look at the [sanitized unit from ENDOR](../configs/wolf/wolf.container) for the deviations (socket `:rw`, Tesla headless env, driver volume, health check, leftover-container cleanup).
- A P100 encode guide. That is [the P100 note](why-i-bought-a-tesla-p100.md).
- A Docker vs Podman benchmark. I did not install a second engine to produce one.
- A security audit of mounting `/dev` into a supervisor container. That surface is large on Docker and Podman.
- My live `config.toml`. That file has client certificates in it. It stays off this repo.

## Related

- [What ENDOR is](what-endor-is.md)
- [Why I bought a sub-$100 Tesla P100](why-i-bought-a-tesla-p100.md)
- [Wolf / Games on Whales](https://github.com/games-on-whales/wolf)
- [Wolf quickstart](https://games-on-whales.github.io/wolf/stable/user/quickstart.html)
- [cockpit-podman](https://github.com/cockpit-project/cockpit-podman)
- [Podman docs](https://docs.podman.io/)
- [ENDOR Wolf Quadlet (sanitized)](../configs/wolf/wolf.container)
- [After an NVIDIA driver update](../configs/wolf/README.md)

## Later, if the lab produces the evidence

- Time from `systemctl start wolf` to port 47989 answering
- A dedicated postmortem of one driver-update failure (logs, not just the rebuild commands)
- Whether I ever bother making Wolf rootless, or stop calling the whole lab that
