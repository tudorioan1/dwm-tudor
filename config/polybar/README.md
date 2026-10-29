# Polybar Configuration (dwm-tudor)

This directory contains the Polybar status bar configuration bundled with dwm-tudor. It is **self-contained** — you do not need to clone any external repos.

## How It Works

When dwm starts, it launches `polybar/launch.sh` which:
- Detects connected monitors via `xrandr`
- Launches the **main** bar (with systray + EWMH tags) on the primary monitor
- Launches **secondary** bars (no tray) on additional monitors
- Auto-detects laptops (battery present) and uses `laptop-config.ini`

The default theme is **minimal** (Nord-inspired).

## Setup

### 1. Install Polybar
```bash
sudo pacman -S polybar
```

### 2. Install Fonts

The icon fonts (MaterialIcons, Feather) are bundled in `fonts/`:
```bash
mkdir -p ~/.local/share/fonts
cp -r fonts/* ~/.local/share/fonts/
fc-cache -fv
```

Also install the text font:
```bash
sudo pacman -S ttf-jetbrains-mono-nerd
```

> The default text font can be changed in `fonts.ini`.

### 3. Config Location

When you run `sudo make install` from the dwm-tudor root, Polybar configs are copied to:
```
~/.config/polybar/
```

The launch script path used by dwm is:
```
~/.config/polybar/launch.sh
```

### 4. Customizing Modules

Edit `themes/minimal/config.ini` to control which modules appear:
```ini
modules-left = ...
modules-center = ...
modules-right = ...
```

Available modules are in `themes/minimal/modules/`.

## Multi-Monitor

- **Single monitor**: One bar with systray + EWMH tags
- **Multiple monitors**: Primary monitor gets systray + EWMH; secondary monitors get a simpler bar
- Primary monitor is auto-detected via `xrandr --query`


