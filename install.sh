#!/bin/bash
# void-postinstall: configure a Void Linux workstation in one prompted pass.
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
R="${R:-}" DRY_RUN="${DRY_RUN:-0}" RICES_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --rices-only) RICES_ONLY=1 ;;
    -h|--help) sed -n '1,12p' "$0"; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
for lib in common prompt system hardware catalog xbps hyprland audio session; do
  # shellcheck source=/dev/null
  . "$ROOT_DIR/lib/$lib.sh"
done

# ----------------------------------------------------------------------------
# Splash screen
# ----------------------------------------------------------------------------
_splashscreen_fallback() {
  cat <<'EOF'
██╗   ██╗  ██████╗  ██╗██████╗
██║   ██║ ██╔═══██╗ ██║██╔══██╗
██║   ██║ ██║   ██║ ██║██║  ██║
╚██╗ ██╔╝ ██║   ██║ ██║██║  ██║
 ╚████╔╝  ╚██████╔╝ ██║██████╔╝
  ╚═══╝    ╚═════╝  ╚═╝╚═════╝

 ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
 ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
 ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
 ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
 ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
 ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝  ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
EOF
}
_splashscreen() {
  [ -t 1 ] || return 0
  if [ -r "$ROOT_DIR/files/splash.txt" ]; then cat "$ROOT_DIR/files/splash.txt"
  else _splashscreen_fallback; fi
  printf '\n'
}
_splashscreen
if [ -z "$R" ] && [ "$(id -u)" -ne 0 ]; then die "Run this installer as root (sudo ./install.sh)."; fi
command -v xbps-install >/dev/null 2>&1 || [ -n "$R" ] || die "xbps-install is required."
prompt_init
trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR
detect_platform
detect_hardware
msg "Void post-install setup"
info "platform: $ARCH / $LIBC"
info "graphics: ${GPU_VENDORS[*]:-not detected}"
info "CPU: ${CPU_VENDOR:-not detected}; Bluetooth: $([ "$HAS_BLUETOOTH" = 1 ] && echo detected || echo not detected)"
[ -n "$VM_KIND" ] && info "virtual machine: $VM_KIND"

# Catalog lookups that tolerate missing keys under `set -u`.
cat_name() { printf '%s' "${NAME[$1]:-$1}"; }
cat_kind() { printf '%s' "${KIND[$1]:-wm}"; }
cat_type() { printf '%s' "${TYPE[$1]:-x11}"; }
cat_pkgs() { printf '%s' "${PKGS[$1]:-}"; }

