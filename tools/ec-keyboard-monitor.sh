#!/usr/bin/env bash

# Monitor EC registers related to keyboard/proximity detection on X1 Fold 16
# Run with: sudo bash ec-keyboard-monitor.sh
#
# Attach and detach the keyboard while this runs to see which registers change.
# Press Ctrl+C to stop.

set -e

# Load ec_sys if not loaded
if [[ ! -f /sys/kernel/debug/ec/ec0/io ]]; then
    echo "Loading ec_sys module with write_support..."
    modprobe ec_sys write_support=1
fi

EC_IO="/sys/kernel/debug/ec/ec0/io"

if [[ ! -f "$EC_IO" ]]; then
    echo "Error: $EC_IO not found. Is the ec_sys module loaded?" >&2
    exit 1
fi

# Read a single byte from EC register as decimal
read_ec() {
    local offset=$1
    dd if="$EC_IO" bs=1 skip="$offset" count=1 2>/dev/null | od -An -tu1 | tr -dc '0-9'
}

# Known registers from DSDT analysis:
#   0x46 bit 6 = PSST (proximity sensor state 1)
#   0x47 bit 1 = PSS2 (proximity sensor state 2)
#   0xC6 bit 0 = DPRL (dock presence relay / lap sensor)

echo "Monitoring EC registers for keyboard/proximity detection..."
echo "Attach and detach the keyboard while this runs."
echo ""
echo "Registers:"
echo "  0x46 (PSST at bit 6) - proximity sensor 1"
echo "  0x47 (PSS2 at bit 1) - proximity sensor 2"
echo "  0xC6 (DPRL at bit 0) - dock presence / lap sensor"
echo ""
echo "Also monitoring tablet_mode and dytc_lapmode sysfs values."
echo "---"

PREV=""

while true; do
    val46=$(read_ec 70)   # 0x46 = 70 decimal
    val47=$(read_ec 71)   # 0x47 = 71 decimal
    valC6=$(read_ec 198)  # 0xC6 = 198 decimal

    psst=$(( (val46 >> 6) & 1 ))
    pss2=$(( (val47 >> 1) & 1 ))
    dprl=$(( valC6 & 1 ))

    reg46_hex=$(printf "%02x" "$val46")
    reg47_hex=$(printf "%02x" "$val47")
    regC6_hex=$(printf "%02x" "$valC6")

    # Also read sysfs values
    tablet_mode=$(cat /sys/devices/platform/thinkpad_acpi/hotkey_tablet_mode 2>/dev/null || echo "N/A")
    lapmode=$(cat /sys/devices/platform/thinkpad_acpi/dytc_lapmode 2>/dev/null || echo "N/A")

    current="0x46=${reg46_hex}(PSST=${psst}) 0x47=${reg47_hex}(PSS2=${pss2}) 0xC6=${regC6_hex}(DPRL=${dprl}) tablet=${tablet_mode} lap=${lapmode}"

    if [[ "$current" != "$PREV" ]]; then
        echo "[$(date +%H:%M:%S)] $current"
        PREV="$current"
    fi

    sleep 0.3
done
