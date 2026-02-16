#!/usr/bin/env bash

# Monitor the EC registers that changed during keyboard attach/detach.
# Run with: sudo bash ec-keyboard-monitor2.sh

set -e

if [[ ! -f /sys/kernel/debug/ec/ec0/io ]]; then
    modprobe ec_sys write_support=1
fi

EC_IO="/sys/kernel/debug/ec/ec0/io"

read_ec() {
    local offset=$1
    dd if="$EC_IO" bs=1 skip="$offset" count=1 2>/dev/null | od -An -tu1 | tr -dc '0-9'
}

echo "Monitoring EC registers 0x27, 0x49, 0xC1 (keyboard detection)"
echo "Attach and detach the keyboard to verify changes."
echo "---"

PREV=""

while true; do
    v27=$(read_ec 39)   # 0x27
    v49=$(read_ec 73)   # 0x49
    vC1=$(read_ec 193)  # 0xC1

    h27=$(printf "%02x" "$v27")
    h49=$(printf "%02x" "$v49")
    hC1=$(printf "%02x" "$vC1")

    # Bit 7 of 0xC1 seems like the cleanest signal
    c1_bit7=$(( (vC1 >> 7) & 1 ))

    tablet_mode=$(cat /sys/devices/platform/thinkpad_acpi/hotkey_tablet_mode 2>/dev/null || echo "N/A")

    current="0x27=${h27} 0x49=${h49} 0xC1=${hC1}(bit7=${c1_bit7}) tablet=${tablet_mode}"

    if [[ "$current" != "$PREV" ]]; then
        echo "[$(date +%H:%M:%S)] $current"
        PREV="$current"
    fi

    sleep 0.3
done
