# Why I bought a sub-$100 Tesla P100

Cover image: the rack shot (`articles/images/endor-rack.jpg`) or the old-tower shroud (`articles/images/p100-shroud-old-case.jpg`).
Promo post to attach when you publish: at the bottom.

---

I did not buy a Tesla P100 because it is a good 2026 gaming GPU.

I bought one because a used Pascal Tesla under $100 is fully functional as the Wolf / Moonlight card on my homelab. I sat in a session. The stream worked.

That is the whole article. The rest is what “worked” actually meant, and what I am not claiming.

## The receipt

Order date 27 Dec 2025. Delivered 2 Jan 2026.

NVIDIA Tesla P100 16 GB HBM2, part 699-2H400-0201.

$89.97 for the board. $93.77 out the door.

I wanted the cheapest enterprise-grade GPU I could find that still had encoding cores. That was the listing.

## Why I wanted those cores

Homelab GPU shopping usually collapses into three posters:

1. Buy a used 3060 for NVENC and 12 GB.
2. Buy a Tesla P40 because Plex people said so.
3. Use the iGPU and stop thinking about it.

The P100 is none of those. It is a compute card that kept an encode block.

What I wanted, in order:

- A price that did not need a second hobby budget. $89.97. Not “good value at $300.”
- Hardware encode for game streaming. Wolf has to ship frames to Moonlight. CPU encode is the fallback I am trying not to live on.
- A GPU the rest of the lab can still use. Immich ML is CUDA. Ollama is CUDA. Jellyfin can transcode when a client will not direct-play.
- Not a consumer card I had to apologize for. Tesla session policy. ECC HBM2.

What I accepted:

- No monitor ports on the Tesla. Wolf is headless. A GTX 960 on the same tray takes a DisplayPort cable when I want a local picture. That card is not the encode device.
- 250 W-class board. A passive Tesla does not invent airflow.
- Datacenter drivers, CDI for the rootless stack, a named volume of NVIDIA userspace for Wolf.
- Pascal NVENC. Fine for “a stream exists.” Not the card you buy to win an encode-quality thread.
- No AV1.

A P40 is the more obvious media-server Tesla. I did not buy a P40. I bought the cheap card that still had the block Wolf needed.

If your only workload is Jellyfin transcode, do not copy this purchase.

## The lab, in one paragraph

The box is ENDOR. Ubuntu Server. Mostly rootless Podman and Quadlets. Wolf is the exception: a rootful system Quadlet that starts session containers and streams a virtual desktop to Moonlight.

The card is nvidia0 / renderD128.

Immich and Jellyfin can see the same die. I do not watch the library in Jellyfin’s own app. I use Infuse. That is why a Pascal encode block is enough for media here.

## One session, 7 Sep 2026

Halo MCC. Xbox One controller. Moonlight 6.1.0.

The game is a Windows binary running under Proton inside the Steam session container. That matters. Proton is how MCC gets onto a Linux Steam container. It is also how some of the slop gets into the feel. I am not going to blame a $90 P100 for Proton.

Moonlight client settings:

- 1080p / 60
- 30 Mbps
- Borderless windowed
- V-Sync on
- Frame pacing off
- Decoder Automatic
- Codec Automatic
- HDR off

Codec was Automatic. The overlay still said HEVC. I did not force HEVC.

What the overlay showed across a 16.5 second clip:

- 1920×1080, ~60 FPS, HEVC
- Incoming / decode / render ~60 FPS
- Network drops 0.00%. Jitter drops 0.00%.
- Average network latency 1 ms
- Decode ~2.6–3.2 ms
- Render ~2.0–2.4 ms
- Frame queue delay started around 7 ms and climbed toward 14 ms

Host HUD in the same frames: game around 55–61 FPS, GPU memory 3.6 / 16 GB, system RAM about 12 / 30 GB.

nvidia-smi on the host at 14:25 the same afternoon:

- Tesla P100-PCIE-16GB
- 47 °C
- 48 W / 250 W
- 35% GPU-Util
- 3563 MiB / 16384 MiB
- Fan in nvidia-smi: N/A. Passive board. The blower is on a motherboard header.

Biggest process on the card: MCC-Win64-Shipping.exe at 2712 MiB. Then Wolf, wolf-ui, Steam helpers, sway.

Zero-copy is off on this host. That is how the stream works on this card, not how it wins a latency contest.

One title. 1080p60. 30 Mbps asked. HEVC negotiated. 47 °C at 48 W. Proton in the middle.

“It is fast” is the wrong sentence.

“It works” is the sentence.

## Cooling is my problem

A used P100 is a passive heatsink that expected a 2U server to shove air through it. ENDOR is a desktop board on an open tray in a 12U rack. That is not a 2U channel.

What is on the card:

- Custom 3D-printed shroud
- Wathai 97×33 mm 9733 blower, 12 V, 4-pin PWM, dual ball bearing
- PWM on a real motherboard header, not molex-at-full-speed

A system service reads GPU temp from nvidia-smi every ten seconds and writes PWM.

- ≤ 45 °C → PWM 50 (stall floor for this blower)
- 45–50 °C → ramp 50 to 80
- 50–75 °C → ramp 80 to 255
- ≥ 75 °C → 255

Three failed nvidia-smi reads pin the fan at 255 and exit. systemd restarts the unit. If the script dies, the fan goes loud, not off.

47 °C at 48 W / 35% util is one data point from that MCC session. It is not a 250 W torture test.

## What still shares the die

Three consumers. One card. Different wiring.

Wolf sees device nodes plus a named NVIDIA volume plus LD_LIBRARY_PATH.

Immich sees CDI: nvidia.com/gpu=0. Server and ML both get the device. ML is the CUDA image, started with --disable-cuda-graph.

Jellyfin can use the same host GPU. I have not published a transcode capture. Infuse direct-plays most of the library. The P100 is idle for those streams.

I will not flatten that into --gpus=all. Mixing the two NVIDIA stories is how an evening disappears after a driver update.

## Who should buy one

Buy a P100 if:

- You actually have a game-streaming host in mind (Wolf or Sunshine), not just a media folder.
- The used price in front of you is in the “why not” range.
- You will tolerate no outputs, a datacenter driver, and a card that is old in every encode-quality chart.
- Your media clients direct-play most of the library. Transcode is the exception.

Do not buy a P100 if:

- You want the best NVENC you can get in 2026.
- You need AV1.
- You need a monitor out of the same card.
- Your plan is five simultaneous 4K HDR tone-mapped transcodes.
- You think “enterprise” means “easy in Podman.” It does not.

I would not migrate a happy 3060 + Docker + Plex box onto a P100 to chase this article.

## What this is not

Not a bitrate bake-off.

Not proof Pascal NVENC looks like a 40-series.

Not a claim that Immich CUDA on GP100 is fast. The worker is healthy. That is all.

Not native Windows latency. Proton is in the path.

The long version, Quadlets, and the fan script live here:

https://github.com/Ninnamon12/homelab-notes/blob/main/articles/why-i-bought-a-tesla-p100.md

---

## Promo post (paste this when you publish the Article)

I bought a used Tesla P100 for $90 because it was the cheapest enterprise GPU I could find that still had encoding cores.

It streams Halo MCC off my homelab through Wolf / Moonlight at 1080p60 HEVC. Proton is in the path. The card still does the job I bought it for.

Full write-up:
