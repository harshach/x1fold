#!/usr/bin/env bash

# Dump all 256 EC registers and compare before/after keyboard attachment.
# Run with: sudo bash ec-dump-diff.sh
#
# Takes two snapshots and shows which bytes changed.

set -e

if [[ ! -f /sys/kernel/debug/ec/ec0/io ]]; then
    modprobe ec_sys write_support=1
fi

EC_IO="/sys/kernel/debug/ec/ec0/io"

dump_ec() {
    od -An -tx1 -w16 -v "$EC_IO"
}

echo "=== EC Register Diff Tool ==="
echo ""
echo "Step 1: DETACH the keyboard, then press Enter."
read -r
echo "Taking snapshot 1 (keyboard detached)..."
DUMP1=$(dump_ec)

echo ""
echo "Step 2: ATTACH the keyboard, then press Enter."
read -r
echo "Taking snapshot 2 (keyboard attached)..."
DUMP2=$(dump_ec)

echo ""
echo "=== Comparing snapshots ==="

# Convert to arrays and compare byte-by-byte
BYTES1=($(echo "$DUMP1" | tr -s ' ' '\n' | grep -v '^$'))
BYTES2=($(echo "$DUMP2" | tr -s ' ' '\n' | grep -v '^$'))

changes=0
for i in "${!BYTES1[@]}"; do
    if [[ "${BYTES1[$i]}" != "${BYTES2[$i]}" ]]; then
        printf "  Offset 0x%02X (%3d): %s -> %s\n" "$i" "$i" "${BYTES1[$i]}" "${BYTES2[$i]}"
        changes=$((changes + 1))
    fi
done

if [[ $changes -eq 0 ]]; then
    echo "  No EC register changes detected."
else
    echo ""
    echo "$changes register(s) changed."
fi