select_target_user() {
  local users=() entries=() u
  mapfile -t users < <(list_human_users)
  if [ "${#users[@]}" -eq 1 ]; then TARGET_USER="${users[0]}"; CREATE_USER=0
  elif [ "${#users[@]}" -gt 1 ]; then
    for u in "${users[@]}"; do entries+=("$u=$u"); done
    menu_one TARGET_USER "Choose the user who will receive the rice" "${users[0]}" "${entries[@]}"
    CREATE_USER=0
  elif [ "$RICES_ONLY" = 1 ]; then die "--rices-only needs an existing human user."
  else
    ask_text TARGET_USER "No existing human user found. Create a login user named" ""
    [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || die "Invalid Linux user name: $TARGET_USER"
    CREATE_USER=1
  fi
  info "target user: $TARGET_USER"
}
select_target_user
if [ "$RICES_ONLY" = 1 ]; then
  install_file "$ROOT_DIR/files/bin/void-rice" /usr/local/bin/void-rice 0755
  run mkdir -p "$R/usr/local/share/void-postinstall/rices"
  run cp -a "$ROOT_DIR/rices/." "$R/usr/local/share/void-postinstall/rices/"
  if [ "$DRY_RUN" = 1 ]; then info "dry run: would apply installed rices for $TARGET_USER"
  else run env R="$R" VOID_RICE_SRC="$R/usr/local/share/void-postinstall/rices" \
    "$R/usr/local/bin/void-rice" apply --installed --user "$TARGET_USER"; fi
  exit 0
fi

mapfile -t MENU_ENTRIES < <(catalog_menu_entries)
if ! hv_supported; then
  filtered=()
  for entry in "${MENU_ENTRIES[@]}"; do [[ "$entry" == hyprland=* ]] || filtered+=("$entry"); done
  MENU_ENTRIES=("${filtered[@]}")
fi
SEL_SESSIONS=()
menu_many SEL_SESSIONS "Choose desktop environments and window managers" "" "${MENU_ENTRIES[@]}"
SEL_DES=() SEL_WMS=() valid_sessions=()
for id in "${SEL_SESSIONS[@]}"; do
  if [ -z "$(cat_pkgs "$id")" ]; then
    warn "Session '$id' has no package list in the catalog; skipping."
    continue
  fi
  valid_sessions+=("$id")
  if [ "$(cat_kind "$id")" = de ]; then SEL_DES+=("$id"); else SEL_WMS+=("$id"); fi
done
SEL_SESSIONS=("${valid_sessions[@]}")
if [ "${#SEL_DES[@]}" -gt 0 ]; then SEAT=elogind
else
  menu_one SEAT "Choose session/device management" elogind \
    elogind='elogind (recommended)' seatd='seatd (lean; adds dumb_runtime_dir and device groups)'
fi
if [ "${#SEL_DES[@]}" -gt 0 ]; then
  dm_default=""
  for c in gdm sddm lightdm; do
    for id in "${SEL_DES[@]}"; do [ "${DM[$id]:-}" = "$c" ] && dm_default="$c"; done
    [ -n "$dm_default" ] && break
  done
  dm_entries=()
  for c in gdm sddm lightdm; do
    for id in "${SEL_DES[@]}"; do
      if [ "${DM[$id]:-}" = "$c" ]; then dm_entries+=("$c=$c"); break; fi
    done
  done
  dm_entries+=(none='No graphical login manager')
  menu_one LOGIN_MANAGER "Choose the login manager" "$dm_default" "${dm_entries[@]}"
elif [ "${#SEL_WMS[@]}" -gt 0 ]; then
  menu_one LOGIN_MANAGER "Choose a login manager" greetd \
    greetd='greetd + tuigreet' none='No graphical login manager'
else LOGIN_MANAGER=none; fi

menu_one GPU_MODE "Choose graphics drivers (detected: ${GPU_VENDORS[*]:-none})" auto \
  auto='Use detected GPU drivers' none='Do not add graphics drivers' \
  intel='Intel Mesa + media acceleration' amd='AMD Mesa' \
  nvidia='NVIDIA branch selected from device IDs' virtual='Virtual-machine Mesa'
NVIDIA_PKG="" NVIDIA_LEGACY=0
if [ "$GPU_MODE" = nvidia ] || { [ "$GPU_MODE" = auto ] && in_list nvidia "${GPU_VENDORS[@]}"; }; then
  NVIDIA_PKG="$(nvidia_suggested_pkg)"
  case "$NVIDIA_PKG" in nvidia580|nvidia470|nvidia390) NVIDIA_LEGACY=1 ;; esac
  if [ -z "$NVIDIA_PKG" ]; then
    warn "No supported NVIDIA branch mapped from device IDs; nouveau will be used."
    [ "$GPU_MODE" = nvidia ] && GPU_MODE=none
  fi
fi
WANT_32BIT=0 WANT_STEAM=0
if is_x86_64_glibc; then
  ask_yn "Install 32-bit compatibility libraries?" n && WANT_32BIT=1 || :
  ask_yn "Install Steam?" n && { WANT_STEAM=1; WANT_32BIT=1; } || :
else info "32-bit and Steam packages require x86_64 glibc; skipping."; fi
if [ "$CPU_VENDOR" = intel ] || [ "$CPU_VENDOR" = amd ]; then
  ask_yn "Install $CPU_VENDOR CPU microcode?" y && WANT_MICROCODE=1 || WANT_MICROCODE=0
else WANT_MICROCODE=0; fi
WANT_BLUETOOTH=0
if [ "$HAS_BLUETOOTH" = 1 ]; then
  ask_yn "Install Bluetooth tools and PipeWire Bluetooth audio?" y && WANT_BLUETOOTH=1 || :
fi
ask_yn "Switch networking to NetworkManager at the end?" y && WANT_NM=1 || WANT_NM=0

KEYMAP_FROM_RC=""
if [ -r "$R/etc/rc.conf" ]; then
  KEYMAP_FROM_RC="$(awk -F= '/^[[:space:]]*KEYMAP=/ { gsub(/[ "'\''\r]/, "", $2); print $2; exit }' "$R/etc/rc.conf")"
