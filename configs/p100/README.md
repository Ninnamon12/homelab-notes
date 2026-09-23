# P100 blower control on ENDOR

Supports [Why I bought a sub-$100 Tesla P100](../../articles/why-i-bought-a-tesla-p100.md).

The Tesla is passive. Air comes from a 3D-printed shroud and a Wathai 9733 PWM blower on a motherboard header. This unit maps `nvidia-smi` GPU temp onto that header.

A GTX 960 shares the top tray and is for occasional local DisplayPort output only. Fan control here is `GPU_ID=0` (the P100). Do not point this script at the 960.

**Live paths**

- `/usr/local/bin/p100-fan-control.sh`
- `/etc/systemd/system/p100-fan-control.service`

`hwmon1/pwm3` is the header this board actually uses. It will not be the same number on your board.

Curve as of 2026-09-23 (quiet-biased; integer PWM):

| GPU temp | PWM |
| --- | --- |
| ≤ 48 °C | 50 (stall floor) |
| 48–65 °C | ramp 50 → 85 |
| 65–80 °C | ramp 85 → 255 |
| ≥ 78 °C | 255 (hard pin, skips the last interpolated steps) |

Slew is 15 PWM per 10 s loop so a load spike does not jump 62 → 143 in one write. Three failed `nvidia-smi` reads set the fan to 255 and exit; systemd restarts the unit. SIGINT/SIGTERM do **not** pin 255 — `Restart=always` made that a full-blast blip on every restart. `systemctl stop` leaves the header at last duty in manual mode.

The previous curve (45 → 50, 50 → 80, 75 → 255) held ~63 °C at PWM 171 under a 220 W Ollama generate. That was louder than the P100's 80 °C max-operating / 82 °C slowdown margin was worth.

`After=network.target` is what is on disk. The script needs the NVIDIA module and `nvidia-smi`, not a network. I have not rewritten the unit to wait on the driver.
