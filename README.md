# x1fold

Omarchy (Arch + Hyprland) configuration for the ThinkPad X1 Fold 16 Gen 1.

## Quick start

```bash
git clone <this-repo> ~/Code/x1fold
~/Code/x1fold/omarchy/bin/x1fold-setup
```

For boot-time Bluetooth keyboard (LUKS unlock):
```bash
x1fold-setup --boot-bluetooth
```

To remove everything:
```bash
x1fold-setup --uninstall
```

## What it does

- **Laptop mode** — Folds screen in half, uses top half for display, bottom half as keyboard surface. Automatically toggles when magnetic keyboard is attached/detached via patched kernel module.
- **Auto-rotation** — Accelerometer-driven display rotation via iio-sensor-proxy.
- **On-screen keyboard** — wvkbd auto-shows when no physical keyboard is detected.
- **Auto-brightness** — Ambient light sensor adjusts display brightness.
- **OLED protection** — Aggressive idle timeouts (dim 2min, off 3min, lock 5min).
- **Battery longevity** — Charge thresholds at 80-90% to protect the battery.
- **Keyboard dock detection** — Patched thinkpad_acpi kernel module reads EC register to detect magnetic keyboard attachment, installed via DKMS for automatic rebuild across kernel updates.
- **Caps Lock as Ctrl** — Remapped in Hyprland input config.

## Architecture decisions

### Display scaling: 1.6x (not 1.5x)

The X1 Fold has a 2024x2560 OLED panel at ~200 DPI. 1.5x scale seems natural but 2024 and 2560 don't divide evenly by 1.5. Hyprland requires integer logical pixels, so it rounds 1.5 up to ~1.6. We set 1.6 directly to avoid the warning. This gives 1265x1600 logical pixels.

### Kernel module: full source copy, not a patch-apply step

The DKMS setup ships a complete patched `thinkpad_acpi.c` rather than applying a patch to the installed kernel source at build time. Reasons:
- Arch's `linux-headers` package doesn't include `.c` source files, only headers
- Applying a patch at DKMS build time would require downloading kernel source, adding complexity and a network dependency
- The full source copy is self-contained and always builds

The tradeoff is that the source may drift from upstream on kernel updates. See [thinkpad_acpi_patch/README.md](thinkpad_acpi_patch/README.md) for how to update.

### Keyboard dock detection: EC register, not GMMS fold state

The ACPI GMMS method reports whether the screen is folded or flat, but not whether the keyboard is attached. The keyboard can be removed while the screen is still folded. We use EC register 0xC1 bit 7 instead, which directly reports magnetic keyboard attachment. See [thinkpad_acpi_patch/README.md](thinkpad_acpi_patch/README.md) for the full discovery story.

### Laptop mode: polling, not event-driven

`x1fold-laptop-mode daemon` polls `/sys/devices/platform/thinkpad_acpi/hotkey_tablet_mode` every 1 second. Event-driven approaches (udev, ACPI netlink) were considered but:
- The `thinkpad_acpi` driver does emit ACPI hotkey events for mode changes, but only when the GMMS value changes — not when the EC dock bit changes
- Polling at 1s is negligible CPU cost and catches all transitions reliably
- The sysfs file read is a single EC register read, essentially free

### OLED protection: hypridle, not a custom daemon

Rather than writing custom idle detection, we generate a `hypridle-x1fold.conf` with aggressive timeouts. This leverages Hyprland's native idle detection and integrates with hyprlock.

## Directory structure

```
omarchy/
  bin/
    x1fold-setup           # One-time setup script (install/uninstall)
    x1fold-laptop-mode     # Toggle/daemon for laptop mode
    x1fold-rotate          # Auto-rotation daemon
    x1fold-osk             # On-screen keyboard manager
    x1fold-brightness      # Auto-brightness daemon
    x1fold-battery         # Battery threshold management
    x1fold-oled-protect    # OLED burn-in protection config generator
  config/
    hypr/
      x1fold.conf          # Main Hyprland config (monitor, input, keybindings)
      x1fold-autostart.conf # Daemon autostart entries

thinkpad_acpi_patch/       # Patched kernel module (see its README.md)

tools/                     # EC register discovery scripts (development only)
```

## Keybindings

| Keys | Action |
|------|--------|
| Super+Shift+L | Toggle laptop mode |
| Super+Shift+K | Toggle on-screen keyboard |
