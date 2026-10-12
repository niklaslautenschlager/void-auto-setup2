# shellcheck shell=bash
# lib/session.sh: session wrapper, session entries, login manager.

SESSION_SHARE=/usr/local/share/void-postinstall
NOEXTRACT=()

# Scripts installed for every setup
install_session_tools() {
  msg "Installing session tools"
  local f
  for f in void-session void-pipewire void-audio-check void-update void-rice rice; do
    install_file "$ROOT_DIR/files/bin/$f" "/usr/local/bin/$f" 0755
  done
  write_file /etc/void-update.conf <<'EOF'
# void-update: substrings of repository URLs treated as third-party.
# Packages installed from them are repolocked after every update.
THIRD_PARTY="hyprland-void"
EOF
}

# Hide upstream session entries for the WMs we wrap, so no login manager
# offers the bare, bus-less variant. Must be written before packages install.
write_noextract_conf() {
  local id f
  for id in "${SEL_WMS[@]}"; do
    for f in ${HIDE[$id]:-}; do NOEXTRACT+=("$f"); done
  done
  [ "${#NOEXTRACT[@]}" -gt 0 ] || return 0
  {
    echo "# Written by void-postinstall. Upstream session entries are replaced by"
    echo "# wrapped ones (/usr/share/*sessions/void-*.desktop, Exec=void-session)."
    echo "# Delete this file to get the upstream entries back on the next update."
    for f in "${NOEXTRACT[@]}"; do echo "noextract=$f"; done
  } | write_file /etc/xbps.d/90-void-postinstall.conf
  for f in "${NOEXTRACT[@]}"; do remove_path "$f"; done
}

# Session definition + .desktop entry per installed WM
install_sessions() {
  msg "Registering window-manager sessions"
  local id dir exec fallback rice_label
  for id in "${SEL_WMS[@]}"; do
    if [ "$id" = hyprland ] && [ "${HV_OK:-0}" != 1 ]; then
      warn "Hyprland was not installed. No session entry created."
      continue
    fi
    exec="${EXEC[$id]}" fallback=""
    case "$id" in
      hyprland)  fallback="Hyprland" ;;
      dwm)       exec="/usr/local/bin/dwm"       fallback="dwm" ;;
      frankenwm) exec="/usr/local/bin/frankenwm" fallback="frankenwm" ;;
    esac
    rice_label="${RICE_LABEL[${RICE[$id]}]:-${RICE[$id]}}"
    write_file "$SESSION_SHARE/sessions/$id.env" <<EOF
# void-session definition for $id (generated)
WM_NAME='${NAME[$id]}'
WM_TYPE='${TYPE[$id]}'
WM_EXEC='$exec'
WM_FALLBACK='$fallback'
WM_XDG='${XDG[$id]}'
WM_RICE='${RICE[$id]}'
WM_SELFSTART='${SELFSTART[$id]:-0}'
EOF
    if [ "${TYPE[$id]}" = wayland ]; then dir=/usr/share/wayland-sessions; else dir=/usr/share/xsessions; fi
    write_file "$dir/void-$id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${NAME[$id]} · $rice_label
Comment=${NAME[$id]} with the $rice_label rice (void-session: D-Bus, PipeWire, portals)
Exec=/usr/local/bin/void-session $id
DesktopNames=${XDG[$id]//:/;}
EOF
  done
}

# greetd + tuigreet: a small console greeter that lists every session above
setup_greetd() {
  msg "Configuring greetd + tuigreet"
  local power_off power_reboot
  if [ "$SEAT" = elogind ]; then
    power_off="loginctl poweroff" power_reboot="loginctl reboot"
  else
    # no logind: allow exactly these two commands for the greeter user
    write_file /etc/sudoers.d/20-greeter-power 0440 <<'EOF'
_greeter ALL=(root) NOPASSWD: /usr/bin/poweroff, /usr/bin/reboot
EOF
    power_off="sudo -n /usr/bin/poweroff" power_reboot="sudo -n /usr/bin/reboot"
  fi
  # vt 7 keeps agetty on tty1-6 untouched (greetd README.voidlinux: never
  # share a VT with an agetty service)
  write_file /etc/greetd/config.toml <<EOF
# Written by void-postinstall
[terminal]
vt = 7

[default_session]
command = "tuigreet --time --remember --remember-user-session --asterisks --greeting 'Void Linux' --sessions /usr/share/wayland-sessions --xsessions /usr/share/xsessions --theme 'border=darkgray;text=gray;prompt=lightcyan;time=lightblue;action=darkgray;button=lightcyan;container=black;input=white' --power-shutdown '$power_off' --power-reboot '$power_reboot'"
user = "_greeter"
EOF
  if [ "$SEAT" = seatd ]; then
    add_user_to_groups _greeter _seatd video
  fi
}
