<div align="center">
  <img src="./dwm.png" alt="dwm-logo" width="185" height="230"/>

  # **dwm - dynamic window manager**
  ### dwm is an extremely ***fast***, ***small***, and ***dynamic*** window manager for X.
<span style="font-size: 45px;">Test</span>
</div>

---
> **Note:** This is a personal project and still a work in progress. It is built around my own workflow and assumes some familiarity with Linux and window managers, so a little troubleshooting after installing is to be expected.

A functional, minimalist and super fast desktop experience based on Suckless' DWM, that was heavily modified for my needs. It includes numerous patches and customizations for a productive workflow on **Arch Linux, Fedora and Debian/Ubuntu** with X11 (Wayland is not supported).
<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/2be9d3ef-42b2-4880-bb91-13344ad5b626" />

## Patches & Features

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
- **Live theming** — 15 themes that restyle dwm, Polybar, rofi and the terminal at once
- **Control Center** — rofi-based menu (<kbd>SUPER</kbd> + <kbd>F1</kbd>) for themes, system health and quick actions
- **Wallpaper picker** — Quickshell grid opened from Polybar; it follows the colors of the active theme (black if none is found) and closes with the X button in its top-right corner or <kbd>Esc</kbd>

## Installation

> **Important** : If you install my configuration of dwm on a system where other dotfiles were installed, existing files may be overwritten (including `~/.xinitrc`, `~/.config/dwm-tudor/` and the Polybar, rofi and dunst configs). Back them up first.

Run the installer as a **normal user, not as root** (it calls `sudo` when needed).

Arch :
```bash
git clone https://github.com/tudorioan1/dwm-tudor && cd dwm-tudor && chmod +x ./install-arch.sh && ./install-arch.sh
```
Fedora :
```bash
git clone https://github.com/tudorioan1/dwm-tudor && cd dwm-tudor && chmod +x ./install-fedora.sh && ./install-fedora.sh
```
Debian/Ubuntu :
```bash
git clone https://github.com/tudorioan1/dwm-tudor && cd dwm-tudor && chmod +x ./install-debian.sh && ./install-debian.sh
```

### What the installers add

- **Fonts:** JetBrainsMono Nerd Font and MesloLGS Nerd Font Mono (packages `ttf-jetbrains-mono-nerd` and `ttf-meslo-nerd` on Arch, upstream Nerd Fonts download on Fedora/Debian).
- **Icons:** the **Papirus** icon theme (`papirus-icon-theme`), already used by rofi and dunst.
- **Quickshell** (used by the wallpaper picker). On **Debian 13** the installer enables the official `trixie-backports` repository (it adds `/etc/apt/sources.list.d/debian-backports.sources`) and installs `quickshell` from it, together with the Qt QML modules it needs. Debian 12 is too old for Quickshell, and on Ubuntu older than 26.10 it has to be installed manually (the installer prints the PPA command).
- `dwm-session` is installed by `make install`; no manual copy step is needed.

### Questions asked at the end of the install

All three are optional: press <kbd>Enter</kbd> for yes, <kbd>n</kbd> for no. Nothing is changed when the installer runs without a terminal.

