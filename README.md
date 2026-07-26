<div align="center">
  <img src="./dwm-logo-bordered.png" alt="dwm-logo-bordered" width="195" height="90"/>

  # dwm - dynamic window manager
  ### dwm is an extremely ***fast***, ***small***, and ***dynamic*** window manager for X.

</div>

---
! Note !
This project is still in beta, so expect some minor bugs.

This is a fork of CTT's version of dwm modified for my needs. It includes numerous patches and customizations for a productive, user-friendly desktop on Arch Linux with X11.
<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/7a9d0545-48f7-4b29-aa4b-be7e093afb93" />


### Patches & Features

- **Polybar** integration (replaces dwm built-in bar)
- **Window swallowing** — terminals absorb child GUI windows
- **EWMH** compliance — proper desktop/tag reporting for external tools
- **Pertag** — independent layouts, master counts, and sizing per tag
- **Cfact** — per-window sizing in tiled layouts
- **Movestack** — reorder windows in the stack with keybinds
- **Systray** — built-in system tray (disabled by default when using Polybar)
- **Fullscreen** — actual and fake fullscreen toggle (3-state)
- **Window icons** — title bar icons via `_NET_WM_ICON`
- **Cursor warp** — cursor follows focus across windows/monitors
- **Noborder** — auto-remove borders when only one window is visible
- **Multi-monitor** — Xinerama support with per-monitor Polybar bars

### Installation
```bash
git clone https://github.com/tudorioan1/dwm-tudor && cd dwm-tudor && chmod +x ./install-arch.sh && ./install-arch.sh && touch ~/font.rasinc
```
### Make your own config file for dwm
```bash
cp config.def.h config.h
```

### Post-Install Setup

**Option A — Display Manager** (SDDM, GDM, LightDM):
Log out, select **dwm** from the session menu, and log back in.

**Option B — startx**:
The installer places `.xinitrc` in your home directory. Start with:
```bash
startx
```

The `.xinitrc` disables screen blanking/DPMS (prevents NVIDIA GPU issues on wake), launches Polybar, and starts dwm.
For changing display resolution or refresh rate, use xrandr.
---

## ⌨️ Keybindings

Press <kbd>SUPER</kbd> + <kbd>/</kbd> inside dwm for an **interactive keybind viewer** (via rofi).

### Essential Keybinds

| Keybind | Action |
|---------|--------|
| <kbd>SUPER</kbd> + <kbd>X</kbd> | Open terminal |
| <kbd>SUPER</kbd> + <kbd>R</kbd> | Launch rofi  |
| <kbd>SUPER</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>SUPER</kbd> + <kbd>J</kbd> / <kbd>K</kbd> | Focus next / previous window |
| <kbd>SUPER</kbd> + <kbd>H</kbd> / <kbd>L</kbd> | Resize master area |
| <kbd>SUPER</kbd> + <kbd>1-9</kbd> | Switch to tag (workspace) |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>1-9</kbd> | Move window to tag |
| <kbd>SUPER</kbd> + <kbd>T</kbd> | Tile layout |
| <kbd>SUPER</kbd> + <kbd>F</kbd> | Floating layout |
| <kbd>SUPER</kbd> + <kbd>M</kbd> | Fullscreen |
| <kbd>SUPER</kbd> + <kbd>Space</kbd> | Toggle floating |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>Q</kbd> | Quit dwm |
| <kbd>SUPER</kbd> + <kbd>Ctrl</kbd> + <kbd>Q</kbd> | Power menu |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> | Screenshot (Flameshot) |
---
! Known issues : If flameshot is not working, enter the configuration menu by right-clicking on the flameshot icon in the system tray (after opening it from rofi) and enable legacy X11 screenshot method.
## 🔧 Configuration

dwm is configured by editing `config.h` and recompiling:

```bash
$EDITOR config.h
make && sudo make install
```

> **Note:** `config.def.h` is the clean default template. `config.h` is your personal customization. If `config.h` doesn't exist, `make` will create it from `config.def.h` automatically.

Key things to customize in `config.h`:
- **`refresh_rate`** — match your monitor (default: 60, set to 120 for high-refresh)
- **`fonts[]`** — font family and size
- **`colors[]`** — color scheme (Nord theme by default in config.h)
- **`autostart[]`** — programs launched on startup
- **`rules[]`** — per-application window rules (floating, tags, terminal detection)
- **`keys[]`** — all keybindings
- **`MODKEY`** — modifier key (`Mod4Mask` = Super, `Mod1Mask` = Alt)

---