fi
keymap_to_xkb() {
  local k
  k="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$k" in
    de|de-*|de_*) echo de ;; fr|fr-*|fr_*) echo fr ;;
    uk|gb|uk-*|uk_*) echo gb ;; us|us-*|us_*) echo us ;;
    ch|de-ch|de_ch) echo ch ;; at|de-at|de_at) echo at ;;
    es|es-*|es_*) echo es ;; it|it-*|it_*) echo it ;;
    pt|pt-*|pt_*) echo pt ;; br|br-*|br_*) echo br ;;
    se|sv|sv-*|sv_*) echo se ;; no|no-*|no_*) echo no ;;
    dk|da|da-*|da_*) echo dk ;; fi|fi-*|fi_*) echo fi ;;
    ru|ru-*|ru_*) echo ru ;; jp|ja|ja-*|ja_*) echo jp ;;
    *) printf '%s\n' "$k" | sed -E 's/[-_].*$//' ;;
  esac
}
KEYBOARD_LAYOUT="$(keymap_to_xkb "${KEYMAP_FROM_RC:-us}")"
[[ "$KEYBOARD_LAYOUT" =~ ^[A-Za-z0-9_,]+$ ]] || KEYBOARD_LAYOUT=us
ask_text KEYBOARD_LAYOUT "XKB keyboard layout" "$KEYBOARD_LAYOUT"
[[ "$KEYBOARD_LAYOUT" =~ ^[A-Za-z0-9_,]+$ ]] || die "Invalid XKB layout: $KEYBOARD_LAYOUT"

APP_CATEGORIES=()
menu_many APP_CATEGORIES "Optional application groups" "" \
  browser='Web browser' media='Media tools' office='Office suite' \
  creative='Image and graphics tools' developer='Developer tools' files='File manager and archives'

# AI coding CLIs, installed globally through npm (nodejs comes from xbps).
declare -A AI_NPM=(
  [claude]='@anthropic-ai/claude-code'
  [codex]='@openai/codex'
  [gemini]='@google/gemini-cli'
  [opencode]='opencode-ai'
)
AI_CLIS=()
menu_many AI_CLIS "Optional AI coding CLIs (installed via npm)" "" \
  claude='Claude Code' codex='OpenAI Codex CLI' gemini='Google Gemini CLI' opencode='opencode'

printf '\nInstallation plan\n'
printf '  User: %s%s\n' "$TARGET_USER" "$([ "$CREATE_USER" = 1 ] && echo ' (create)' || :)"
printf '  Sessions: %s\n' "${SEL_SESSIONS[*]:-none}"
printf '  Seat/login manager: %s / %s\n' "$SEAT" "$LOGIN_MANAGER"
printf '  Graphics: %s%s\n' "$GPU_MODE" "${NVIDIA_PKG:+ ($NVIDIA_PKG)}"
printf '  32-bit/Steam/network manager: %s / %s / %s\n' "$WANT_32BIT" "$WANT_STEAM" "$WANT_NM"
printf '  Microcode/Bluetooth/keyboard: %s / %s / %s\n' "$WANT_MICROCODE" "$WANT_BLUETOOTH" "$KEYBOARD_LAYOUT"
printf '  App groups: %s\n' "${APP_CATEGORIES[*]:-none}"
printf '  AI CLIs: %s\n' "${AI_CLIS[*]:-none}"
ask_yn "Proceed with this plan?" n || die "Cancelled before changing the system."

log_init
xbps_sync_and_update
SUBREPOS=()
REPO_SYNC_NEEDED=0
[ -n "$NVIDIA_PKG" ] && SUBREPOS+=(void-repo-nonfree)
[ "$WANT_32BIT" = 1 ] && SUBREPOS+=(void-repo-multilib)
[ "$WANT_STEAM" = 1 ] && SUBREPOS+=(void-repo-multilib-nonfree void-repo-nonfree)
if [ "${#SUBREPOS[@]}" -gt 0 ]; then
  REPO_SYNC_NEEDED=1
  unique=()
  for p in "${SUBREPOS[@]}"; do in_list "$p" "${unique[@]}" || unique+=("$p"); done
  enable_subrepos "${unique[@]}"
fi
HV_SELECTED=0
in_list hyprland "${SEL_WMS[@]}" && HV_SELECTED=1
if [ "$HV_SELECTED" = 1 ]; then
  REPO_SYNC_NEEDED=1
  hv_setup_repo || warn "Hyprland repo setup failed; continuing without it."
fi
audio_queue
write_noextract_conf
if [ "$REPO_SYNC_NEEDED" = 1 ]; then xbps_sync; fi
msg "Reading package index"
xbps_load_index
want "Core services" dbus polkit
if [ "$SEAT" = elogind ]; then want "Core services" elogind; else want "Core services" seatd dumb_runtime_dir; fi
want "Core utilities" htop
[ "$WANT_NM" = 1 ] && want "Networking" NetworkManager
if [ "$CREATE_USER" = 1 ] || [ "$SEAT" = seatd ]; then
  want "Core services" sudo