- **GTK look:** *Materia-dark* theme, *Papirus-Dark* icons and the *Bibata-Modern-Ice* cursor (the cursor is downloaded from upstream; the theme and icons come from your distro's packages). If you answer no, your current GTK theme, icons and cursor stay as they are.
- **Bash prompt:** installs my customised bash prompt from [tudorioan1/mybash](https://github.com/tudorioan1/mybash) (cloned to `~/mybash`).
- **Default web browser:** the installer scans the browsers installed on your system (native, Flatpak and Snap) and lets you pick one. It becomes the system default (`xdg-settings`) and the `browser` variable in `~/.config/dwm-tudor/hotkeys.toml`, which <kbd>SUPER</kbd> + <kbd>B</kbd> uses.

### Post-Install Setup

**Option A — Display Manager** (SDDM, GDM, LightDM, etc.):
Log out, select **dwm** from the session menu, and log back in.

**Option B — startx**:
The installer places `.xinitrc` in your home directory. Start from TTY with:
```bash
startx
```

---
**The `.xinitrc` disables screen blanking/DPMS (prevents NVIDIA GPU issues on wake), launches Polybar, and starts dwm.
For changing display resolution or refresh rate, use xrandr.**

**GTK theming:** the installer can set a GTK look for you (see above): **Materia-dark** theme, **Papirus-Dark** icons and the **Bibata-Modern-Ice** cursor. To change the GTK theme, icon theme, cursor theme and font manually, use **`nwg-look`** (installed by the installers) or **`lxappearance`** (install it from your distro's repositories). Launch either one from a terminal as a normal user, not as root. *Materia-dark* is the theme that works best with this setup.

> **Note:** a theme picked with `nwg-look` or `lxappearance` used to be lost at every restart, because `theme-apply.sh` reset the GTK theme to Adwaita each time. Current versions only manage the GTK theme *name* while it is unset or one of the stock Adwaita themes, and they always keep the dark/light preference in sync, so your choice now survives restarts and theme switches. If it still resets (for example with an older `theme-apply.sh`), lock the file: `sudo chattr +i ~/.config/gtk-3.0/settings.ini`. Undo it with `sudo chattr -i ~/.config/gtk-3.0/settings.ini` before changing the GTK theme again.

## Keybindings

Press <kbd>SUPER</kbd> + <kbd>/</kbd> inside dwm for an **interactive keybind viewer** (via rofi). It reads your live `~/.config/dwm-tudor/hotkeys.toml`, so it always shows what is really bound.

To modify the keybinds, edit `~/.config/dwm-tudor/hotkeys.toml` (hot-reloading, no logout needed).

### Essential keybinds

| Keybind | Action |
|---------|--------|
| <kbd>SUPER</kbd> + <kbd>X</kbd> | Open terminal |
| <kbd>SUPER</kbd> + <kbd>R</kbd> | Launch rofi (App Launcher) |
| <kbd>SUPER</kbd> + <kbd>F1</kbd> | Launch dwm Control Center |
| <kbd>SUPER</kbd> + <kbd>/</kbd> | Keybind viewer |
| <kbd>SUPER</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>SUPER</kbd> + <kbd>J</kbd> / <kbd>K</kbd> | Focus next / previous window |
| <kbd>SUPER</kbd> + <kbd>H</kbd> / <kbd>L</kbd> | Resize master area |
| <kbd>SUPER</kbd> + <kbd>1-9</kbd> | Switch to tag (workspace) |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>1-9</kbd> | Move window to tag |
| <kbd>SUPER</kbd> + <kbd>T</kbd> / <kbd>F</kbd> / <kbd>M</kbd> | Tile layout / Float layout / Fullscreen |
| <kbd>SUPER</kbd> + <kbd>Space</kbd> | Toggle floating |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> | Screenshot (Flameshot) |
| <kbd>SUPER</kbd> + <kbd>Ctrl</kbd> + <kbd>Q</kbd> | Power menu |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>Q</kbd> | Quit dwm |

<kbd>SUPER</kbd> + <kbd>B</kbd> opens your web browser: the one you picked during the install, or `brave-origin` by default. To change it, edit the `browser` variable in the `[vars]` section of `hotkeys.toml` (a command with arguments, such as `flatpak run org.mozilla.firefox`, works too).

## Configuration

Most of the configuration lives in TOML files in `~/.config/dwm-tudor/`, and changes are applied live (no recompiling, no logout):

| File | What it controls |
|------|------------------|
| `hotkeys.toml` | Keybindings |
| `themes.toml` | Colors and the active theme (dwm, Polybar, rofi, terminal) |
| `window-rules.toml` | Per-application window rules (floating, tags, terminal detection) |

Edit the files in `~/.config/dwm-tudor/`, **not** the copies under `~/.local/share/dwm-tudor/`: those are only the defaults that `make install` ships.

`config.h` holds the compile-time settings. After editing it, rebuild:

```bash
$EDITOR config.h
make && sudo make install
```

> **Note:** `config.def.h` is the clean default template. `config.h` is your personal customization. If `config.h` doesn't exist, `make` will create it from `config.def.h` automatically.

Key things to customize in `config.h`:
- **`refresh_rate`** — set to the highest refresh rate that your monitor supports, or use xrandr in the autostart script
- **`fonts[]`** — font family and size
- **`autostart[]`** — programs launched on startup
- **`MODKEY`** — modifier key (`Mod4Mask` = Super, `Mod1Mask` = Alt)

`keys[]`, `colors[]` and `rules[]` also exist in `config.h`, but they are superseded by `hotkeys.toml`, `themes.toml` and `window-rules.toml` above.

## Theming

You can change the theme in two ways:

- **Control Center:** <kbd>SUPER</kbd> + <kbd>F1</kbd> → *Appearance* → *Select Theme*
- **By hand:** edit `theme = "..."` in `~/.config/dwm-tudor/themes.toml` and follow the instructions written there.

Changing the theme updates dwm, Polybar, rofi and the terminal. The default theme is **monochrome**. Available themes: `monochrome`, `nord`, `dracula`, `gruvbox`, `catppuccin`, `tokyonight`, `onedark`, `solarized`, `rosepine`, `everforest`, and the light ones `catppuccin-latte`, `gruvbox-light`, `solarized-light`, `rosepine-dawn`, `tokyonight-day`.

Every theme has its own rofi theme (`rofi-monochrome`, `rofi-nord`, `rofi-tokyonight`, ...): the same drop-down launcher, in the colors of the active theme. It is chosen by the `rofi_theme` key of each theme in `themes.toml`. The older `sidetab-*` layouts are still included; to use one, set `rofi_theme` to its name (for example `sidetab-nord`).

## Troubleshooting

- **Check dependencies:** Control Center → *Quick Actions* → *Run Dependency Check*, or run `scripts/check-deps.sh`. *System Health* in the Control Center does the same check live and can launch the right installer for your distro.
- **After `sudo make install`**, log out and back in, so `dwm-session` (and its environment, e.g. the Qt platform theme) is picked up.
- **An updated script seems to have no effect?** Run `which -a <script>`: a copy in `/usr/local/bin` wins over the one in `~/.local/share/dwm-tudor/scripts/`. Reinstall with `sudo make install`.
- **GTK theme resets after a restart:** see the note in the GTK theming section (`theme-apply.sh` update, or `chattr +i` on `~/.config/gtk-3.0/settings.ini`).
- **Flameshot not working:** open it from rofi or a terminal, right-click its icon in the system tray to enter the configuration menu, and enable "legacy X11 screenshot method (deprecated)".

### Known limitations

- The Quickshell wallpaper picker needs Debian 13 or newer (Debian 12 is not supported); on Ubuntu older than 26.10 install Quickshell manually.
- X11 only.

## Credits & License

Built on [suckless dwm](https://dwm.suckless.org/) and forked from Chris Titus Tech's [dwm-titus](https://github.com/ChrisTitusTech/dwm-titus) configuration. dwm is released under the MIT/X Consortium License; see [LICENSE](./LICENSE).
