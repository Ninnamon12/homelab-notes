# P100 blower control on ENDOR

Supports [Why I bought a sub-$100 Tesla P100](../../articles/why-i-bought-a-tesla-p100.md).

The Tesla is passive. Air comes from a 3D-printed shroud and a Wathai 9733 PWM blower on a motherboard header. This unit maps `nvidia-smi` GPU temp onto that header.

A GTX 960 shares the top tray and is for occasional local DisplayPort output only. Fan control here is `GPU_ID=0` (the P100). Do not point this script at the 960.

**Live paths**

- `/usr/local/bin/p100-fan-control.sh`
- `/etc/systemd/system/p100-fan-control.service`

`hwmon1/pwm3` is the header this board actually uses. It will not be the same number on your board.

Curve as deployed: 45 C -> PWM 50, 50 C -> 80, 75 C -> 255. Floor is 50 because the blower stalls below that. Three failed `nvidia-smi` reads set the fan to 255 and exit; systemd restarts the unit. SIGINT/SIGTERM also pin the fan at 255.

`After=network.target` is what is on disk. The script needs the NVIDIA module and `nvidia-smi`, not a network. I have not rewritten the unit to wait on the driver.
