#!/bin/bash
# ENDOR: map Tesla P100 temp from nvidia-smi onto a motherboard PWM header.
# Live path: /usr/local/bin/p100-fan-control.sh
# Driven by /etc/systemd/system/p100-fan-control.service
#
# PWM path is THIS board's hwmon. Copying the numbers without checking
# /sys/class/hwmon is how you spin the wrong fan.

PWM="/sys/class/hwmon/hwmon1/pwm3"
PWM_ENABLE="${PWM}_enable"
GPU_ID=0

MIN_TEMP=45
QUIET_TEMP=50
MAX_TEMP=75

MIN_PWM=50     # blower stall floor
QUIET_PWM=80
MAX_PWM=255
ERROR_COUNT=0

cleanup() {
    echo "Script exiting. Setting fan to MAX for safety..."
    echo 255 > "$PWM"
    exit
}
trap cleanup SIGINT SIGTERM

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
    elif [ "$TEMP" -le "$QUIET_TEMP" ]; then
        PWM_VAL=$(( MIN_PWM + (TEMP - MIN_TEMP) * (QUIET_PWM - MIN_PWM) / (QUIET_TEMP - MIN_TEMP) ))
    elif [ "$TEMP" -ge "$MAX_TEMP" ]; then
        PWM_VAL=$MAX_PWM
    else
        PWM_VAL=$(( QUIET_PWM + (TEMP - QUIET_TEMP) * (MAX_PWM - QUIET_PWM) / (MAX_TEMP - QUIET_TEMP) ))
    fi

    echo "$PWM_VAL" > "$PWM"

    echo "$(date): Temp=${TEMP}C -> PWM=${PWM_VAL}"

    sleep 10
done