fi
[ "$SEAT" = seatd ] && want_first "Seat suspend helper" zzz
[ "$WANT_BLUETOOTH" = 1 ] && want "Bluetooth" bluez blueman
if [ "$WANT_MICROCODE" = 1 ]; then
  if [ "$CPU_VENDOR" = intel ]; then want "CPU microcode" intel-ucode; else want "CPU microcode" amd-ucode; fi
fi
for id in "${SEL_DES[@]}"; do
  read -r -a packages <<< "$(cat_pkgs "$id")"
  want "Desktop: $(cat_name "$id")" "${packages[@]}"
done
for id in "${SEL_WMS[@]}"; do
  read -r -a packages <<< "$(cat_pkgs "$id")"
  want "Window manager: $(cat_name "$id")" "${packages[@]}"
  if [ "$(cat_type "$id")" = wayland ]; then read -r -a packages <<< "$RICE_WAYLAND_PKGS"
  else read -r -a packages <<< "$RICE_X11_PKGS"; fi
  want "Rice tools" "${packages[@]}"
done
if [ "${#SEL_WMS[@]}" -gt 0 ]; then
  read -r -a packages <<< "$RICE_COMMON_PKGS"
  want "Rice tools" "${packages[@]}"
fi
[ "$LOGIN_MANAGER" = greetd ] && want "Login manager" greetd tuigreet

queue_gpu() {
  local vendor="$1" series
  case "$vendor" in
    intel) want "Graphics: Intel" mesa-dri mesa-vulkan-intel intel-video-accel ;;
    amd) want "Graphics: AMD" mesa-dri mesa-vulkan-radeon mesa-vaapi ;;
    virtual) want "Graphics: virtual" mesa-dri mesa-vulkan-lavapipe ;;
    nvidia)
      if [ -n "$NVIDIA_PKG" ]; then
        want "Graphics: NVIDIA" "$NVIDIA_PKG"
        while read -r series; do [ -n "$series" ] && want "NVIDIA kernel headers" "linux${series}-headers"; done < <(installed_kernel_series)
        if [ "$NVIDIA_LEGACY" = 1 ]; then
          write_file /etc/modprobe.d/void-postinstall-nvidia.conf <<'EOF'
# Required for legacy NVIDIA branches selected by void-postinstall.
options nvidia_drm modeset=1 fbdev=1
EOF
        fi
      else want "Graphics: NVIDIA fallback" mesa-dri; fi ;;
  esac
}
case "$GPU_MODE" in
  auto) for vendor in "${GPU_VENDORS[@]}"; do queue_gpu "$vendor"; done ;;
  intel|amd|virtual|nvidia) queue_gpu "$GPU_MODE" ;;
esac
if [ "$WANT_32BIT" = 1 ]; then
  want "32-bit compatibility" libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit mesa-dri-32bit
  case "$NVIDIA_PKG" in
    nvidia) want "32-bit NVIDIA" nvidia-libs-32bit ;;
    nvidia580|nvidia470|nvidia390) want "32-bit NVIDIA" "$NVIDIA_PKG-libs-32bit" ;;
  esac
fi
[ "$WANT_STEAM" = 1 ] && want "Steam" steam
for category in "${APP_CATEGORIES[@]}"; do
  case "$category" in
    browser) want_first "Apps: browser" firefox chromium ;;
    media) want "Apps: media" mpv vlc audacity ;;
    office) want_first "Apps: office" libreoffice libreoffice-writer ;;
    creative) want "Apps: creative" gimp inkscape ;;
    developer) want "Apps: developer" git cmake clang base-devel ;;
    files) want_first "Apps: file manager" Thunar pcmanfm; want "Apps: archives" file-roller p7zip ;;
  esac
done
[ "${#AI_CLIS[@]}" -gt 0 ] && want "AI CLIs: runtime" nodejs

xbps_install_queue
HV_OK=0
if [ "$HV_SELECTED" = 1 ]; then
  read -r -a hv_packages <<< "${HV[hyprland]:-}"
  if [ "${#hv_packages[@]}" -eq 0 ]; then
    warn "No Hyprland package list in the catalog; skipping Hyprland install."
  elif hv_install "${hv_packages[@]}"; then HV_OK=1; fi
