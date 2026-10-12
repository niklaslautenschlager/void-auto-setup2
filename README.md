# Void Post-install

A guided Void Linux workstation setup. It configures PipeWire, selects desktop environments or window managers, applies a matching rice, and optionally adds graphics drivers, applications, Bluetooth, and NetworkManager.

Run from the extracted directory as root:

```sh
sudo ./install.sh
```

The installer asks all questions first, displays a plan, and waits for confirmation before changing the system. It writes a log to `/var/log/void-postinstall.log`.

Options:

- `sudo ./install.sh --dry-run` shows the actions without applying them.
- `sudo ./install.sh --rices-only` reapplies the rices for the installed sessions.
- `sudo ./install.sh --help` prints usage.

The installer supports six desktop environments and the Void-packaged dynamic tiling WMs in `lib/catalog.sh`. Each selected WM gets its own palette and config. Qtile has separate Wayland and X11 sessions with one shared rice. `dwm` and `FrankenWM` are built with the matching palette; if a source build fails, their Void package remains available as a fallback.

## PipeWire

The installer configures PipeWire, WirePlumber, PulseAudio compatibility, and ALSA routing. It starts one audio stack for wrapped WM sessions and uses XDG autostart for full desktop environments. `void-session` provides a D-Bus session bus and runtime directory when needed, and cleans up stale PipeWire processes at logout.

After logging in, check the setup with:

```sh
void-audio-check
```

For a desktop environment, log out and back in after installation so the new autostart entry runs. For a seatd setup, group changes also take effect at the next login.

## Shared keys

All WM rices use Super (Windows key) as the main modifier:

| Keys | Action |
|---|---|
| Super+Return | Terminal |
| Super+D or Super+Space | Application launcher |
| Super+Q | Close focused window |
| Super+H/J/K/L (arrows where supported) | Focus a window |
| Super+Shift+H/J/K/L (arrows where supported) | Move or promote a window |
| Super+Ctrl+H/J/K/L (arrows where supported) | Resize or adjust the tiling layout |
| Super+1–9 | Switch workspace |
| Super+Shift+1–9 | Move window to workspace |
| Super+F | Fullscreen |
| Super+V | Floating mode (WM-specific where unsupported) |
| Super+Escape | Lock |
| Super+Shift+Escape | Power menu |
| Super+Shift+R | Reload or restart the WM |
| Print / Shift+Print | Full-screen / area screenshot |
| XF86 media and brightness keys | Volume, mute, playback, and brightness |

On a seatd setup the suspend action uses `sudo -n zzz`; the installer adds a narrow sudoers rule for that helper and for reboot/poweroff. Under elogind, the power menu uses `loginctl`.

## Rices and palettes

Rice source files are installed under `/usr/local/share/void-postinstall/rices`. Each WM has a palette in `palettes/`, a wallpaper, and a WM-specific config. Edit the installed palette, then apply it:

```sh
sudoedit /usr/local/share/void-postinstall/rices/palettes/ember.conf
sudo void-rice apply ember --user YOUR_USER
```

`void-rice list` shows the rice/WM mapping. `void-rice apply --installed --user YOUR_USER` refreshes all installed rices. Existing configs are backed up under `~/.config/void-rice/.backup/`. Per-user palette overrides live at `~/.config/void-rice/<rice>.conf`; keyboard settings can be overridden in `~/.config/void-rice/settings.conf`.

`dwm` and `FrankenWM` compile from upstream source using the rice palette. Rebuild one with `sudo void-rice build dwm` or `sudo void-rice build frankenwm`. Downloaded source archives are checksum-verified. On systems that cannot reach the upstream source site, place a matching source archive somewhere local and set `VOID_RICE_TARBALL=/path/to/archive` for the build.

## Updates with Hyprland

The Hyprland repository is kept at low priority and packages installed from it are repolocked. Use `void-update` for system upgrades so it can hold only the packages whose updates would break a third-party shared-library dependency:

```sh
sudo void-update
sudo void-update --dry-run
sudo void-update --status
```

A hold created by `void-update` is released automatically on the next run, allowing the package to update after the third-party repository catches up. `sudo void-update --release` removes only holds managed by this tool. Do not use a plain `xbps-install -Su` while Hyprland packages from the third-party repository are installed.

## Restoring upstream session entries

The installer writes `/etc/xbps.d/90-void-postinstall.conf` with `noextract` rules so package updates do not restore upstream session entries beside the wrapped `void-session` entries. To undo that mask, remove the file and force-reinstall the package that owns each session file:

```sh
sudo rm /etc/xbps.d/90-void-postinstall.conf
xbps-query -o /usr/share/xsessions/i3.desktop
sudo xbps-install -f PACKAGE_NAME
```

Replace the example path with the session file you want to restore and use the package name printed by `xbps-query -o`. Removing the mask alone does not recreate a file that was already removed.
