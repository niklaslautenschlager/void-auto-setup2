# shellcheck shell=bash
# lib/system.sh: platform facts, runit services, users and groups.

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------
detect_platform() {
  ARCH="$(uname -m)"
  if [ -n "${VPI_LIBC:-}" ]; then
    LIBC="$VPI_LIBC"
  elif ldd --version 2>&1 | grep -qi musl || [ -e "$R/lib/ld-musl-${ARCH}.so.1" ]; then
    LIBC=musl
  else
    LIBC=glibc
  fi
  # A running runsvdir means services start the moment they are linked.
  # In a chroot (manual install) nothing is supervised yet.
  if [ -n "${VPI_CHROOT:-}" ]; then
    IN_CHROOT="$VPI_CHROOT"
  elif pgrep -x runsvdir >/dev/null 2>&1; then
    IN_CHROOT=0
  else
    IN_CHROOT=1
  fi
}

is_x86_64_glibc() { [ "$ARCH" = x86_64 ] && [ "$LIBC" = glibc ]; }

# ---------------------------------------------------------------------------
# runit services
#
# Handbook ("Enabling Services"): on a running system link into /var/service,
# otherwise into /etc/runit/runsvdir/default. /var/service points at the
# *current* runsvdir, which is "default" on a normal boot, so linking into
# default works in both cases and survives reboots.
# ---------------------------------------------------------------------------
SVDIR_DEFAULT=/etc/runit/runsvdir/default

service_exists()  { [ -d "$R/etc/sv/$1" ]; }
service_enabled() { [ -L "$R$SVDIR_DEFAULT/$1" ]; }

enable_service() {
  local svc="$1"
  if ! service_exists "$svc"; then
    warn "Service '$svc' does not exist (package missing?); not enabled."
    return 0
  fi
  if service_enabled "$svc"; then
    info "service $svc: already enabled"
    return 0
  fi
  symlink "/etc/sv/$svc" "$SVDIR_DEFAULT/$svc"
  info "service $svc: enabled"
}

disable_service() {
  local svc="$1"
  service_enabled "$svc" || return 0
  remove_path "$SVDIR_DEFAULT/$svc"
  info "service $svc: disabled"
}

# enable_service_next_boot SVC: enabled, but not started right now.
# Used for login managers: starting one while the script still owns the
# console would switch VTs under the user. A `down` file keeps runit from
# starting it now; a one-shot core-services hook removes it on the next boot.
enable_service_next_boot() {
  local svc="$1"
  service_exists "$svc" || { warn "Service '$svc' does not exist; not enabled."; return 0; }
  if [ "$IN_CHROOT" = 1 ]; then
    enable_service "$svc"
    return 0
  fi
  write_file "/etc/sv/$svc/down" </dev/null
  write_file "/etc/runit/core-services/99-void-postinstall-$svc.sh" 0644 <<EOF
# One-shot hook written by void-postinstall: allow '$svc' to start from now on.
rm -f /etc/sv/$svc/down /etc/runit/core-services/99-void-postinstall-$svc.sh
EOF
  enable_service "$svc"
}

# ---------------------------------------------------------------------------
# Users and groups
# ---------------------------------------------------------------------------
# list_human_users: name per line, UID 1000-59999, real login shell
list_human_users() {
  awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ { print $1 }' "$R/etc/passwd"
}

group_exists() { awk -F: -v g="$1" '$1 == g { f = 1 } END { exit !f }' "$R/etc/group"; }
user_home()    { awk -F: -v u="$1" '$1 == u { print $6 }' "$R/etc/passwd"; }
user_in_group() { id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }

# add_user_to_groups USER GROUP...: only groups that exist; idempotent
add_user_to_groups() {
  local user="$1" g; shift
  local add=()
  for g in "$@"; do
    group_exists "$g" || continue
    user_in_group "$user" "$g" && continue
    add+=("$g")
  done
  [ "${#add[@]}" -eq 0 ] && return 0
  run usermod -aG "$(IFS=,; echo "${add[*]}")" "$user"
  info "added $user to: ${add[*]}"
}

# create_user NAME: interactive password via passwd(1) on the real tty
create_user() {
  local name="$1"
  run useradd -m -G wheel,users -s /bin/bash "$name"
  if [ "$DRY_RUN" != 1 ]; then
    info "Set a password for $name:"
    until passwd "$name" </dev/tty; do warn "Try again."; done
  fi
  # wheel → sudo, unless the admin already decided otherwise
  if ! grep -Eqs '^[[:space:]]*%wheel[[:space:]]+ALL' "$R/etc/sudoers" "$R"/etc/sudoers.d/* 2>/dev/null; then
    write_file /etc/sudoers.d/10-wheel 0440 <<<'%wheel ALL=(ALL:ALL) ALL'
  fi
}
