# shellcheck shell=bash
# lib/xbps.sh: repository index cache and batched package installation.
#
# Instead of one `xbps-query -R` per package (~120 index loads) and ~40 separate
# transactions, the whole repository pool is read once into an associative
# array, packages are queued in named groups, and everything is installed in a
# single transaction. Only if that fails do we fall back to installing group by
# group, which pinpoints the broken group without losing the rest.

declare -A REPO_PKGS=()      # pkgname -> pkgver available in the pool
declare -A INSTALLED=()      # pkgname -> pkgver installed
declare -A QUEUED=()         # pkgname -> group label
QUEUE_ORDER=()               # pkgnames in queue order
QUEUE_GROUPS=()              # group labels in order
declare -A GROUP_PKGS=()     # group label -> "pkg pkg ..."
MISSING_PKGS=()              # requested but not in any repo

# pkgver -> pkgname (pkgver is name-version_revision; version contains no '-')
_pkgname() { local v="$1"; printf '%s' "${v%-*}"; }

xbps_load_index() {
  local line pv
  REPO_PKGS=()
  # `xbps-query -Rs ''` matches every package in every configured repository.
  # Lines look like "[-] name-1.2_1   short description".
  while read -r _ pv _; do
    [ -n "$pv" ] && REPO_PKGS["$(_pkgname "$pv")"]="$pv"
  done < <(xbps-query -Rs '' 2>/dev/null)
  INSTALLED=()
  while read -r _ pv _; do
    [ -n "$pv" ] && INSTALLED["$(_pkgname "$pv")"]="$pv"
  done < <(xbps-query -l 2>/dev/null)
  info "repository index: ${#REPO_PKGS[@]} packages available, ${#INSTALLED[@]} installed"
  [ "${#REPO_PKGS[@]}" -gt 0 ] || die "Could not read the repository index (offline? run 'xbps-install -S')."
}

pkg_avail()     { [ -n "${REPO_PKGS[$1]:-}" ]; }
pkg_installed() { [ -n "${INSTALLED[$1]:-}" ]; }

# want GROUP PKG...: queue packages under a group label (dedupes)
want() {
  local group="$1" p; shift
  in_list "$group" "${QUEUE_GROUPS[@]}" || QUEUE_GROUPS+=("$group")
  for p in "$@"; do
    [ -n "$p" ] || continue
    [ -n "${QUEUED[$p]:-}" ] && continue
    QUEUED[$p]="$group"
    QUEUE_ORDER+=("$p")
    GROUP_PKGS[$group]+="$p "
  done
}

# want_first GROUP PKG...: queue the first package that exists
want_first() {
  local group="$1" p; shift
  for p in "$@"; do
    if pkg_avail "$p"; then want "$group" "$p"; return 0; fi
  done
  warn "$group: none of [$*] exist in the configured repositories"
}

# _filter_available PKG...: prints available ones, records missing ones
_filter_available() {
  local p
  for p in "$@"; do
    if pkg_avail "$p"; then
      printf '%s\n' "$p"
    elif ! in_list "$p" "${MISSING_PKGS[@]}"; then
      MISSING_PKGS+=("$p")
    fi
  done
}

# xbps_install_queue: one transaction for the whole queue, group fallback
xbps_install_queue() {
  local p list=() g glist
  for p in "${QUEUE_ORDER[@]}"; do
    [ -n "${QUEUED[$p]:-}" ] || continue
    list+=("$p")
  done
  mapfile -t list < <(_filter_available "${list[@]}")
  if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
    warn "Not in any configured repository (skipped): ${MISSING_PKGS[*]}"
  fi
  [ "${#list[@]}" -gt 0 ] || { info "nothing to install"; return 0; }

  msg "Installing ${#list[@]} packages in one transaction"
  if run xbps-install -y "${list[@]}"; then
    _mark_installed "${list[@]}"
    return 0
  fi

  warn "The combined transaction failed; retrying group by group to isolate the problem."
  for g in "${QUEUE_GROUPS[@]}"; do
    # shellcheck disable=SC2086
    mapfile -t glist < <(_filter_available ${GROUP_PKGS[$g]:-})
    [ "${#glist[@]}" -gt 0 ] || continue
    info "group: $g"
    if run xbps-install -y "${glist[@]}"; then
      _mark_installed "${glist[@]}"
    else
      warn "group '$g' failed to install: ${glist[*]}"
    fi
  done
}

_mark_installed() {
  local p
  for p in "$@"; do INSTALLED[$p]="${REPO_PKGS[$p]:-?}"; done
}

# ---------------------------------------------------------------------------
# System update (handbook: xbps must update itself in a separate transaction)
# ---------------------------------------------------------------------------
xbps_sync_and_update() {
  if [ -f "$R/usr/share/xbps.d/99-hyprland-void.conf" ] && [ -x "$R/usr/local/bin/void-update" ]; then
    msg "Updating through void-update (hyprland-void shlib protection enabled)"
    run "$R/usr/local/bin/void-update" --yes
    return
  fi
  msg "Syncing repositories and updating xbps"
  run xbps-install -Syu xbps
  msg "Updating the system"
  if ! run xbps-install -yu; then
    warn "System update failed (repository mid-build/'staged'?). Continuing; run 'void-update' later."
  fi
}

xbps_sync() {
  msg "Syncing repository indexes"
  run xbps-install -S
}

# ---------------------------------------------------------------------------
# Official sub-repositories
# ---------------------------------------------------------------------------
# These packages only drop a repository file into /usr/share/xbps.d.
enable_subrepos() {
  local pkgs=() p
  for p in "$@"; do pkg_installed "$p" || pkgs+=("$p"); done
  [ "${#pkgs[@]}" -gt 0 ] || return 0
  msg "Enabling repositories: ${pkgs[*]}"
  run xbps-install -y "${pkgs[@]}"
  _mark_installed "${pkgs[@]}"
}
