# shellcheck shell=bash
# lib/audio.sh: PipeWire, set up the way the handbook describes and then made
# hard to break.
#
# Handbook checklist                          where it's handled
#   system D-Bus enabled                      install.sh (always)
#   user session bus                          void-session (dbus-run-session)
#   XDG_RUNTIME_DIR                           elogind / dumb_runtime_dir / void-session
#   audio+video groups without elogind        install.sh (seatd path)
#   pipewire + wireplumber                    queue below
#   10-wireplumber.conf, 20-pipewire-pulse    audio_configure
#   pulseaudio removed / not running          audio_configure
#   launch pipewire with the session          void-session, XDG autostart for DEs
#   Bluetooth: libspa-bluetooth               queue below
#   ALSA integration: alsa-pipewire + links   audio_configure
# Plus what the handbook doesn't cover: SOF firmware + UCM profiles (laptops
# without them have no sound card at all), rtkit for realtime scheduling,
# and restarting stale stacks.

audio_queue() {
  # keep a kept-for-dependencies pulseaudio from re-adding its autostart entry
  NOEXTRACT+=(/etc/xdg/autostart/pulseaudio.desktop)
  want "Audio (PipeWire)" pipewire wireplumber alsa-pipewire alsa-utils alsa-ucm-conf \
    pulseaudio-utils rtkit
  if [ "$HAS_INTEL_AMD_AUDIO" = 1 ] && [ "$ARCH" = x86_64 ]; then
    want "Audio (PipeWire)" sof-firmware
  fi
  [ "${WANT_BLUETOOTH:-0}" = 1 ] && want "Audio (PipeWire)" libspa-bluetooth
  return 0
}

audio_configure() {
  msg "Configuring PipeWire (system-wide, per handbook)"

  symlink /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/10-wireplumber.conf
  symlink /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf
  symlink /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/50-pipewire.conf
  symlink /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/99-pipewire-default.conf

  # PulseAudio: the handbook says uninstall it. Something may still depend on
  # it; then keep the package but make sure it can never start.
  if xbps-query -p pkgver pulseaudio >/dev/null 2>&1; then
    local rdeps
    rdeps="$(xbps-query -X pulseaudio 2>/dev/null | tr '\n' ' ')"
    if [ -z "$rdeps" ]; then
      run xbps-remove -y pulseaudio || warn "could not remove pulseaudio"
    else
      warn "pulseaudio is required by: $rdeps. Kept, but autospawn is disabled."
    fi
  fi
  write_file /etc/pulse/client.conf.d/00-void-postinstall.conf <<'EOF'
# PipeWire's pipewire-pulse provides the PulseAudio server; never autospawn
# a real pulseaudio daemon (written by void-postinstall).
autospawn = no
EOF
  remove_path /etc/xdg/autostart/pulseaudio.desktop

  # Full desktops (GNOME, KDE, XFCE, ...) have no systemd user units on Void,
  # so they need XDG autostart (handbook: "Launching Automatically").
  # void-pipewire exits immediately inside a void-session, so a WM that
  # happens to run XDG autostart cannot start a second stack.
  write_file /etc/xdg/autostart/void-pipewire.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=PipeWire (void-postinstall)
Comment=Start PipeWire, WirePlumber and pipewire-pulse for this session
Exec=/usr/local/bin/void-pipewire
Terminal=false
NoDisplay=true
X-GNOME-Autostart-Phase=Initialization
X-KDE-autostart-phase=1
EOF

  enable_service rtkit
}
