#!/bin/bash
# ENDOR: map Tesla P100 temp from nvidia-smi onto a motherboard PWM header.
# Live path: /usr/local/bin/p100-fan-control.sh
# Driven by /etc/systemd/system/p100-fan-control.service
#
# PWM path is THIS board's hwmon. Copying the numbers without checking
# /sys/class/hwmon is how you spin the wrong fan.
#
# Curve is quiet-biased. P100 PCIe max operating is 80 C, slowdown 82 C,
# shutdown 85 C. Holding 62 C at ~220 W with PWM 171 was louder than the
# margin was worth. Cruise is allowed to walk into the high 60s / low 70s.

PWM="/sys/class/hwmon/hwmon1/pwm3"
PWM_ENABLE="${PWM}_enable"
GPU_ID=0

# --- Config ---
MIN_TEMP=48
QUIET_TEMP=65
MAX_TEMP=80
HARD_TEMP=78          # skip the last interpolated steps; pin 255

MIN_PWM=50            # blower stall floor
QUIET_PWM=85
MAX_PWM=255
MAX_STEP=15           # PWM units per 10 s loop; kills the 62 -> 143 jump

ERROR_COUNT=0
LAST_PWM=""
LOG_CYCLE=0

# Restart=always SIGTERMs this process and starts a new copy in RestartSec.
# Do not blast 255 here — that was the loud blip on every restart.
# Three failed nvidia-smi reads still pin 255 before exit.
# systemctl stop leaves the header at last duty in manual mode.
cleanup() {
    exit
}
trap cleanup SIGINT SIGTERM

# Set manual control
echo 1 > "$PWM_ENABLE"

echo "P100 fan control active for GPU $GPU_ID..."

while true; do
    TEMP=$(nvidia-smi -i $GPU_ID --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)

    if ! [[ "$TEMP" =~ ^[0-9]+$ ]]; then
        ((ERROR_COUNT++))
        echo "Error reading temperature ($ERROR_COUNT/3)..."

        if [ "$ERROR_COUNT" -ge 3 ]; then
            echo 255 > "$PWM"
            echo "Critical Error: Cannot read GPU temp. Fan set to 100%."
            exit 1
        fi
        sleep 5
        continue
    fi

    ERROR_COUNT=0

    if [ "$TEMP" -le "$MIN_TEMP" ]; then
        PWM_VAL=$MIN_PWM
    elif [ "$TEMP" -ge "$HARD_TEMP" ]; then
        PWM_VAL=$MAX_PWM
    elif [ "$TEMP" -le "$QUIET_TEMP" ]; then
        PWM_VAL=$(( MIN_PWM + (TEMP - MIN_TEMP) * (QUIET_PWM - MIN_PWM) / (QUIET_TEMP - MIN_TEMP) ))
    elif [ "$TEMP" -ge "$MAX_TEMP" ]; then
        PWM_VAL=$MAX_PWM
    else
        PWM_VAL=$(( QUIET_PWM + (TEMP - QUIET_TEMP) * (MAX_PWM - QUIET_PWM) / (MAX_TEMP - QUIET_TEMP) ))
    fi

    if [ "$PWM_VAL" -lt "$MIN_PWM" ]; then
        PWM_VAL=$MIN_PWM
    elif [ "$PWM_VAL" -gt "$MAX_PWM" ]; then
        PWM_VAL=$MAX_PWM
    fi

    if [ -n "$LAST_PWM" ]; then
        DELTA=$(( PWM_VAL - LAST_PWM ))
        if [ "$DELTA" -gt "$MAX_STEP" ]; then
            PWM_VAL=$(( LAST_PWM + MAX_STEP ))
        elif [ "$DELTA" -lt "-$MAX_STEP" ]; then
            PWM_VAL=$(( LAST_PWM - MAX_STEP ))
        fi
    fi

    echo "$PWM_VAL" > "$PWM"

    ((LOG_CYCLE++))
    if [ "$PWM_VAL" != "$LAST_PWM" ] || [ "$LOG_CYCLE" -ge 6 ]; then
        echo "$(date): Temp=${TEMP}°C -> PWM=${PWM_VAL}"
        LOG_CYCLE=0
    fi

    LAST_PWM=$PWM_VAL
    sleep 10
done
