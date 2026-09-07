# Why I run Wolf on Podman instead of Docker (even though the permissions are worse)

**Status:** draft  
**Lab:** ENDOR  
**Date:** 2026-09-07  
**Scope:** one homelab, one workload — not a generic runtime shoot-out

This is not "Podman vs Docker." That article already exists a few hundred times.

This is why ENDOR runs [Wolf](https://github.com/games-on-whales/wolf) — Moonlight game streaming backed by on-demand session containers — on Podman, what that choice actually bought me, and the permission tax I keep paying for it.

## What ENDOR is, and why Wolf is the test that mattered

ENDOR is an Ubuntu Server homelab running mostly rootless Podman and Quadlets. The interesting hardware is a reused Tesla P100. The interesting workload is Wolf: a host container that stands up per-client virtual desktops and streams them to Moonlight.

Wolf is a bad candidate for a generic container-engine comparison, which is exactly why it is a good one for this lab.

Most "app" containers need a filesystem, a network, and maybe a published port. Wolf needs:

- GPU device nodes and a render node
- `/dev/uinput` and `/dev/uhid` so gamepads exist
- live udev
- a container-runtime socket, because Wolf is not only *a* container — it is a supervisor that starts and stops *other* containers for sessions and audio
- host networking, IPC, and a fairly wide `/dev` surface

That last point is the one generic comparisons skip. Wolf speaks the Docker API. The documented Podman path is not "Podman is a drop-in binary." It is: run `podman.socket`, mount `/run/podman/podman.sock` onto `/var/run/docker.sock` inside the Wolf container, and accept that Wolf will create sibling containers through that socket.

So the runtime choice is an architecture decision, not a CLI preference.

## The claim

**Observed:** for this Wolf/GPU workload, Podman felt lower-level and more responsive than Docker. I also prefer how the rest of the lab shows up in Cockpit.

**Not claimed:** I do not have a side-by-side benchmark. No launch-time numbers, no input-lag captures, no dropped-frame logs, no `podman stats` vs `docker stats` dump from the same session. If I publish those later, they will be labeled as measurements. Until then, "more responsive" is an impression from using the box, not a result.

**Inferred (not measured):** some of that impression is probably not magic performance. It is how close Podman sits to the pieces Wolf already forces you to touch — systemd, device nodes, the runtime socket, Quadlets.

## Where "lower-level" actually shows up

Docker's model is a daemon. You talk to `dockerd`. `dockerd` talks to the rest of the machine.

Podman's model, on a Linux server, is closer to the host's normal service model: a CLI and library talking to an OCI runtime (`crun` on this box unless I have overridden it), with optional socket activation when something like Wolf needs an API, and Quadlet units when I want a container to be a systemd service.

That difference is academic for a `hello-world` container. It is not academic for Wolf.

On Podman I am not wrapping the GPU problem inside a second service I have to reason about. The failure domain is:

1. Does the host see the P100 (`nvidia-smi`, `/dev/nvidia*`, `/dev/dri/renderD*`)?
2. Is `nvidia-drm` modeset on, if the compositor path needs it?
3. Can the Wolf unit see those nodes?
4. Is `podman.socket` up, and does Wolf's mount of that socket actually work?
5. When a Moonlight client connects, does Wolf succeed at creating the session container through that socket?

Those are host questions. Podman does not hide them. Docker does not make the hardware easier either — it just adds `dockerd` as another place the same failure can hide.

"Lower-level" here means: when Wolf breaks, I am already looking at systemd, udev, and device permissions, which is where the bug usually is.

### The socket is the real integration point

Wolf's documented Docker run bind-mounts `/var/run/docker.sock`. The documented Podman Quadlet does the equivalent:

```ini
Volume=/run/podman/podman.sock:/var/run/docker.sock:ro
```

plus `Requires=podman.socket` / `After=podman.socket`.

That single line is the whole compatibility story. Wolf does not need Docker-the-product. It needs a Docker-compatible API next to a lot of host devices.

It is also why "just run Wolf rootless like the rest of the lab" is not free. The rest of ENDOR can stay in a user namespace. Wolf wants `/dev`, udev, uinput, and the ability to spawn containers. The official Quadlet examples live under `/etc/containers/systemd` and talk to the system socket. That is a different trust boundary than a rootless Quadlet in `~/.config/containers/systemd`.

I still call the lab a rootless-Podman homelab. Wolf is the exception I keep having to explain. That exception is part of the article, not a footnote.

## Responsiveness, without pretending I timed it

What I can say honestly:

- Starting and restarting Wolf as a systemd service (Quadlet) feels like managing any other service on the box. There is no separate "is the daemon up?" step in the happy path.
- Under a Wolf session, the machine did not *feel* like it had an extra always-on control plane in the way. That is an impression. Socket-activated `podman.socket` is still a service. I have not measured resident memory of `dockerd` vs `podman.socket` on this host.
- Debugging "why is this session container not starting?" is a `systemctl` / `journalctl` / `podman ps -a` problem. That loop is tight. I will take a tight loop over a friendlier first-run experience.

What I will not say:

- Podman encodes frames faster.
- Podman reduces Moonlight input lag.
- The P100 is "faster on Podman."

The P100 is a reused datacenter GPU. Encode path, render node, and whether an iGPU is doing any of the session work are separate questions. They belong in a Wolf/P100 write-up, not smuggled into a runtime comparison.

If I later capture even rough numbers — time from `systemctl start wolf` to the Web UI answering, time from Moonlight handshake to first frame, journal timestamps around session-container create — I will add them here and mark the date.

## Second win: Cockpit

I manage the box through Cockpit. The container UI I actually want is [cockpit-podman](https://github.com/cockpit-project/cockpit-podman), which talks to Podman's API.

That is the concrete advantage, not "the page is prettier."

- The same engine that runs Quadlets is the engine the browser can list, start, and stop.
- I do not maintain a second mental model for "Cockpit-facing containers" vs "CLI-facing containers."
- When Wolf or a session container looks wedged, I can see it next to the rest of the lab without SSH-first.

Cockpit is not a substitute for `journalctl -u wolf` when GPU passthrough is on fire. It is the everyday control plane. Podman fitting that control plane is worth something on a machine I do not want to babysit from a terminal every time I want to know what is running.

## The honest cost: permissions are worse

Docker's default is simple because it is privileged-by-habit. Rootful Docker plus the NVIDIA Container Toolkit path is a well-lit trail. Wolf's own quickstart is Docker-first for a reason.

Podman makes the permission model visible. Visible is not the same as easy.

On this workload the tax shows up in four places:

**1. Devices are first-class problems.**  
Wolf needs `/dev/dri`, NVIDIA nodes, `/dev/uinput`, `/dev/uhid`, and a writable view of `/dev` and `/run/udev`. Getting the nodes into the container is not "add `--gpus=all` and forget it" if you are on the manual/volume driver path Wolf documents for NVIDIA. Group membership (`video`, `render`, `input`), udev rules, and device cgroup rules all exist whether you use Docker or Podman. Podman will not invent a friendlier version of `/dev/uinput`.

**2. The runtime socket has an owner.**  
`/run/podman/podman.sock` is not `/var/run/docker.sock`. Mounting it read-only into Wolf is easy to type and easy to get wrong. If the socket is down, Wolf cannot spawn session containers. If the socket is the wrong one (user vs system), Wolf talks to an engine that cannot see the devices you think you passed through.

**3. Wolf's data directory is not exempt from mapping rules.**  
`/etc/wolf` has to be writable by whatever UID the container actually runs as. Rootless user-namespace mapping is usually the first time a homelab Docker user meets "the file is there, but it is not *your* file." I have hit that class of problem on Podman more often than I did on Docker. That is not Podman being broken. That is Podman refusing to paper over UID 0.

**4. The lab policy and the Wolf policy disagree.**  
The house style is rootless. Wolf's documented happy path is a system Quadlet with host devices and a system socket. I can pretend those are the same policy. They are not. Every time I copy a pattern from a rootless Quadlet into Wolf, I re-learn that.

I am not going to claim I have a clean rootless Wolf setup worth copying. I do not. The win is operational, not purity.

## What I would tell someone else

If you already run Docker, Wolf is happy, and you do not care about Cockpit-podman or systemd units, do not migrate for the mythology. The generic "Podman is rootless therefore better" pitch is weakest on the exact workload I care about, because Wolf wants host devices and a container API.

If you already standardized on Podman + Quadlets + Cockpit, running Wolf on Docker just to follow the first README example is the worse split. You now have two engines, two logging stories, and a GPU device story that still is not simple.

That is the trade I accepted:

| Keep | Pay |
| --- | --- |
| One engine for the lab | Device and socket permissions you cannot ignore |
| Wolf as a systemd unit | Official examples assume system/rootful more than user/rootless |
| Cockpit talking to the same API | No "it just works" NVIDIA one-liner |
| Failure domain on the host | More time spent on UIDs, groups, and udev |

For ENDOR — GPU-backed Wolf plus Cockpit on a Podman box — that trade is worth it. For a single Docker compose stack on a NAS, it probably is not.

## What this article is not

- A Quadlet you should paste without reading Wolf's current docs. Their NVIDIA devices, render node, and socket path change. Start at the [Wolf quickstart (Podman Quadlets)](https://games-on-whales.github.io/wolf/stable/user/quickstart.html).
- A P100 how-to. That is a later note.
- A security audit of mounting `/dev` into a supervisor container. That surface is large on Docker and Podman.

## Related

- [Wolf / Games on Whales](https://github.com/games-on-whales/wolf)
- [Wolf quickstart](https://games-on-whales.github.io/wolf/stable/user/quickstart.html)
- [cockpit-podman](https://github.com/cockpit-project/cockpit-podman)
- [Podman docs](https://docs.podman.io/)

## Later, if the lab produces the evidence

- Actual start-time / first-frame notes from `journalctl`
- The exact Quadlet ENDOR runs, with the secrets pulled out
- The permission failures I hit, in order, including the ones that did not work
- Whether Wolf on this host is system-Podman, user-Podman, or a hybrid I should stop calling "rootless"
