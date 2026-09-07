# Why I bought a sub-$100 Tesla P100

**Status:** draft  
**Lab:** ENDOR  
**Date:** 2026-09-07  
**Scope:** why this card, what the encoders are for, how it is cooled  
**Not:** an NVENC quality bake-off, and not a "best GPU for Plex 2026" list

I bought a Tesla P100 16 GB because it was the cheapest enterprise-grade GPU I could find that still had encoding cores, and it was under $100.

Order date 2025-12-27. Delivered 2026-01-02. Listing: NVIDIA Tesla P100 16 GB HBM2, part `699-2H400-0201`. **$89.97** for the board, **$93.77** out the door. Name, address, order ID, and tracking stay off this repo.

Those cores exist for Wolf / Moonlight. Immich and Jellyfin can still see the same die. I do not watch the library in Jellyfin's own app. I use Infuse. That is why a Pascal encode block is enough for media here.

The lab around the card is in [What ENDOR is](what-endor-is.md). The runtime tax is in [Why I run Wolf on Podman](why-i-run-wolf-on-podman.md).

## The claim

**Observed:** ENDOR runs a Tesla P100 16 GB as `nvidia0` / `/dev/dri/renderD128`. Wolf is why the card is in the tray. Immich (server + CUDA ML) and Jellyfin are wired to it. Infuse is the daily player. `immich_machine_learning` is healthy as of later 2026-09-07. Healthy means the HealthCmd answers. It does not mean I measured embeddings.

**Documented (NVIDIA, not my bench):** Pascal GP100. Hardware NVENC and NVDEC. H.264 and HEVC exist; AV1 does not. Tesla-class cards are not under the consumer NVENC session cap.

**Not claimed:** Moonlight lag numbers, simultaneous stream counts, a Jellyfin dashboard capture, or "this looks like a 30-series." Those need screenshots. They are not in this file.

**Inferred:** a used GeForce in the same price band would have been the easier gaming card. Display outputs. Game Ready muscle memory. I paid the Tesla tax for HBM2, ECC, unrestricted sessions, and one die that is allowed to do compute and encode on the same box.

## Why this category exists

Homelab GPU shopping usually collapses into three posters:

1. Buy a used 3060 for NVENC + 12 GB.
2. Buy a Tesla P40 because Plex people said so.
3. Use the iGPU and stop thinking about it.

The P100 is none of those. It is a compute card that kept an encode block.

What I wanted, in order:

1. **A price that did not need a second hobby budget.** $89.97. Not "good value at $300."
2. **Hardware encode for game streaming.** Wolf has to ship frames to Moonlight. CPU encode is the fallback I am trying not to live on.
3. **A GPU the rest of the lab can still use.** Immich ML is CUDA. Ollama is CUDA. Jellyfin can transcode when a client will not direct-play.
4. **Not a consumer card I had to apologize for.** Tesla session policy. ECC HBM2. No "is this GeForce allowed in a server" argument with myself.

What I accepted:

- No monitor ports. Wolf is headless (`WLR_BACKEND=headless`, `WOLF_RENDER_NODE=/dev/dri/renderD128`).
- 250 W-class card. Not a 75 W impulse buy. A passive Tesla does not invent airflow. See cooling below.
- Datacenter driver story. CDI for the rootless stack. `nvidia-driver-vol` for Wolf.
- Pascal NVENC. Fine for "a stream exists." Not the card you buy to win an encode-quality thread.
- No AV1.

A P40 is the more obvious media-server Tesla. I did not buy a P40. I bought the cheap card that still had the block Wolf needed. If your only workload is Jellyfin transcode, do not copy this purchase.

## What the encoders are for

Three consumers. One die. Different APIs.

```text
                    Tesla P100
                    nvidia0 / renderD128
                           |
          +----------------+----------------+
          |                |                |
        Wolf            Jellyfin          Immich
     (NVENC via         (NVENC/NVDEC      (CUDA ML +
      GStreamer /        when a client     optional video
      nvcodec)           cannot             on the same
                         direct-play)       CDI device)
          |                |                |
     Moonlight          Infuse is          photos /
     clients            the daily           embeddings
                        player
```

### Gaming is why the card exists

Wolf is a rootful system Quadlet. It starts session containers -- Steam is the one that matters -- and encodes a virtual desktop to Moonlight.

That encode is the purchase. Sunshine or Wolf without a hardware encoder is a different machine. I did not buy 16 GB of HBM2 so Steam would feel premium. I bought a used Tesla because the alternative in that price band was a weak consumer card or a compute card with the video block stripped.

Already written down elsewhere:

- Zero-copy is **off** (`WOLF_USE_ZERO_COPY=FALSE`). That is how the stream works on this card, not how it wins a latency contest.
- Other people have hit P100 + Wolf GStreamer bugs on H.264 while HEVC worked. Those are their logs. If I hit that class of failure, it gets its own note.

"I game on it" is the claim. "It is fast" waits for numbers.

### Jellyfin is secondary and Infuse-shaped

Jellyfin is running. The GPU is available to it. I still watch through Infuse.

- Infuse direct-plays when it can. Then Jellyfin is a library and a file server. The P100 is idle for that stream.
- Infuse can ask the server to transcode. That is when NVENC on this card earns its keep for media.
- I have not sat in the Jellyfin dashboard and written down "this title became NVENC H.264 at X." Until I do, "Jellyfin can use it" means the device is in the stack.

Five concurrent 4K browser transcodes is a different house. Buy what the Plex threads tell that house to buy.

