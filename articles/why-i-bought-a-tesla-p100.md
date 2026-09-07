# Why I bought a sub-$100 Tesla P100

**Status:** draft  
**Lab:** ENDOR  
**Date:** 2026-09-07  
**Scope:** why this card, what the encoders are for, what still shares the die  
**Not:** an NVENC quality bake-off, and not a "best GPU for Plex 2026" list

The buying reason was not subtle. A Tesla P100 was the cheapest enterprise-grade GPU I could find that still had encoding cores, and it was under $100.

I use those cores when I game through Wolf / Moonlight. Immich and Jellyfin can still see the same card. I do not watch Jellyfin through Jellyfin's own client as the daily path — I stream with Infuse. That last sentence is load-bearing. It is why a Pascal encode block is enough for media on this box.

## The claim

**Observed (this lab):** ENDOR runs a Tesla P100 16 GB as `nvidia0` / `/dev/dri/renderD128`. Wolf is the workload that justified the card. Immich (server + CUDA ML image) and Jellyfin are also wired to it. I play the library primarily through Infuse. On 2026-09-07, Immich's machine-learning container was **unhealthy**; "Immich can use the GPU" is not the same sentence as "Immich ML is fine."

**Documented (NVIDIA, not my bench):** the P100 is Pascal GP100. NVIDIA's video encode/decode matrix lists hardware NVENC and NVDEC on it. Encode is Pascal-generation (H.264 and HEVC exist; AV1 does not). Tesla-class cards are not under the consumer NVENC session cap. Launch price was thousands of dollars. Used boards in 2025–2026 commonly sell well under the original MSRP; listings around and under $100 exist. That market is why the card showed up here. It is not a receipt from my purchase.

**Not claimed:** the exact dollar amount I paid, simultaneous encode stream counts, Moonlight bitrate/lag numbers, Jellyfin dashboard proof that a given title hit NVENC, or "P100 encode looks as good as a 30-series." Those need captures. They are not in this file.

**Inferred:** a used GeForce in the same price band would have been the lower-friction gaming card (display outputs, Game Ready driver muscle memory). I paid the Tesla tax on purpose for HBM2, ECC, unrestricted sessions, and a die that is still allowed to do compute and encode on one box.

## Why "cheapest enterprise GPU with encoders" is a real category

Homelab GPU shopping usually collapses into three posters:

1. Buy a used 3060 for NVENC + 12 GB.
2. Buy a Tesla P40 because Plex people said so.
3. Use the iGPU and stop thinking about it.

The P100 is none of those. It is a compute card that happened to keep an encode block.

What I wanted, in order:

1. **A price that did not require a second hobby budget.** Sub-$100 used. Not "good value at $300."
2. **Hardware encode for game streaming.** Wolf is a compositor that has to ship frames to Moonlight. CPU encode on this box is the fallback I am trying not to live on.
3. **Something that is still a GPU for the rest of the lab.** Immich ML is CUDA. Ollama is CUDA. Jellyfin can use NVDEC/NVENC when a client cannot direct-play.
4. **Not a consumer card I had to apologize for.** Tesla session policy, ECC HBM2, no "is this GeForce allowed in a server" argument with myself.

What I accepted in the same decision:

- No monitor ports. Wolf is headless (`WLR_BACKEND=headless`, `WOLF_RENDER_NODE=/dev/dri/renderD128`).
- 250 W TDP class. This is not a 75 W impulse buy.
- Datacenter driver story, CDI for the rootless stack, `nvidia-driver-vol` for Wolf. Documented in the Wolf note and [`configs/wolf/README.md`](../configs/wolf/README.md).
- Pascal NVENC, not Turing/Ampere/Ada. Fine for "a stream exists." Not the card you buy to win an encode quality thread.
- No AV1 encode or decode on this generation.

A P40 is the more obvious "media server Tesla." More of the internet has opinions about P40 + Plex. I did not buy a P40. I bought the card that was cheap *and* still had the block I needed for Wolf. If your only workload is Jellyfin transcode, do not cargo-cult this purchase.

## What the encoders are for on ENDOR

Three consumers. One die. Different APIs.

```text
                    Tesla P100
                    nvidia0 / renderD128
                           |
          +----------------+----------------+
          |                |                |
        Wolf            Jellyfin          Immich
     (NVENC path      (NVENC/NVDEC      (CUDA ML +
      via GStreamer    when a client     optional video
      / nvcodec)       cannot direct      on the same
                       play)              CDI device)
          |                |                |
     Moonlight          Infuse is          photos /
     game clients       the daily           embeddings
                        player
```

### 1. Gaming — this is the reason the card exists

Wolf on ENDOR is a rootful system Quadlet. It starts session containers (Steam is the one that matters) and encodes a virtual desktop to Moonlight.

That encode is why "it has encoding cores" is not a spec-sheet flex. Sunshine/Wolf without a hardware encoder is a different machine. I did not buy 16 GB of HBM2 so Steam would feel premium. I bought a used Tesla because the alternative in that price band was either a weak consumer card or a compute card with the video block stripped.

Lab-specific, already written down elsewhere:

- Zero-copy is **off** (`WOLF_USE_ZERO_COPY=FALSE`). That is how the stream *works* on this card, not how it wins a latency contest. See [Why I run Wolf on Podman](why-i-run-wolf-on-podman.md).
- Other people have hit P100 + Wolf GStreamer negotiation bugs on H.264 while HEVC worked. I am not attaching their logs to my purchase story. If I hit that class of failure, it gets its own note with journal lines.

