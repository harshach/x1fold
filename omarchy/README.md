# X1 Fold on Omarchy (Arch + Hyprland)

Support scripts and configs for running the ThinkPad X1 Fold 16 Gen 1 on [Omarchy](https://github.com/getomarchy/omarchy).

## Features

- **Auto-rotation** — screen rotates automatically in tablet mode via accelerometer
- **Laptop mode** — toggle to use only the top half of the display when the screen is folded with keyboard on bottom
- **On-screen keyboard** — wvkbd auto-shows when no physical keyboard is attached, hides when one is connected
- **Waybar integration** — laptop mode toggle button in the status bar
- **Boot-time Bluetooth** — use your Bluetooth keyboard to enter LUKS passphrase at boot

## Quick Start

Set up everything (configs, scripts, packages, and boot-time Bluetooth) with a single command:

```bash
git clone https://github.com/jeblair/x1fold.git
cd x1fold/omarchy
./bin/x1fold-setup --all
```

Then reboot.

Or install components separately:

```bash
./bin/x1fold-setup                  # Configs, scripts, packages only
./bin/x1fold-setup --boot-bluetooth # Add boot-time Bluetooth keyboard support
```

## What Gets Installed

### Packages
- `iio-sensor-proxy` — accelerometer/sensor support for auto-rotation
- `wvkbd` — on-screen keyboard for Wayland
- `mkinitcpio-bluetooth` (AUR, with `--all` or `--boot-bluetooth`) — Bluetooth keyboard in initramfs

### Scripts (symlinked to `~/.local/bin/`)
- `x1fold-laptop-mode` — toggle between full-screen and top-half-only mode
- `x1fold-rotate` — rotation daemon that listens to the accelerometer
- `x1fold-osk` — on-screen keyboard manager with auto-show/hide

### Configs (symlinked to `~/.config/`)
- `hypr/x1fold.conf` — monitor, input, and keybinding configuration
- `hypr/x1fold-autostart.conf` — autostart entries for rotation and OSK daemons
- `waybar/x1fold-modules.json` — laptop mode module for waybar

## Keybindings

| Binding | Action |
|---|---|
| `Super+Shift+L` | Toggle laptop mode |
| `Super+Shift+K` | Toggle on-screen keyboard |

## Configuration

### Monitor Name

The scripts default to `eDP-1`. If your display has a different name (check with `hyprctl monitors`), set it in your shell profile:

```bash
export X1FOLD_MONITOR="eDP-1"
```

### Laptop Mode Method

Two approaches are available for laptop mode:

- **`resolution`** (default) — switches the monitor to half-height resolution (2024x1280). Cleaner but may not work on all Hyprland versions.
- **`reserved`** — uses `addreserved` to block the bottom half. Safer fallback.

```bash
export X1FOLD_LAPTOP_METHOD="reserved"
```

### On-Screen Keyboard Options

Pass additional options to wvkbd:

```bash
export X1FOLD_WVKBD_OPTS="--landscape-layers full --hidden"
```

## Waybar

To add the laptop mode toggle to your waybar, add `"custom/laptop-mode"` to your modules list in `~/.config/waybar/config` and merge the module definition from `x1fold-modules.json`.

## Uninstall

```bash
./bin/x1fold-setup --uninstall
```

## Boot-Time Bluetooth

The `--boot-bluetooth` flag (included in `--all`) sets up your Bluetooth keyboard to work at the LUKS passphrase prompt during boot. It:

1. Verifies your keyboard is paired and trusted
2. Sets `AutoEnable=true` in `/etc/bluetooth/main.conf`
3. Installs `mkinitcpio-bluetooth` from AUR
4. Adds the `bluetooth` hook to `/etc/mkinitcpio.conf` (after `keyboard`, before `encrypt`)
5. Rebuilds the initramfs with `mkinitcpio -P`

**Prerequisites:**
- Your Bluetooth keyboard must be paired before running setup
- Uses the traditional `encrypt` hook (NOT compatible with `sd-encrypt`/`systemd` hook)
- `/boot` must be unencrypted

**Note:** The keyboard may take a few seconds to connect at boot. Keystrokes are buffered, so you can start typing your passphrase immediately.

## Troubleshooting

- **Rotation not working**: Ensure `iio-sensor-proxy` is running: `systemctl status iio-sensor-proxy`
- **OSK not showing**: Make sure `wvkbd` is installed: `pacman -Qi wvkbd`
- **Laptop mode not toggling**: Check the monitor name with `hyprctl monitors` and set `X1FOLD_MONITOR` accordingly
- **Resolution method doesn't work**: Try `export X1FOLD_LAPTOP_METHOD="reserved"` and re-toggle
- **Bluetooth keyboard not working at boot**: Ensure the keyboard is paired and trusted (`bluetoothctl devices Paired`), then re-run `x1fold-setup --boot-bluetooth`
- **sd-encrypt incompatibility**: `mkinitcpio-bluetooth` only works with the traditional `encrypt` hook, not `sd-encrypt`