fi
if [ "${#AI_CLIS[@]}" -gt 0 ]; then
  if [ -n "$R" ]; then
    warn "AI CLIs are installed with the host's npm; skipped because R=$R targets another root."
  elif ! command -v npm >/dev/null 2>&1 && [ "$DRY_RUN" != 1 ]; then
    warn "npm not found after installing nodejs; AI CLIs were not installed."
  else
    msg "Installing AI CLIs"
    for cli in "${AI_CLIS[@]}"; do
      pkg="${AI_NPM[$cli]:-}"
      if [ -z "$pkg" ]; then warn "Unknown AI CLI '$cli'; skipping."; continue; fi
      if ! run npm install -g "$pkg"; then warn "npm install of $pkg failed."; fi
    done
  fi
fi
[ "$CREATE_USER" = 1 ] && create_user "$TARGET_USER"
enable_service dbus
if [ "$SEAT" = elogind ]; then enable_service elogind; disable_service acpid; else enable_service seatd; fi
enable_service polkitd
[ "$WANT_BLUETOOTH" = 1 ] && enable_service bluetoothd
if [ "$WANT_NM" = 1 ]; then
  disable_service dhcpcd
  disable_service wpa_supplicant
  enable_service NetworkManager
fi
audio_configure
install_session_tools
run mkdir -p "$R/usr/local/share/void-postinstall/rices"
run cp -a "$ROOT_DIR/rices/." "$R/usr/local/share/void-postinstall/rices/"
install_sessions
write_file /etc/void-postinstall/settings.conf <<EOF
kb_layout='$KEYBOARD_LAYOUT'
EOF
write_file /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "void-postinstall keyboard layout"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$KEYBOARD_LAYOUT"
EndSection
EOF
if [ "$DRY_RUN" != 1 ] && [ "${#SEL_WMS[@]}" -gt 0 ]; then
  run env R="$R" VOID_RICE_SRC="$R/usr/local/share/void-postinstall/rices" \
    "$R/usr/local/bin/void-rice" apply --installed --user "$TARGET_USER"
  for id in "${SEL_WMS[@]}"; do
    case "$id" in
      dwm|frankenwm)
        if ! env R="$R" VOID_RICE_SRC="$R/usr/local/share/void-postinstall/rices" \
          "$R/usr/local/bin/void-rice" build "$id"; then warn "$id build failed; using packaged binary if available."; fi ;;
    esac
  done
elif [ "${#SEL_WMS[@]}" -gt 0 ]; then info "dry run: rice deployment and source builds are skipped."; fi

add_user_to_groups "$TARGET_USER" users wheel
[ "$WANT_NM" = 1 ] && add_user_to_groups "$TARGET_USER" network
[ "$SEAT" = seatd ] && add_user_to_groups "$TARGET_USER" audio video input _seatd
if [ "$SEAT" = seatd ]; then
  write_file /etc/sudoers.d/30-void-postinstall-power 0440 <<EOF
$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/zzz, /usr/bin/reboot, /usr/bin/poweroff
EOF
fi
if [ "$WANT_BLUETOOTH" = 1 ]; then add_user_to_groups "$TARGET_USER" bluetooth; run rfkill unblock bluetooth; fi
TARGET_HOME="$(user_home "$TARGET_USER" || true)"
if [ -n "$TARGET_HOME" ]; then
  write_file "$TARGET_HOME/.config/void-rice/settings.conf" <<EOF
kb_layout='$KEYBOARD_LAYOUT'
EOF
  for gtk in 3.0 4.0; do
    write_file "$TARGET_HOME/.config/gtk-$gtk/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=true
EOF
  done
  TARGET_GID="$(awk -F: -v u="$TARGET_USER" '$1 == u { print $4; exit }' "$R/etc/passwd")"
  if [ -n "$TARGET_GID" ]; then
    run chown -R "$TARGET_USER:$TARGET_GID" "$R$TARGET_HOME/.config"
  else
    warn "Could not read the primary group for $TARGET_USER; config ownership was not changed."
  fi
else warn "Could not read the home directory for $TARGET_USER; user settings were not written."; fi
if [ "$LOGIN_MANAGER" = greetd ]; then
  setup_greetd
  enable_service_next_boot greetd
elif [ "$LOGIN_MANAGER" != none ]; then enable_service_next_boot "$LOGIN_MANAGER"; fi
printf '\nSetup finished. Log: %s\n' "$LOG"
if [ "${#WARNINGS[@]}" -gt 0 ]; then
  printf 'Warnings:\n'
  printf '  - %s\n' "${WARNINGS[@]}"
fi
ask_yn "Reboot now?" n && run reboot || :