### Immich is compute, not the Wolf path

Immich is a rootless pod. Server and ML both get `AddDevice=nvidia.com/gpu=0`. ML is the CUDA image, started with `--disable-cuda-graph`.

| Workload | How it sees the P100 |
| --- | --- |
| Wolf | Device nodes + `nvidia-driver-vol` + `LD_LIBRARY_PATH` |
| Immich | CDI (`nvidia.com/gpu=0`) |
| Jellyfin | Same host GPU; unit not in this repo yet |

I will not flatten that into `--gpus=all`. Mixing the two NVIDIA stories is how an evening disappears after a driver update.

`immich_machine_learning` was unhealthy on the morning snapshot. A nested `python -c` HealthCmd that had been fine on Podman 4.9.3 died on Podman 5.7.0 with an unterminated quote. JSON exec form against `/ping` made it healthy. That is systemd liveness. Embeddings on GP100 are still unmeasured. The quoting story belongs with the Immich units, not as proof the P100 is a good ML card.

## Cooling

A used P100 is a passive heatsink that expected a 2U server to shove air through it. ENDOR is a desktop board on an open tray in a 12U rack. That is not a 2U channel.

What is on the card:

- Custom 3D-printed shroud
- Wathai 97x33 mm 9733 blower, 12 V, 4-pin PWM, dual ball bearing, centrifugal
- PWM on a real motherboard header, not molex-at-full-speed

The close-up is the **old tower**. Same shroud idea, different box. That photo also shows an ASUS Strix under the P100 and a Corsair RM-series PSU. The Strix is not in the current GPU inventory. The rack shot is current: open tray at the top, UDM-Pro and USW-16-PoE in the middle, disks lower.

![P100 with printed shroud and Wathai blower in the old tower](images/p100-shroud-old-case.jpg)

![ENDOR current 12U rack](images/endor-rack.jpg)

The blower is not left at 12 V. A system service reads GPU temp from `nvidia-smi` every ten seconds and writes PWM. Live paths: `/usr/local/bin/p100-fan-control.sh` and `/etc/systemd/system/p100-fan-control.service`. Copies: [`configs/p100/`](../configs/p100/).

| GPU temp | PWM |
| --- | --- |
| <= 45 C | 50 (stall floor for this blower) |
| 45-50 C | ramp 50 to 80 |
| 50-75 C | ramp 80 to 255 |
| >= 75 C | 255 |

On this board the header is `hwmon1/pwm3`. That path is not portable. Three failed `nvidia-smi` reads pin the fan at 255 and exit. systemd restarts the unit. SIGINT/SIGTERM also pin 255.

`After=network.target` is what is on the unit. The script needs the NVIDIA module, not a default route. I have not cleaned that up.

I am not publishing a Wolf-session temp log. The claim is closed-loop on die temp, with a loud failure mode instead of an off fan.

## What that purchase actually bought

Worth keeping:

| Property | Why it mattered |
| --- | --- |
| Used price under $100 | $89.97 / $93.77 on 2025-12-27. A better card I do not buy encodes nothing. |
| Hardware NVENC + NVDEC | Wolf has an encoder. Jellyfin has an off-ramp when Infuse cannot direct-play. |
| Tesla session policy | I am not patching a consumer NVENC limit for one game stream and a stray transcode. |
| HBM2 + a real CUDA device | Ollama and Immich ML are not bolted onto a 2 GB GT 1030. |
| No display outputs | Forces the honest Wolf setup instead of an HDMI dummy plug. |

The bill I keep paying:

| Cost | What it looks like here |
| --- | --- |
| Driver / userspace skew | Rebuild `gow/nvidia-driver` against `/sys/module/nvidia/version`, refill `nvidia-driver-vol`, regenerate `/etc/cdi/nvidia.yaml` |
| Two GPU integration paths | Wolf volume vs Immich CDI |
| Pascal encode | No AV1 |
| Cooling is my problem | Printed shroud + Wathai + a host unit |
| Shared-card contention | Not measured |

## What I would tell someone else

Buy a P100 if:

- You actually have a game-streaming host in mind (Wolf or Sunshine), not just a media folder.
- The used price in front of you is in the "why not" range.
- You will tolerate no outputs, a datacenter driver, and a card that is old in every encode-quality chart.
- Your media clients direct-play most of the library. Transcode is the exception.

Do not buy a P100 if:

- You want the best NVENC you can get in 2026.
- You need AV1.
- You need a monitor out of the same card.
- Your plan is five simultaneous 4K HDR tone-mapped transcodes.
- You think "enterprise" means "easy in Podman." It does not.

I would not migrate a happy 3060 + Docker + Plex box onto a P100 to chase this article.

## Related

- [What ENDOR is](what-endor-is.md)
- [Why I run Wolf on Podman](why-i-run-wolf-on-podman.md)
- [ENDOR Wolf Quadlet](../configs/wolf/wolf.container)
- [After an NVIDIA driver update](../configs/wolf/README.md)
- [Immich on ENDOR](../configs/immich/)
- [P100 blower service](../configs/p100/)
- [NVIDIA video encode/decode support matrix](https://developer.nvidia.com/video-encode-decode-support-matrix)

## Later, if the lab produces the evidence

- `nvidia-smi` during a Moonlight session and during an Infuse-requested Jellyfin transcode
- Whether H.264 or HEVC is what Moonlight actually negotiates here
- One shot of contention: Wolf + Jellyfin encode on the same die
- Immich embedding throughput on this card
