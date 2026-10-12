# shellcheck shell=bash
# lib/hyprland.sh: the unofficial hyprland-void binary repository
# (github.com/sofijacom/hyprland-void), set up so it cannot break xbps.
#
#  * Priority: xbps takes a package from the FIRST repository that has it
#    (bestmatching is off by default) and reads /etc/xbps.d before
#    /usr/share/xbps.d. A file in /etc/xbps.d would make hyprland-void the
#    top-priority repo and let it shadow Void's own lua55, hyprutils,
#    hyprpicker, ... We use the path upstream's own `hyprland-repo` template
#    uses: /usr/share/xbps.d/99-hyprland-void.conf, the lowest priority.
#    Versioned deps (hyprland needs hyprutils>=0.14) still fall through to it.
#  * Key: imported from a pinned copy whose fingerprint was verified against
#    the live repodata (b3:21:c4:43:d9:38:6f:ec:36:64:0d:65:37:13:c1:fe), so
#    no interactive prompt and no trust-on-first-use.
#  * Package set: no Qt-private-API packages (hyprpolkitagent,
#    hyprland-qt-support, hyprland-guiutils). They break on every Qt point
#    release; today they need Qt 6.11.1 while Void ships 6.11.2.
#  * Isolation: installed in its own transaction, so a broken third-party
#    repo can't take the rest of the install down with it.
#  * Freeze: everything that came from it is repolocked; `void-update`
#    holds Void packages whose update would strand its shlibs.

HV_KEY_FP="b3:21:c4:43:d9:38:6f:ec:36:64:0d:65:37:13:c1:fe"
HV_KEY_FILE="${HV_KEY_FP//:/_}.plist"
HV_CONF=/usr/share/xbps.d/99-hyprland-void.conf
HV_URL=""

hv_supported() {
  case "$ARCH-$LIBC" in
    x86_64-glibc|x86_64-musl|aarch64-glibc|aarch64-musl)
      HV_URL="https://raw.githubusercontent.com/sofijacom/hyprland-void/repository-$ARCH-$LIBC"
      return 0 ;;
  esac
  return 1
}

hv_setup_repo() {
  hv_supported || { warn "hyprland-void has no packages for $ARCH-$LIBC"; return 1; }
  msg "Adding hyprland-void (lowest priority) and its signing key"

  # The original script wrote /etc/xbps.d/hyprland-void.conf, which made
  # the third-party repo outrank Void's own. Migrate it away.
  local f
  for f in "$R"/etc/xbps.d/*.conf; do
    [ -e "$f" ] || continue
    if grep -q 'sofijacom/hyprland-void' "$f"; then
      info "removing high-priority repo file ${f#"$R"}"
      remove_path "${f#"$R"}"
    fi
  done

  write_file "$HV_CONF" <<EOF
# hyprland-void: unofficial Hyprland packages (written by void-postinstall).
# Kept in /usr/share/xbps.d with a high number on purpose: lowest priority,
# so it can never shadow a package that Void itself ships.
repository=$HV_URL
EOF
  install_file "$ROOT_DIR/files/xbps-keys/$HV_KEY_FILE" "/var/db/xbps/keys/$HV_KEY_FP.plist" 0644
}

# hv_install PKG...: separate transaction; failure is reported, not fatal
hv_install() {
  local pkgs=() p
  for p in "$@"; do
    if pkg_avail "$p"; then pkgs+=("$p"); else warn "hyprland-void: $p not found"; fi
  done
  [ "${#pkgs[@]}" -gt 0 ] || return 1
  msg "Installing from hyprland-void: ${pkgs[*]}"
  if run xbps-install -y "${pkgs[@]}" </dev/null; then
    _mark_installed "${pkgs[@]}"
    hv_repolock
    return 0
  fi
  warn "hyprland-void transaction failed. Usually it is mid-rebuild after a Void library bump."
  warn "Everything else is installed. Retry later with: xbps-install -S ${pkgs[*]} && void-update"
  return 1
}

# Repolock every installed package whose origin is hyprland-void
hv_repolock() {
  local v p n=0
  [ "$DRY_RUN" = 1 ] && { dim "  [dry-run] repolock packages from hyprland-void"; return 0; }
  while read -r v; do
    p="${v%%:*}"; p="${p%-*}"
    [ -n "$p" ] || continue
    xbps-pkgdb -m repolock "$p" >/dev/null 2>&1 && n=$((n + 1))
  done < <(xbps-query -p repository -s 'hyprland-void' 2>/dev/null)
  info "repolocked $n package(s) to hyprland-void"
}
