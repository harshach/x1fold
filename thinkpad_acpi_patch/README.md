# thinkpad_acpi kernel patch for X1 Fold 16

Patched `thinkpad_acpi` kernel module that adds foldable device support and magnetic keyboard dock detection for the ThinkPad X1 Fold 16.

## What the patch does

The patch makes 4 changes to `drivers/platform/x86/lenovo/thinkpad_acpi.c`. See `x1fold-type6.patch` for the exact diff.

### 1. Include path fix (out-of-tree build)

```c
-#include "../dual_accel_detect.h"
+#include "dual_accel_detect.h"
```

The upstream source uses a relative path to a header one directory up. Since we build out-of-tree via DKMS, we ship a local copy of `dual_accel_detect.h` and fix the include path.

### 2. GMMS type 6 recognition (foldable device)

The ThinkPad ACPI `GMMS` method returns a "type" in the upper 16 bits and a "value" in the lower 16 bits. The upstream driver handles types 1-5 (various Yoga hinges) but doesn't know about type 6 (foldable devices like the X1 Fold).

Without this, the driver logs:
```
Unknown multi mode status type 6 with value 0x0001
```

The patch adds `case 6` to recognize the foldable form factor and declares it supports laptop + tablet modes.

### 3. Value swap for type 6

**This is the non-obvious part.** For type 6 foldable devices, the GMMS values are inverted compared to other device types:

| GMMS value | Other types (1-5) | Type 6 (foldable) |
|------------|--------------------|--------------------|
| 1          | laptop             | **tablet** (fully open/flat) |
| 2          | flat               | **laptop** (folded, keyboard surface exposed) |

This was discovered empirically by observing GMMS output while physically folding/unfolding the device. Without the swap, the driver reports the wrong mode.

### 4. EC CMMD register dock bit (keyboard detection)

**The most important change.** Even with correct GMMS mode reporting, the fold state alone isn't enough for practical use. The X1 Fold's magnetic keyboard can be attached in laptop mode OR removed while the screen is still folded. GMMS only reports fold state, not keyboard presence.

The EC (Embedded Controller) register `0xC1` (known as CMMD in Lenovo's firmware) contains a dock bit:

- **Bit 7 of register 0xC1**: `1` = keyboard magnetically attached, `0` = keyboard detached

The patch reads this register when GMMS type is 6, and uses it for `hotkey_tablet_mode` instead of the fold state:

```c
if (((s >> 16) & 0xffff) == 6) {
    u8 cmmd;
    if (acpi_ec_read(0xc1, &cmmd))
        *status = (cmmd >> 7) & 1;
    else
        *status = hotkey_gmms_get_tablet_mode(s, NULL);
}
```

This means `/sys/devices/platform/thinkpad_acpi/hotkey_tablet_mode` reflects keyboard attachment, not fold state. The `x1fold-laptop-mode daemon` polls this file to switch modes.

## How the EC register was discovered

The `tools/` directory contains the scripts used to discover the dock bit:

1. **`ec-dump-diff.sh`** — Dumps all 256 EC registers, prompts to attach/detach keyboard, dumps again, shows diff. This identified register `0xC1` as changing between attached/detached states.

2. **`ec-keyboard-monitor.sh`** — Monitored candidate registers (`0x46`, `0x47`, `0xC6`) found from initial diffing. These turned out to be proximity/sensor related, not reliable for dock state.

3. **`ec-keyboard-monitor2.sh`** — Focused on `0x27`, `0x49`, `0xC1`. Confirmed bit 7 of `0xC1` is the cleanest signal: `1` = docked, `0` = undocked.

## How to update for a new kernel version

When a kernel update causes the DKMS build to fail (source incompatibility):

1. **Get the new kernel's source file:**
   ```bash
   KVER=$(uname -r)
   # Extract from kernel source (check arch linux kernel PKGBUILD for exact tag)
   curl -sL "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/platform/x86/lenovo/thinkpad_acpi.c?h=v${KVER%%-*}" \
     -o /tmp/thinkpad_acpi_new.c
   ```

2. **Copy it and apply the same 4 changes.** Search for these landmarks in the new source:
   - `#include "../dual_accel_detect.h"` — change to `"dual_accel_detect.h"`
   - `hotkey_gmms_get_tablet_mode` function — add `case 6` to the type switch
   - `switch (value)` in that same function — swap values 1 and 2 for type 6
   - `hotkey_get_tablet_mode` function, `TP_HOTKEY_TABLET_USES_GMMS` case — add EC CMMD read for type 6

3. **Test the build:**
   ```bash
   cd thinkpad_acpi_patch
   make clean && make
   ```

4. **Regenerate the patch for reference:**
   ```bash
   diff -u /tmp/thinkpad_acpi_new.c thinkpad_acpi.c > x1fold-type6.patch
   ```

5. **Update DKMS:**
   ```bash
   sudo dkms remove thinkpad-acpi-x1fold/1.0 --all
   sudo cp thinkpad_acpi.c Makefile dkms.conf dual_accel_detect.h /usr/src/thinkpad-acpi-x1fold-1.0/
   sudo dkms install thinkpad-acpi-x1fold/1.0
   sudo modprobe -r thinkpad_acpi && sudo modprobe thinkpad_acpi
   ```

## Checking if the patch is still needed

The upstream kernel may eventually add type 6 support. Check:

```bash
# Look at the upstream source for case 6 in hotkey_gmms_get_tablet_mode
curl -sL "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/platform/x86/lenovo/thinkpad_acpi.c" \
  | grep -A5 'case 6'
```

If upstream has added `case 6` handling (and EC CMMD reading), this patch is no longer needed. Run `x1fold-setup --uninstall` then `x1fold-setup` to use the stock module.

## Files in this directory

| File | Purpose |
|------|---------|
| `thinkpad_acpi.c` | Patched source (based on kernel 6.18.7) |
| `dual_accel_detect.h` | Required header, copied from upstream kernel |
| `Makefile` | Out-of-tree kernel module build |
| `dkms.conf` | DKMS configuration for auto-rebuild on kernel updates |
| `x1fold-type6.patch` | Unified diff for reference (all 4 changes) |
