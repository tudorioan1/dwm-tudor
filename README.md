<div align="center">
  <img src="./dwm.png" alt="dwm-logo" width="185" height="230"/>

  # **dwm - dynamic window manager**
  ### dwm is an extremely ***fast***, ***small***, and ***dynamic*** window manager for X.

</div>

---
> **Note:** This is a personal project and still a work in progress. It is built around my own workflow and assumes some familiarity with Linux and window managers, so a little troubleshooting after installing is to be expected.

A functional, minimalist and super fast desktop experience built on the original Suckless DWM, heavily modified for my needs, for **Arch Linux, Debian/Ubuntu, Fedora and openSUSE Tumbleweed** with X11 (Wayland is not supported).
<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/9d1d8d46-f80c-43b3-ae1f-2038b4b69952" />

## Features

- **Polybar** integration (replaces the dwm bar), per-monitor bars with Xinerama
- **Window swallowing**, **Pertag**, **Cfact**, **Movestack**, 3-state **fullscreen**, **noborder**, **cursor warp**, **window icons**, **EWMH** compliance
- **15 live themes** (9 dark, 5 light, monochrome) that restyle dwm, Polybar, rofi, dunst, the terminal and the GTK look at once
- **Control Center** (<kbd>SUPER</kbd> + <kbd>F1</kbd>): themes, system health, quick actions
- **Wallpaper picker** (Quickshell) that follows the theme

## Installation

Run the installer for your distro as a **normal user, not root** (it uses `sudo` when needed):

```bash
git clone https://github.com/tudorioan1/dwm-tudor && cd dwm-tudor
chmod +x install-*.sh
./install-arch.sh        # Arch
./install-debian.sh      # Debian / Ubuntu
./install-fedora.sh      # Fedora
./install-opensuse.sh    # openSUSE Tumbleweed (new, less tested)
```

Before it changes anything, the installer **copies your existing config** (`~/.xinitrc`, `~/.bashrc`, GTK settings and the `polybar`, `rofi`, `dunst`, `picom`, `alacritty`, `kitty`, `ghostty`, `quickshell`, `dwm-tudor` folders in `~/.config`) to `~/backup-files/<date-time>/` and tells you where. It is a copy, not a move, because `make install` keeps your `~/.config/dwm-tudor`.

It installs the JetBrainsMono and MesloLGS Nerd Fonts and the Papirus icons, and lists anything it could not install at the end. At the end it also asks three optional questions (Enter = yes, `n` = no; nothing happens without a terminal):

- **GTK look:** *Materia* theme, *Papirus* icons, *Bibata-Modern-Ice* cursor and the *Inter Nerd Font Propo Medium 12.5* font. Materia and Bibata come from their official GitHub projects; Inter is built from source with the Nerd Fonts patcher (takes a few minutes). Answer no and your current GTK setup stays untouched.
- **Bash prompt:** my prompt from [tudorioan1/mybash](https://github.com/tudorioan1/mybash).
- **Default web browser:** picked from the browsers found on your system; it is set as the system default and used by <kbd>SUPER</kbd> + <kbd>B</kbd>.

**Quickshell** (wallpaper picker): on Debian 13 the installer enables the official `trixie-backports`; on Fedora it offers a COPR and on openSUSE an Open Build Service repository, always asking first (default no on openSUSE).

### Start dwm

Log out, pick **dwm** in your display manager, log back in. Or run `startx` from a TTY (the installer places `.xinitrc` in your home).

## Keybindings

<kbd>SUPER</kbd> + <kbd>/</kbd> opens an interactive keybind viewer that reads your live `~/.config/dwm-tudor/hotkeys.toml` (hot-reloading).

| Keybind | Action |
|---------|--------|
| <kbd>SUPER</kbd> + <kbd>X</kbd> | Terminal |
| <kbd>SUPER</kbd> + <kbd>B</kbd> | Web browser (the one chosen at install) |
| <kbd>SUPER</kbd> + <kbd>R</kbd> | App launcher (rofi) |
| <kbd>SUPER</kbd> + <kbd>F1</kbd> | Control Center |
| <kbd>SUPER</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>SUPER</kbd> + <kbd>J</kbd> / <kbd>K</kbd> | Focus next / previous window |
| <kbd>SUPER</kbd> + <kbd>H</kbd> / <kbd>L</kbd> | Resize master area |
| <kbd>SUPER</kbd> + <kbd>1-5</kbd> | Switch to tag |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>1-5</kbd> | Move window to tag |
| <kbd>SUPER</kbd> + <kbd>T</kbd> / <kbd>F</kbd> / <kbd>M</kbd> | Tile / Float / Fullscreen |
| <kbd>SUPER</kbd> + <kbd>Space</kbd> | Toggle floating |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> | Screenshot (Flameshot) |
| <kbd>SUPER</kbd> + <kbd>Ctrl</kbd> + <kbd>Q</kbd> | Power menu |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>Q</kbd> | Quit dwm |

## Configuration

Settings live in `~/.config/dwm-tudor/` and apply live, with no recompiling: `hotkeys.toml` (keys, and the `browser` variable), `themes.toml` (colors and the active theme) and `window-rules.toml`. Edit these, not the defaults under `~/.local/share/dwm-tudor/`. Compile-time options are in `config.h` (rebuild with `make && sudo make install`).

## Theming

Change the theme from <kbd>SUPER</kbd> + <kbd>F1</kbd> → *Appearance* → *Select Theme*, or set `theme = "..."` in `themes.toml`. The default is **monochrome**; the others are `nord`, `dracula`, `gruvbox`, `catppuccin`, `tokyonight`, `onedark`, `solarized`, `rosepine`, `everforest` and the light `catppuccin-latte`, `gruvbox-light`, `solarized-light`, `rosepine-dawn`, `tokyonight-day`.

On the dark themes the terminal and window borders are a darker shade tinted with the theme color (a hint of purple for Dracula, green for Everforest). Each theme has its own rofi theme (`rofi-<theme>`); set `rofi_theme` in `themes.toml` to use another layout such as `sidetab-nord`. With the Materia and Papirus families, the GTK theme and icons switch between their dark and light variants together with the theme.

### GTK

Change the GTK theme, icons, cursor and font with **`nwg-look`** or **`lxappearance`** (run as a normal user). A choice made there now survives restarts: `theme-apply.sh` only manages the GTK theme name while it is unset or Adwaita. If it still resets on an older install, lock it with `sudo chattr +i ~/.config/gtk-3.0/settings.ini` (undo with `-i`).

## Troubleshooting

- **Dependencies:** run `scripts/check-deps.sh`, or Control Center → *System Health*.
- **After `sudo make install`** log out and back in. If an updated script has no effect, run `which -a <script>`: a copy in `/usr/local/bin` wins over the one in `~/.local/share/dwm-tudor/scripts/`.
- **Black screen after suspend:** `resume-hook.sh` restarts picom (the cause on NVIDIA) after every resume. If it still happens, set `backend = "xrender"` in `~/.config/picom/picom.conf`.
- **Flameshot not working:** right-click its tray icon → configuration → enable "legacy X11 screenshot method".
- **Something of yours was overwritten:** look in `~/backup-files/`.

## Credits & License

Built on [suckless dwm](https://dwm.suckless.org/) and forked from Chris Titus Tech's [dwm-titus](https://github.com/ChrisTitusTech/dwm-titus). dwm is released under the MIT/X Consortium License, see [LICENSE](./LICENSE).