I do not have start-to-first-frame timings in this repo. "I game on it" is the claim. "It is fast" waits for numbers.

### 2. Jellyfin — present, secondary, Infuse-shaped

Jellyfin is running. The GPU is available to it. I still watch through Infuse.

That pairing changes the hardware argument:

- Infuse's job is to **direct-play** as much as possible on the client. When that works, Jellyfin is a library and a file server. The P100 is idle for that stream.
- Infuse can also *ask* the server for a transcode (remote, thin uplink, a title the client will not swallow). That is when NVENC on the P100 earns its keep for media.
- I am not publishing a transcode matrix from this lab. I have not sat in the Jellyfin dashboard and written down "this 4K HEVC HDR remux became NVENC H.264 at X." Until I do, "Jellyfin can use it" means the device is in the stack and playback has not forced me to rip the card out.

If your household streams five concurrent 4K transcodes through a browser, buy the card the Plex threads tell you to buy. That is not this house.

### 3. Immich — same card, different personality, currently bruised

Immich on ENDOR is a rootless pod. Server and ML both get `AddDevice=nvidia.com/gpu=0`. ML is the CUDA image, started with `--disable-cuda-graph`.

That is compute, not the Wolf encode path. Same physical GPU, different integration:

| Workload | How it sees the P100 |
| --- | --- |
| Wolf | Device nodes + `nvidia-driver-vol` + `LD_LIBRARY_PATH` |
| Immich | CDI (`nvidia.com/gpu=0`) |
| Jellyfin | Same host GPU; unit not published in this repo yet |

I will not flatten those into "`--gpus=all` and pray." Mixing the two NVIDIA stories is how an evening disappears after a driver update.

Snapshot honesty: `immich_machine_learning` was unhealthy on 2026-09-07. So the accurate sentence is: Immich is *attached* to the P100. I have not demonstrated a healthy CUDA ML worker on this card in the published notes. Smart-search / embeddings performance is unmeasured here.

## What "enterprise grade, sub $100" actually bought

Worth keeping:

| Property | Why it mattered on ENDOR |
| --- | --- |
| Used price in the sub-$100 band | The purchase happens. A "better" card I do not buy does not encode anything. |
| Hardware NVENC + NVDEC | Wolf has an encoder. Jellyfin has an off-ramp when Infuse cannot or should not direct-play. |
| Tesla session policy | I am not patching a consumer NVENC limit to run one game stream and a stray transcode. |
| HBM2 + a real CUDA device | Ollama and Immich ML are not afterthoughts bolted onto a 2 GB GT 1030. |
| No display outputs | Forces the honest Wolf setup (headless wlroots) instead of "HDMI dummy plug and a desktop session." |

The bill I keep paying:

| Cost | What it looks like in this repo |
| --- | --- |
| Driver / userspace skew | Rebuild `gow/nvidia-driver` against `/sys/module/nvidia/version`, refill `nvidia-driver-vol`, regenerate `/etc/cdi/nvidia.yaml` |
| Two GPU integration paths | Wolf volume vs Immich CDI |
| Pascal encode generation | No AV1. Do not expect 40-series stills. |
| Power and cooling | 250 W-class card in a server. Not characterized here. |
| Shared-card contention | Not measured. Wolf + a Jellyfin transcode + Immich ML at once is a test I have not published. |
| Unhealthy Immich ML | The "and Immich uses it too" slide currently has an asterisk |

## What I would tell someone else

Buy a P100 if:

- You actually have a game-streaming host in mind (Wolf or Sunshine), not just a media folder.
- The used price in front of you is in the "why not" range, not "I will finance this."
- You will tolerate no outputs, a datacenter driver, and a card that is old in every encode-quality chart.
- Your media clients direct-play most of the library (Infuse, a Shield, a browser on LAN with matching codecs). Transcode is the exception.

Do not buy a P100 if:

- You want the best NVENC you can get in 2026. That is a different generation.
- You need AV1.
- You need a monitor out of the same card.
- Your plan is five simultaneous 4K HDR tone-mapped transcodes. Read the P40 / 3060 / iGPU threads instead of this one.
- You think "enterprise" means "easy in Podman." It does not. See the Wolf permissions note.

I would not migrate a happy 3060 + Docker + Plex box onto a P100 to chase this article.

## What this article is not

- A receipt. I am not publishing the listing I clicked.
- Proof that Pascal NVENC is "good enough" in a screenshot-of-a-tree sense.
- A claim that Immich CUDA ML works on GP100. The unit is there. The worker was unhealthy when I looked.
- A cooling, riser, or "will this fit in my case" guide.
- Permission to ignore the rest of the lab: Wolf is still rootful, zero-copy is still off, driver updates still break the volume.

## Related

- [What ENDOR is](what-endor-is.md)
- [Why I run Wolf on Podman](why-i-run-wolf-on-podman.md)
- [ENDOR Wolf Quadlet](../configs/wolf/wolf.container)
- [After an NVIDIA driver update](../configs/wolf/README.md)
- [NVIDIA video encode/decode support matrix](https://developer.nvidia.com/video-encode-decode-support-matrix)
- [Jellyfin NVIDIA acceleration](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia)
- [Infuse / Jellyfin client spotlight](https://jellyfin.org/posts/client-infuse)

## Later, if the lab produces the evidence

- Purchase date, cooler situation
- `nvidia-smi` during a Moonlight session and during an Infuse-requested Jellyfin transcode
- Whether H.264 or HEVC is what Moonlight actually negotiates here
- Immich ML made healthy, or a postmortem of why it is not
- One screenshot of contention: Wolf + Jellyfin encode on the same die
